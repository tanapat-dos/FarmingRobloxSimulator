-- Tracks best crop sales per player and builds the shop plaza leaderboard sign.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CropSellPriceBoard = require(ReplicatedStorage:WaitForChild("Modules").CropSellPriceBoard)

local BOARD_MODEL_NAME = "CropPriceBoard"
local SIGN_NAME = "Sign"
local POST_NAME = "Post"
local ANCHOR_NAME = "LeaderboardAnchor"

local BOARD_SIZE = Vector3.new(96, 48, 0.65)
local POST_SIZE = Vector3.new(8, 24, 8)
local POST_BURY_DEPTH = 2
local BEHIND_NPC_OFFSET = 18
local PLATFORM_BACK_MARGIN = 2

local Service = {}
Service.cachedModules = nil

local bestByCrop: { [string]: CropSellPriceBoard.BestSaleRecord } = {}
local boardModel: Model? = nil
local updateRemote: RemoteEvent

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

function Service.getEntries(): { CropSellPriceBoard.LeaderboardEntry }
	return CropSellPriceBoard.getDisplayEntries(bestByCrop)
end

function Service.broadcastUpdate()
	local entries = Service.getEntries()
	updateRemote:FireAllClients(entries)
	Service.refreshWorldBoard()
end

function Service.refreshWorldBoard()
	if not boardModel then
		return
	end
	local sign = boardModel:FindFirstChild(SIGN_NAME)
	if sign and sign:IsA("BasePart") then
		CropSellPriceBoard.populateSignGui(sign, Service.getEntries())
	end
end

function Service.recordSale(player: Player, cropName: string, weight: number, harvestRarity: string, sellPrice: number)
	if not cropName or sellPrice <= 0 then
		return
	end

	local current = bestByCrop[cropName]
	if current and sellPrice <= current.SellPrice then
		return
	end

	bestByCrop[cropName] = {
		PlayerName = player.Name,
		UserId = player.UserId,
		CropName = cropName,
		Weight = weight,
		Rarity = harvestRarity,
		SellPrice = math.floor(sellPrice * 100 + 0.5) / 100,
	}

	Service.broadcastUpdate()
end

local function getShopFloorY(shops: Instance): number
	local characters = shops:FindFirstChild("Characters")
	if characters then
		local total = 0
		local count = 0
		for _, npc in characters:GetChildren() do
			if npc:IsA("Model") then
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					total += hrp.Position.Y - 2
					count += 1
				end
			end
		end
		if count > 0 then
			return total / count
		end
	end

	local sellStuff = shops:FindFirstChild("SellStuff")
	local tpPart = sellStuff and sellStuff:FindFirstChild("TPPart")
	if tpPart and tpPart:IsA("BasePart") then
		return tpPart.Position.Y - 5
	end

	return 42
end

local function getPlatformBackZ(shops: Instance, fallbackZ: number): number
	local maxZ = -math.huge

	for _, child in shops:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= ANCHOR_NAME then
			local model = child:FindFirstAncestorOfClass("Model")
			if model and model.Parent == shops then
				local partMaxZ = child.Position.Z + (child.Size.Z * 0.5)
				maxZ = math.max(maxZ, partMaxZ)
			end
		end
	end

	if maxZ == -math.huge then
		return fallbackZ
	end

	return maxZ - PLATFORM_BACK_MARGIN
end

local function getBoardAnchor(shops: Instance): Vector3
	local anchor = shops:FindFirstChild(ANCHOR_NAME)
	if anchor and anchor:IsA("BasePart") then
		return anchor.Position
	end

	local samplePositions: { Vector3 } = {}
	for _, shopName in { "SeedShop", "SellStuff", "PetShop" } do
		local model = shops:FindFirstChild(shopName)
		local tpPart = model and model:FindFirstChild("TPPart")
		if tpPart and tpPart:IsA("BasePart") then
			table.insert(samplePositions, tpPart.Position)
		end
	end

	local characters = shops:FindFirstChild("Characters")
	if characters then
		for _, npc in characters:GetChildren() do
			if npc:IsA("Model") then
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					table.insert(samplePositions, hrp.Position)
				end
			end
		end
	end

	local minX, maxX, maxNpcZ = math.huge, -math.huge, -math.huge
	for _, position in samplePositions do
		minX = math.min(minX, position.X)
		maxX = math.max(maxX, position.X)
		maxNpcZ = math.max(maxNpcZ, position.Z)
	end

	local floorY = getShopFloorY(shops)
	local fallbackZ = maxNpcZ + BEHIND_NPC_OFFSET
	local boardZ = getPlatformBackZ(shops, fallbackZ)

	return Vector3.new((minX + maxX) * 0.5, floorY, boardZ)
end

