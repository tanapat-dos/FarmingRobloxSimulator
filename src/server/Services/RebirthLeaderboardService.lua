--!strict
--[[
	RebirthLeaderboardService — top-3 rebirth leaderboard.

	Mirrors CropSellLeaderboardService's architecture (persist + cross-server sync + push to
	client), keyed by player (UserId) instead of by crop name:
	  - In-memory `topEntries` sorted descending by Rebirths, capped at TOP_N.
	  - Persisted to a DataStore so the board survives server restarts / new servers spinning up.
	  - Broadcast via MessagingService so every live server converges within ~1s of a change.
	  - Pushed to clients via RemoteEvent "UpdateRebirthLeaderboard" + a RemoteFunction
	    "RequestRebirthLeaderboard" for on-demand pull (mirrors RequestCropLeaderboard).

	Player character models for the top 3 are NOT stored here — only Name/UserId/Rebirths are
	persisted (models can't survive a DataStore round-trip or a server restart anyway). The
	client resolves a live Player from UserId when available and clones their actual character;
	if that player isn't in the current server, it falls back to a generic R15 rig loaded via
	Players:GetHumanoidDescriptionFromUserId, so the podium never shows an empty slot just
	because the #1 rebirther happens to be on a different server.

	Remote protocol:
	  server -> client: RemoteEvent "UpdateRebirthLeaderboard" (entries: { RebirthLeaderboardEntry })
	  client -> server: RemoteFunction "RequestRebirthLeaderboard" -> entries
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local cachedModules = require(script.Parent.Parent.Server.CachedModules)

export type RebirthLeaderboardEntry = {
	UserId: number,
	PlayerName: string,
	Rebirths: number,
	Rank: number,
}

local IS_STUDIO = RunService:IsStudio()
local LEADERBOARD_KEY = "TopRebirths"
local LEADERBOARD_TOPIC = "RebirthLeaderboardUpdate"
local TOP_N = 3
local SAVE_MIN_INTERVAL = 5 -- throttle DataStore writes, matches CropSellLeaderboardService

-- Physical world board (mirrors CropSellLeaderboardService's sign/posts/frame pattern). Only
-- the SurfaceGui text is runtime-generated; the wood geometry itself is baked into the place
-- file once (via a one-time Edit-mode build) so it's visible without playtesting. If no baked
-- model exists yet, buildBoardModel() below falls back to building it fresh, same as the crop
-- board did before it was baked.
local BOARD_MODEL_NAME = "RebirthPriceBoard"
local SIGN_NAME = "Sign"
local POST_NAME = "Post"
local ANCHOR_NAME = "RebirthLeaderboardAnchor"
local BOARD_SIZE = Vector3.new(14, 9, 0.65)
local SIGN_CENTER_HEIGHT = 8.5
local POST_SIZE = Vector3.new(1, 6, 1)
local POST_BURY_DEPTH = 1
local BEHIND_ALTAR_OFFSET = 10

-- Guarded exactly like CropSellLeaderboardService: GetDataStore() can throw right after a
-- server boots. Server.server.lua's service loader has no pcall around require(), so an
-- unguarded throw here would silently abort every service that loads after this one
-- alphabetically.
local leaderboardStore: GlobalDataStore? = nil
if not IS_STUDIO then
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("RebirthLeaderboard_v1")
	end)
	if ok then
		leaderboardStore = store
	else
		warn("[RebirthLeaderboardService] GetDataStore failed, leaderboard will not persist:", store)
	end
end

local Service = {}
local boardModel: Model? = nil

-- { [UserId]: { UserId, PlayerName, Rebirths } }, unsorted source of truth.
local byUserId: { [number]: { UserId: number, PlayerName: string, Rebirths: number } } = {}

local updateRemote: RemoteEvent
local pendingSave = false
local lastSaveClock = 0

local function ensureRemote(name: string): RemoteEvent
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote :: RemoteEvent
end

-- Top TOP_N entries, sorted descending by Rebirths (ties broken by name for stability).
function Service.getTopEntries(): { RebirthLeaderboardEntry }
	local all = {}
	for _, record in byUserId do
		table.insert(all, record)
	end

	table.sort(all, function(a, b)
		if a.Rebirths ~= b.Rebirths then
			return a.Rebirths > b.Rebirths
		end
		return a.PlayerName < b.PlayerName
	end)

	local top: { RebirthLeaderboardEntry } = {}
	for i = 1, math.min(TOP_N, #all) do
		local record = all[i]
		table.insert(top, {
			UserId = record.UserId,
			PlayerName = record.PlayerName,
			Rebirths = record.Rebirths,
			Rank = i,
		})
	end
	return top
end

-- ------------------------------------------------------------------ physical world board
-- Simple 3-row SurfaceGui (Rank / Player / Rebirths) on the sign — no 3D character viewports
-- here, that stays exclusive to the podium panel opened via the "🏆 Top 3" menu button and
-- the board's own ProximityPrompt. This just needs to be readable from a walk-up distance.
local RANK_ICONS = { "🥇", "🥈", "🥉" }

local function populateSignGui(signPart: BasePart, entries: { RebirthLeaderboardEntry })
	local existingGui = signPart:FindFirstChild("BoardGui")
	if existingGui then
		existingGui:Destroy()
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "BoardGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = signPart

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(26, 20, 38)
	root.BorderSizePixel = 0
	root.Parent = surfaceGui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.03, 0)
	padding.PaddingBottom = UDim.new(0.03, 0)
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.Parent = root

	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(150, 110, 210)
	border.Thickness = 3
	border.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "🌟 Rebirth Leaderboard"
	title.TextColor3 = Color3.fromRGB(240, 230, 250)
	title.TextScaled = true
	title.Parent = root

	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MaxTextSize = 60
	titleConstraint.MinTextSize = 20
	titleConstraint.Parent = title

	local rowsFrame = Instance.new("Frame")
	rowsFrame.Name = "Rows"
	rowsFrame.Size = UDim2.fromScale(1, 0.78)
	rowsFrame.Position = UDim2.fromScale(0, 0.20)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.Parent = root

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0.02, 0)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsFrame

	if #entries == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 0)
		empty.AutomaticSize = Enum.AutomaticSize.Y
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.Text = "No rebirths yet — be the first!"
		empty.TextColor3 = Color3.fromRGB(180, 170, 200)
		empty.TextScaled = true
		empty.Parent = rowsFrame

		local emptyConstraint = Instance.new("UITextSizeConstraint")
		emptyConstraint.MaxTextSize = 36
		emptyConstraint.MinTextSize = 14
		emptyConstraint.Parent = empty
		return
	end

	for index, entry in entries do
		local row = Instance.new("Frame")
		row.Name = "Row" .. tostring(index)
		row.Size = UDim2.new(1, 0, 1 / TOP_N, 0)
		row.BackgroundColor3 = index % 2 == 0
			and Color3.fromRGB(38, 32, 54)
			or Color3.fromRGB(32, 27, 46)
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Parent = rowsFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.15, 0)
		corner.Parent = row

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Name = "Rank"
		rankLabel.Size = UDim2.new(0.18, 0, 1, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.Text = RANK_ICONS[entry.Rank] or ("#" .. tostring(entry.Rank))
		rankLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
		rankLabel.TextScaled = true
		rankLabel.Parent = row

		local rankConstraint = Instance.new("UITextSizeConstraint")
		rankConstraint.MaxTextSize = 48
		rankConstraint.MinTextSize = 16
		rankConstraint.Parent = rankLabel

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Player"
		nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
		nameLabel.Position = UDim2.fromScale(0.18, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = entry.PlayerName
		nameLabel.TextColor3 = Color3.fromRGB(220, 210, 240)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextScaled = true
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = row

		local nameConstraint = Instance.new("UITextSizeConstraint")
		nameConstraint.MaxTextSize = 44
		nameConstraint.MinTextSize = 14
		nameConstraint.Parent = nameLabel

		local rebirthLabel = Instance.new("TextLabel")
		rebirthLabel.Name = "Rebirths"
		rebirthLabel.Size = UDim2.new(0.27, 0, 1, 0)
		rebirthLabel.Position = UDim2.fromScale(0.73, 0)
		rebirthLabel.BackgroundTransparency = 1
		rebirthLabel.Font = Enum.Font.GothamBold
		rebirthLabel.Text = tostring(entry.Rebirths)
		rebirthLabel.TextColor3 = Color3.fromRGB(190, 140, 255)
		rebirthLabel.TextXAlignment = Enum.TextXAlignment.Right
		rebirthLabel.TextScaled = true
		rebirthLabel.Parent = row

		local rebirthConstraint = Instance.new("UITextSizeConstraint")
		rebirthConstraint.MaxTextSize = 44
		rebirthConstraint.MinTextSize = 14
		rebirthConstraint.Parent = rebirthLabel
	end
end

local function makeWoodPart(name: string, size: Vector3, color: Color3?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Wood
	part.Color = color or Color3.fromRGB(70, 50, 90)
	return part
end

local function getBoardPlacement(): (Vector3, CFrame)?
	local anchor = workspace:FindFirstChild(ANCHOR_NAME, true)
	if anchor and anchor:IsA("BasePart") then
		anchor.Anchored = true
		anchor.AssemblyLinearVelocity = Vector3.zero
		local signCFrame = anchor.CFrame * CFrame.new(0, SIGN_CENTER_HEIGHT, 0)
		return anchor.Position, signCFrame
	end

	-- Fallback: behind the altar, facing it, same pattern as the crop board's NPC-based
	-- fallback. Only used if no RebirthLeaderboardAnchor part has been placed.
	local altar = workspace:FindFirstChild("RebirthAltar")
	local pedestal = altar and altar:FindFirstChild("Pedestal")
	if not (pedestal and pedestal:IsA("BasePart")) then
		return nil
	end

	local altarPosition = pedestal.Position
	local floorY = altarPosition.Y - pedestal.Size.Y / 2
	local boardPosition = altarPosition + Vector3.new(0, 0, BEHIND_ALTAR_OFFSET)
	local floorPosition = Vector3.new(boardPosition.X, floorY, boardPosition.Z)
	local signPosition = Vector3.new(boardPosition.X, floorY + SIGN_CENTER_HEIGHT, boardPosition.Z)

	local flatTarget = Vector3.new(altarPosition.X, signPosition.Y, altarPosition.Z)
	local direction = flatTarget - signPosition
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end
	local yaw = math.atan2(direction.X, direction.Z)
	local signCFrame = CFrame.new(signPosition) * CFrame.Angles(0, yaw, 0)

	return floorPosition, signCFrame
end

local function applyBoardTransform(model: Model, floorPosition: Vector3, signCFrame: CFrame)
	local sign = model:FindFirstChild(SIGN_NAME)
	if not sign or not sign:IsA("BasePart") then
		return
	end

	sign.CFrame = signCFrame

	local floorY = floorPosition.Y
	local signCenterY = signCFrame.Position.Y
	local postOffsetY = (floorY + POST_SIZE.Y * 0.5 - POST_BURY_DEPTH) - signCenterY
	local posts = {}
	for _, child in model:GetChildren() do
		if child.Name == POST_NAME and child:IsA("BasePart") then
			table.insert(posts, child)
		end
	end
	table.sort(posts, function(a, b)
		return a.Position.X < b.Position.X
	end)
	local sideOffsets = { -(BOARD_SIZE.X * 0.5 - POST_SIZE.X), BOARD_SIZE.X * 0.5 - POST_SIZE.X }
	for index, post in posts do
		local sideX = sideOffsets[index]
		if sideX then
			post.CFrame = sign.CFrame * CFrame.new(sideX, postOffsetY, 0.3)
		end
	end

	local frameTrim = model:FindFirstChild("Frame")
	if frameTrim and frameTrim:IsA("BasePart") then
		frameTrim.CFrame = sign.CFrame * CFrame.new(0, 0, -0.14)
	end
end

local function buildBoardModel(floorPosition: Vector3, signCFrame: CFrame): Model?
	-- Direct Workspace child (not nested), same StreamingEnabled-exemption reasoning as
	-- CropSellLeaderboardService.
	local existing = workspace:FindFirstChild(BOARD_MODEL_NAME)
	local hasManualAnchor = workspace:FindFirstChild(ANCHOR_NAME, true) ~= nil

	if existing and existing:IsA("Model") and existing:FindFirstChild(SIGN_NAME)
		and (existing:FindFirstChild(SIGN_NAME) :: BasePart).Size == BOARD_SIZE then
		local sign = existing:FindFirstChild(SIGN_NAME) :: BasePart

		if hasManualAnchor then
			applyBoardTransform(existing, floorPosition, signCFrame)
		end

		local prompt = sign:FindFirstChild("RebirthPriceBoard")
		if not prompt or not prompt:IsA("ProximityPrompt") then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "RebirthPriceBoard"
			prompt.ActionText = "View Full List"
			prompt.ObjectText = "Rebirth Leaderboard"
			prompt.MaxActivationDistance = 24
			prompt.RequiresLineOfSight = false
			prompt.UIOffset = Vector2.new(0, -40)
			prompt.Parent = sign
		end

		pcall(populateSignGui, sign, Service.getTopEntries())

		if existing.Parent ~= workspace then
			existing.Parent = workspace
		end
		existing.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		CollectionService:AddTag(existing, "RebirthPriceBoard")
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local floorY = floorPosition.Y

	local model = Instance.new("Model")
	model.Name = BOARD_MODEL_NAME

	local sign = makeWoodPart(SIGN_NAME, BOARD_SIZE, Color3.fromRGB(80, 58, 102))
	sign.CFrame = signCFrame
	sign.Parent = model

	local signCenterY = signCFrame.Position.Y
	local postOffsetY = (floorY + POST_SIZE.Y * 0.5 - POST_BURY_DEPTH) - signCenterY
	for _, sideX in { -(BOARD_SIZE.X * 0.5 - POST_SIZE.X), BOARD_SIZE.X * 0.5 - POST_SIZE.X } do
		local post = makeWoodPart(POST_NAME, POST_SIZE, Color3.fromRGB(58, 42, 74))
		post.CFrame = sign.CFrame * CFrame.new(sideX, postOffsetY, 0.3)
		post.Parent = model
	end

	local frameTrim = makeWoodPart(
		"Frame",
		Vector3.new(BOARD_SIZE.X + 0.8, BOARD_SIZE.Y + 0.8, 0.4),
		Color3.fromRGB(44, 32, 56)
	)
	frameTrim.CFrame = sign.CFrame * CFrame.new(0, 0, -0.14)
	frameTrim.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPriceBoard"
	prompt.ActionText = "View Full List"
	prompt.ObjectText = "Rebirth Leaderboard"
	prompt.MaxActivationDistance = 24
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, -40)
	prompt.Parent = sign

	CollectionService:AddTag(model, "RebirthPriceBoard")
	model.PrimaryPart = sign
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = workspace

	pcall(populateSignGui, sign, Service.getTopEntries())

	return model
end

local function setupWorldBoard()
	local floorPosition, signCFrame = getBoardPlacement()
	if not floorPosition or not signCFrame then
		warn("[RebirthLeaderboardService] No RebirthLeaderboardAnchor or RebirthAltar found — board not built.")
		return
	end
	boardModel = buildBoardModel(floorPosition, signCFrame)
end

function Service.refreshWorldBoard()
	if not boardModel then
		return
	end
	local sign = boardModel:FindFirstChild(SIGN_NAME)
	if sign and sign:IsA("BasePart") then
		pcall(populateSignGui, sign, Service.getTopEntries())
	end
end

function Service.broadcastUpdate()
	updateRemote:FireAllClients(Service.getTopEntries())
	Service.refreshWorldBoard()
end

local function saveToDataStore()
	if IS_STUDIO or not leaderboardStore then
		return
	end
	local ok, err = pcall(function()
		leaderboardStore:SetAsync(LEADERBOARD_KEY, byUserId)
	end)
	if not ok then
		warn("[RebirthLeaderboardService] Failed to save leaderboard:", err)
	end
end

-- Throttled save, same coalescing pattern as CropSellLeaderboardService.
local function queueSave()
	if IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - lastSaveClock >= SAVE_MIN_INTERVAL then
		lastSaveClock = now
		saveToDataStore()
		return
	end
	if pendingSave then
		return
	end
	pendingSave = true
	task.delay(SAVE_MIN_INTERVAL - (now - lastSaveClock), function()
		pendingSave = false
		lastSaveClock = os.clock()
		saveToDataStore()
	end)
end

-- Called by RebirthService whenever a player's rebirth count changes. Only writes/broadcasts
-- when the new count is actually higher than what's on record (a player's count only ever
-- increases, but this guards against any out-of-order remote-sync application below).
function Service.reportRebirths(userId: number, playerName: string, rebirths: number)
	if typeof(userId) ~= "number" or typeof(rebirths) ~= "number" then
		return
	end
	local current = byUserId[userId]
	if current and rebirths <= current.Rebirths then
		-- Still refresh the display name in case it changed, but no rank change to broadcast.
		current.PlayerName = playerName
		return
	end

	byUserId[userId] = { UserId = userId, PlayerName = playerName, Rebirths = rebirths }
	Service.broadcastUpdate()
	queueSave()

	if not IS_STUDIO then
		pcall(function()
			MessagingService:PublishAsync(LEADERBOARD_TOPIC, byUserId[userId])
		end)
	end
end

-- Applies a record broadcast by another server (or loaded from DataStore) without
-- re-publishing/re-saving, avoiding an infinite MessagingService echo between servers.
local function applyRecord(record: any)
	if typeof(record) ~= "table" or typeof(record.UserId) ~= "number" then
		return
	end
	local current = byUserId[record.UserId]
	if current and record.Rebirths <= current.Rebirths then
		return
	end
	byUserId[record.UserId] = { UserId = record.UserId, PlayerName = record.PlayerName, Rebirths = record.Rebirths }
	Service.broadcastUpdate()
end

local function onRemoteUpdate(message)
	applyRecord(message.Data)
end

local function loadFromDataStore()
	if IS_STUDIO or not leaderboardStore then
		return
	end
	local ok, data = pcall(function()
		return leaderboardStore:GetAsync(LEADERBOARD_KEY)
	end)
	if ok and typeof(data) == "table" then
		for userIdKey, record in data do
			if typeof(record) == "table" then
				-- DataStore round-trips numeric table keys as strings; normalize back.
				local userId = tonumber(userIdKey) or record.UserId
				if typeof(userId) == "number" then
					byUserId[userId] = { UserId = userId, PlayerName = record.PlayerName, Rebirths = record.Rebirths }
				end
			end
		end
		Service.broadcastUpdate()
	elseif not ok then
		warn("[RebirthLeaderboardService] Failed to load leaderboard:", data)
	end
end

function Service.init()
	updateRemote = ensureRemote("UpdateRebirthLeaderboard")

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local requestRemote = remotes:FindFirstChild("RequestRebirthLeaderboard")
	if not requestRemote then
		requestRemote = Instance.new("RemoteFunction")
		requestRemote.Name = "RequestRebirthLeaderboard"
		requestRemote.Parent = remotes
	end
	(requestRemote :: RemoteFunction).OnServerInvoke = function(_player)
		return Service.getTopEntries()
	end

	if not IS_STUDIO then
		pcall(function()
			MessagingService:SubscribeAsync(LEADERBOARD_TOPIC, onRemoteUpdate)
		end)
	end

	task.spawn(function()
		loadFromDataStore()

		local ok, err = pcall(setupWorldBoard)
		if not ok then
			warn("[RebirthLeaderboardService] setupWorldBoard failed:", err)
		end

		-- Push initial entries to players who joined before the load finished.
		for _, player in Players:GetPlayers() do
			updateRemote:FireClient(player, Service.getTopEntries())
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			updateRemote:FireClient(player, Service.getTopEntries())
		end)
	end)
end

-- Called once a player's data has loaded (dataLoaded hook pattern, mirrors
-- RebirthService/CollectionService/etc.) so an existing high-rebirth player who rejoins gets
-- re-reported immediately, not just players who rebirth during this session.
function Service.dataLoaded(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if data and typeof(data.Rebirths) == "number" and data.Rebirths > 0 then
		Service.reportRebirths(player.UserId, player.Name, data.Rebirths)
	end
end

return Service
