--!strict
--[[
	RebirthLeaderboardClient — top-3 rebirth podium with live player models.

	Opens from the 🌟 Rebirth menu bar button (View mode) rather than replacing the existing
	teleport-to-altar behavior — the button now shows this leaderboard panel; the physical
	altar itself is still reached by walking there (findRebirthAltarPart in MenuBarClient still
	teleports on click, this panel is opened via a toggle instead, wired below).

	Podium: 3 ViewportFrames, one per rank, each showing a rotating character model:
	  - If the ranked player is in the CURRENT server, clone their live Character (actual
	    fit/appearance right now).
	  - Otherwise, build a generic R15 rig from HumanoidDescription via
	    InsertService/GetHumanoidDescriptionFromUserId, so a #1 rebirther on another server
	    still shows a real avatar, not an empty pedestal.
	  - If both fail (e.g. UserId lookup throttled/offline), falls back to a plain color block
	    so the podium never look broken.

	Below the podium: the same CropSellPriceBoard-style row list pattern (reused visually, not
	via that module — this needs a different column set: Rank / Player / Rebirths).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local CloseIconUi = require(ReplicatedStorage:WaitForChild("Modules").CloseIconUi)

local COLORS = {
	panel = Color3.fromRGB(22, 20, 32),
	header = Color3.fromRGB(34, 28, 50),
	headerDark = Color3.fromRGB(22, 18, 34),
	podiumBg = Color3.fromRGB(30, 26, 44),
	row = Color3.fromRGB(34, 30, 48),
	rowAlt = Color3.fromRGB(28, 25, 40),
	text = Color3.fromRGB(235, 240, 250),
	subtext = Color3.fromRGB(170, 160, 195),
	gold = Color3.fromRGB(255, 210, 80),
	silver = Color3.fromRGB(205, 210, 220),
	bronze = Color3.fromRGB(210, 150, 90),
	purple = Color3.fromRGB(190, 140, 255),
	close = Color3.fromRGB(214, 92, 92),
	empty = Color3.fromRGB(60, 55, 75),
}

local RANK_COLORS = { COLORS.gold, COLORS.silver, COLORS.bronze }
local RANK_ICONS = { "🥇", "🥈", "🥉" }

local PANEL_SIZE = UDim2.fromOffset(620, 560)

local gui: ScreenGui? = nil
local panel: Frame? = nil
local podiumSlots: { Frame } = {}
local rowsFolder: ScrollingFrame? = nil
local rowsLayout: UIListLayout? = nil
local isOpen = false

local function corner(inst: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function stroke(inst: GuiObject, color: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = inst
	return s
end

-- ------------------------------------------------------------------ character model resolution
-- Builds a rotating-display rig into the given ViewportFrame for the given UserId.
-- Tries: (1) a live Player's actual Character in this server, (2) a generic rig built from
-- their HumanoidDescription, (3) gives up silently (caller shows a placeholder instead).
local function fillViewportWithCharacter(viewport: ViewportFrame, userId: number): boolean
	viewport:ClearAllChildren()

	local modelToShow: Model? = nil

	-- (1) Live player in this server — clone their actual current character.
	local livePlayer = Players:GetPlayerByUserId(userId)
	if livePlayer and livePlayer.Character then
		local ok, clone = pcall(function()
			return livePlayer.Character:Clone()
		end)
		if ok and clone then
			modelToShow = clone
		end
	end

	-- (2) Not on this server (or clone failed) — build a generic rig from their avatar.
	if not modelToShow then
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		if ok and description then
			local rigOk, rig = pcall(function()
				return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
			end)
			if rigOk and rig then
				modelToShow = rig
			end
		end
	end

	if not modelToShow then
		return false
	end

	-- Strip scripts/sounds/tools so the podium rig is purely visual (no animation
	-- controller running character scripts inside a ViewportFrame preview).
	for _, descendant in modelToShow:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Tool")
			or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end

	local humanoid = modelToShow:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	for _, part in modelToShow:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end

	modelToShow.Parent = viewport

	local cam = Instance.new("Camera")
	cam.Name = "ViewportCamera"
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	local cf, size = modelToShow:GetBoundingBox()
	local center = cf.Position
	local zoomDistance = math.max(size.X, size.Y, size.Z) * 1.15 + 1.5
	cam.CFrame = CFrame.new(center + Vector3.new(0, size.Y * 0.05, zoomDistance), center)

	-- Slow idle spin so the podium reads as "alive" rather than a static screenshot.
	local spinConn: RBXScriptConnection? = nil
	spinConn = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent or not modelToShow.Parent then
			if spinConn then
				spinConn:Disconnect()
			end
			return
		end
		local currentCF = cam.CFrame
		local rotated = CFrame.new(center) * CFrame.Angles(0, dt * 0.35, 0) * CFrame.new(currentCF.Position - center)
			* CFrame.new(0, 0, 0)
		cam.CFrame = CFrame.new(rotated.Position, center)
	end)

	return true
end

-- ------------------------------------------------------------------ panel construction
local function buildPodiumSlot(rank: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = "Rank" .. rank
	slot.BackgroundColor3 = COLORS.podiumBg
	slot.Parent = nil -- parented by caller
	corner(slot, 12)
	stroke(slot, RANK_COLORS[rank] or COLORS.purple, 2, 0.15)

	local rankBadge = Instance.new("TextLabel")
	rankBadge.Name = "RankBadge"
	rankBadge.Size = UDim2.new(1, 0, 0, 26)
	rankBadge.Position = UDim2.fromOffset(0, 4)
	rankBadge.BackgroundTransparency = 1
	rankBadge.Text = (RANK_ICONS[rank] or "🏅") .. " #" .. tostring(rank)
	rankBadge.TextColor3 = RANK_COLORS[rank] or COLORS.purple
	rankBadge.Font = Enum.Font.GothamBold
	rankBadge.TextSize = 16
	rankBadge.Parent = slot

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Position = UDim2.fromOffset(6, 32)
	viewport.Size = UDim2.new(1, -12, 1, -96)
	viewport.BackgroundTransparency = 1
	viewport.Parent = slot

	local placeholder = Instance.new("TextLabel")
	placeholder.Name = "Placeholder"
	placeholder.Size = UDim2.fromScale(1, 1)
	placeholder.BackgroundTransparency = 1
	placeholder.Text = "❔"
	placeholder.TextColor3 = COLORS.empty
	placeholder.Font = Enum.Font.GothamBold
	placeholder.TextSize = 40
	placeholder.Visible = false
	placeholder.Parent = viewport

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(1, -8, 0, 20)
	nameLabel.Position = UDim2.new(0, 4, 1, -58)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "—"
	nameLabel.TextColor3 = COLORS.text
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = slot

	local rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "RebirthCount"
	rebirthLabel.Size = UDim2.new(1, -8, 0, 30)
	rebirthLabel.Position = UDim2.new(0, 4, 1, -34)
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.Text = "0 Rebirths"
	rebirthLabel.TextColor3 = COLORS.subtext
	rebirthLabel.Font = Enum.Font.GothamBold
	rebirthLabel.TextSize = 14
	rebirthLabel.Parent = slot

	return slot
end

local function buildPanel()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "RebirthLeaderboardGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 14
	gui.Enabled = false
	gui.Parent = playerGui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = PANEL_SIZE
	panel.BackgroundColor3 = COLORS.panel
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, Color3.fromRGB(12, 10, 20), 2, 0.2)

	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, 0, 62)
	headerBar.BackgroundColor3 = COLORS.header
	headerBar.Parent = panel
	corner(headerBar, 18)

	local headerFill = Instance.new("Frame")
	headerFill.Size = UDim2.new(1, 0, 0.5, 0)
	headerFill.Position = UDim2.fromScale(0, 0.5)
	headerFill.BackgroundColor3 = COLORS.header
	headerFill.BorderSizePixel = 0
	headerFill.Parent = headerBar

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(22, 0)
	title.Size = UDim2.new(1, -70, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "🌟  Rebirth Leaderboard"
	title.TextColor3 = COLORS.purple
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.Parent = headerBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.BackgroundColor3 = COLORS.close
	closeBtn.Text = ""
	closeBtn.Parent = headerBar
	corner(closeBtn, 10)
	CloseIconUi.build(closeBtn, { color = COLORS.text })
	closeBtn.MouseButton1Click:Connect(function()
		if gui then
			gui.Enabled = false
			isOpen = false
		end
	end)

	-- ---------------------------------------------------------------- podium row
	local podiumRow = Instance.new("Frame")
	podiumRow.Name = "Podium"
	podiumRow.Position = UDim2.fromOffset(18, 78)
	podiumRow.Size = UDim2.new(1, -36, 0, 220)
	podiumRow.BackgroundTransparency = 1
	podiumRow.Parent = panel

	local podiumLayout = Instance.new("UIListLayout")
	podiumLayout.FillDirection = Enum.FillDirection.Horizontal
	podiumLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	podiumLayout.Padding = UDim.new(0, 10)
	podiumLayout.SortOrder = Enum.SortOrder.LayoutOrder
	podiumLayout.Parent = podiumRow

	podiumSlots = {}
	-- Visual order: #2, #1, #3 (classic podium arrangement), but #1 is taller.
	local visualOrder = { 2, 1, 3 }
	for _, rank in visualOrder do
		local slot = buildPodiumSlot(rank)
		slot.LayoutOrder = rank == 1 and 2 or (rank == 2 and 1 or 3)
		slot.Size = rank == 1 and UDim2.new(0, 190, 1, 0) or UDim2.new(0, 160, 1, -30)
		if rank ~= 1 then
			slot.AnchorPoint = Vector2.new(0, 1)
			slot.Position = UDim2.new(0, 0, 1, 0)
		end
		slot.Parent = podiumRow
		podiumSlots[rank] = slot
	end

	-- ---------------------------------------------------------------- rows list
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Position = UDim2.fromOffset(18, 308)
	header.Size = UDim2.new(1, -36, 0, 30)
	header.BackgroundColor3 = COLORS.headerDark
	header.Parent = panel
	corner(header, 8)

	local rankHeader = Instance.new("TextLabel")
	rankHeader.Size = UDim2.new(0.15, 0, 1, 0)
	rankHeader.BackgroundTransparency = 1
	rankHeader.Text = "Rank"
	rankHeader.TextColor3 = COLORS.subtext
	rankHeader.Font = Enum.Font.GothamBold
	rankHeader.TextSize = 13
	rankHeader.Parent = header

	local playerHeader = Instance.new("TextLabel")
	playerHeader.Position = UDim2.new(0.15, 0, 0, 0)
	playerHeader.Size = UDim2.new(0.55, 0, 1, 0)
	playerHeader.BackgroundTransparency = 1
	playerHeader.Text = "Player"
	playerHeader.TextXAlignment = Enum.TextXAlignment.Left
	playerHeader.TextColor3 = COLORS.subtext
	playerHeader.Font = Enum.Font.GothamBold
	playerHeader.TextSize = 13
	playerHeader.Parent = header

	local rebirthHeader = Instance.new("TextLabel")
	rebirthHeader.Position = UDim2.new(0.7, 0, 0, 0)
	rebirthHeader.Size = UDim2.new(0.3, -10, 1, 0)
	rebirthHeader.BackgroundTransparency = 1
	rebirthHeader.Text = "Rebirths"
	rebirthHeader.TextXAlignment = Enum.TextXAlignment.Right
	rebirthHeader.TextColor3 = COLORS.subtext
	rebirthHeader.Font = Enum.Font.GothamBold
	rebirthHeader.TextSize = 13
	rebirthHeader.Parent = header

	rowsFolder = Instance.new("ScrollingFrame")
	rowsFolder.Name = "Rows"
	rowsFolder.Position = UDim2.fromOffset(18, 344)
	rowsFolder.Size = UDim2.new(1, -36, 1, -362)
	rowsFolder.BackgroundTransparency = 1
	rowsFolder.BorderSizePixel = 0
	rowsFolder.ScrollBarThickness = 6
	rowsFolder.CanvasSize = UDim2.new()
	rowsFolder.Parent = panel

	rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, 4)
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = rowsFolder
	rowsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if rowsFolder and rowsLayout then
			rowsFolder.CanvasSize = UDim2.new(0, 0, 0, rowsLayout.AbsoluteContentSize.Y + 8)
		end
	end)
end

-- ------------------------------------------------------------------ rendering
local function renderPodium(entries: { any })
	for rank = 1, 3 do
		local slot = podiumSlots[rank]
		if not slot then
			continue
		end
		local entry = entries[rank]
		local viewport = slot:FindFirstChild("Viewport") :: ViewportFrame
		local placeholder = viewport and viewport:FindFirstChild("Placeholder")
		local nameLabel = slot:FindFirstChild("PlayerName") :: TextLabel
		local rebirthLabel = slot:FindFirstChild("RebirthCount") :: TextLabel

		if entry then
			nameLabel.Text = entry.PlayerName
			rebirthLabel.Text = ("%d Rebirth%s"):format(entry.Rebirths, entry.Rebirths == 1 and "" or "s")
			local filled = fillViewportWithCharacter(viewport, entry.UserId)
			if placeholder then
				placeholder.Visible = not filled
			end
		else
			nameLabel.Text = "—"
			rebirthLabel.Text = "No one yet"
			if viewport then
				viewport:ClearAllChildren()
				local ph = Instance.new("TextLabel")
				ph.Name = "Placeholder"
				ph.Size = UDim2.fromScale(1, 1)
				ph.BackgroundTransparency = 1
				ph.Text = "❔"
				ph.TextColor3 = COLORS.empty
				ph.Font = Enum.Font.GothamBold
				ph.TextSize = 40
				ph.Parent = viewport
			end
		end
	end
end

local function renderRows(entries: { any })
	if not rowsFolder then
		return
	end
	for _, child in rowsFolder:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, entry in entries do
		local row = Instance.new("Frame")
		row.Name = "Row" .. index
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = index % 2 == 0 and COLORS.rowAlt or COLORS.row
		row.LayoutOrder = index
		row.Parent = rowsFolder
		corner(row, 6)

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Size = UDim2.new(0.15, 0, 1, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Text = (RANK_ICONS[entry.Rank] or ("#" .. tostring(entry.Rank)))
		rankLabel.TextColor3 = RANK_COLORS[entry.Rank] or COLORS.text
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.TextSize = 15
		rankLabel.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.new(0.15, 0, 0, 0)
		nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = entry.PlayerName
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = COLORS.text
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextSize = 14
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = row

		local rebirthLabel = Instance.new("TextLabel")
		rebirthLabel.Position = UDim2.new(0.7, 0, 0, 0)
		rebirthLabel.Size = UDim2.new(0.3, -10, 1, 0)
		rebirthLabel.BackgroundTransparency = 1
		rebirthLabel.Text = tostring(entry.Rebirths)
		rebirthLabel.TextXAlignment = Enum.TextXAlignment.Right
		rebirthLabel.TextColor3 = COLORS.purple
		rebirthLabel.Font = Enum.Font.GothamBold
		rebirthLabel.TextSize = 15
		rebirthLabel.Parent = row
	end

	if #entries == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Text = "No rebirths yet — be the first!"
		empty.TextColor3 = COLORS.subtext
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 14
		empty.Parent = rowsFolder
	end
end

local function renderEntries(entries: { any })
	buildPanel()
	renderPodium(entries)
	renderRows(entries)
end

-- ------------------------------------------------------------------ open/close toggle
local function toggle()
	buildPanel()
	if not gui then
		return
	end
	isOpen = not isOpen
	gui.Enabled = isOpen
end

-- ------------------------------------------------------------------ remotes
local updateRemote = remotes:WaitForChild("UpdateRebirthLeaderboard") :: RemoteEvent
updateRemote.OnClientEvent:Connect(function(entries)
	if typeof(entries) == "table" then
		renderEntries(entries)
	end
end)

task.spawn(function()
	local requestRemote = remotes:WaitForChild("RequestRebirthLeaderboard", 10)
	if requestRemote and requestRemote:IsA("RemoteFunction") then
		local ok, result = pcall(function()
			return (requestRemote :: RemoteFunction):InvokeServer()
		end)
		if ok and typeof(result) == "table" then
			renderEntries(result)
		end
	end
end)

-- ------------------------------------------------------------------ signal for MenuBarClient
local function getClientSignals(): Folder
	local folder = ReplicatedStorage:FindFirstChild("ClientSignals")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientSignals"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local toggleEvent = getClientSignals():FindFirstChild("ToggleRebirthLeaderboard")
if not toggleEvent then
	toggleEvent = Instance.new("BindableEvent")
	toggleEvent.Name = "ToggleRebirthLeaderboard"
	toggleEvent.Parent = getClientSignals()
end
(toggleEvent :: BindableEvent).Event:Connect(toggle)