local function getBoardViewTarget(shops: Instance): Vector3
	local sellShop = shops:FindFirstChild("SellStuff")
	local tpPart = sellShop and sellShop:FindFirstChild("TPPart")
	if tpPart and tpPart:IsA("BasePart") then
		return tpPart.Position
	end

	for _, shopName in { "SeedShop", "PetShop" } do
		local model = shops:FindFirstChild(shopName)
		local tp = model and model:FindFirstChild("TPPart")
		if tp and tp:IsA("BasePart") then
			return tp.Position
		end
	end

	return Vector3.new(0, 0, 0)
end

local function makeWoodPart(name: string, size: Vector3, color: Color3?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Wood
	part.Color = color or Color3.fromRGB(101, 67, 33)
	return part
end

local function buildBoardModel(shops: Instance, boardAnchor: Vector3)
	local existing = shops:FindFirstChild(BOARD_MODEL_NAME)
	if existing and existing:IsA("Model") and existing:FindFirstChild(SIGN_NAME) then
		local sign = existing:FindFirstChild(SIGN_NAME) :: BasePart

		local oldBillboard = sign:FindFirstChild("SignBillboard")
		if oldBillboard then
			oldBillboard:Destroy()
		end

		local prompt = sign:FindFirstChild("CropPriceBoard")
		if not prompt or not prompt:IsA("ProximityPrompt") then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "CropPriceBoard"
			prompt.ActionText = "View Full List"
			prompt.ObjectText = "Crop Sell Leaderboard"
			prompt.MaxActivationDistance = 24
			prompt.RequiresLineOfSight = false
			prompt.UIOffset = Vector2.new(0, -40)
			prompt.Parent = sign
		end

		local ok, err = pcall(function()
			CropSellPriceBoard.populateSignGui(sign, Service.getEntries())
		end)
		if not ok then
			warn("[CropSellLeaderboardService] Failed to populate board UI:", err)
		end

		CollectionService:AddTag(existing, "CropPriceBoard")
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local floorY = boardAnchor.Y
	local boardX = boardAnchor.X
	local boardZ = boardAnchor.Z

	local model = Instance.new("Model")
	model.Name = BOARD_MODEL_NAME

	local post = makeWoodPart(POST_NAME, POST_SIZE, Color3.fromRGB(86, 58, 28))
	local postCenterY = floorY + (POST_SIZE.Y * 0.5) - POST_BURY_DEPTH
	post.CFrame = CFrame.new(boardX, postCenterY, boardZ)
	post.Parent = model

	local sign = makeWoodPart(SIGN_NAME, BOARD_SIZE, Color3.fromRGB(118, 78, 38))
	local postTopY = floorY + POST_SIZE.Y - POST_BURY_DEPTH
	local signCenterY = postTopY + BOARD_SIZE.Y * 0.5
	local signPosition = Vector3.new(boardX, signCenterY, boardZ)
	local viewTarget = getBoardViewTarget(shops)
	sign.CFrame = CropSellPriceBoard.getSignCFrame(signPosition, viewTarget)
	sign.Parent = model

	local frameTrim = makeWoodPart(
		"Frame",
		Vector3.new(BOARD_SIZE.X + 0.8, BOARD_SIZE.Y + 0.8, 0.4),
		Color3.fromRGB(62, 42, 20)
	)
	frameTrim.CFrame = sign.CFrame * CFrame.new(0, 0, -0.14)
	frameTrim.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CropPriceBoard"
	prompt.ActionText = "View Full List"
	prompt.ObjectText = "Crop Sell Leaderboard"
	prompt.MaxActivationDistance = 24
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, -40)
	prompt.Parent = sign

	CollectionService:AddTag(model, "CropPriceBoard")
	model.PrimaryPart = sign
	model.Parent = shops

	local ok, err = pcall(function()
		CropSellPriceBoard.populateSignGui(sign, Service.getEntries())
	end)
	if not ok then
		warn("[CropSellLeaderboardService] Failed to populate board UI:", err)
	end

	return model
end

local function setupWorldBoard()
	local shops = workspace:WaitForChild("Shops", 60)
	if not shops then
		warn("[CropSellLeaderboardService] Workspace.Shops not found")
		return
	end

	local boardAnchor = getBoardAnchor(shops)
	boardModel = buildBoardModel(shops, boardAnchor)
end

function Service.init()
	updateRemote = ensureRemote("UpdateCropSellLeaderboard")

	task.defer(function()
		local ok, err = pcall(setupWorldBoard)
		if not ok then
			warn("[CropSellLeaderboardService] setupWorldBoard failed:", err)
		elseif not boardModel then
			warn("[CropSellLeaderboardService] Board model was not created")
		end

		for _, player in Players:GetPlayers() do
			updateRemote:FireClient(player, Service.getEntries())
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			if boardModel then
				updateRemote:FireClient(player, Service.getEntries())
			end
		end)
	end)
end

return Service
