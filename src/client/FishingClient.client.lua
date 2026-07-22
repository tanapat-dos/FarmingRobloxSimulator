--[[
	FishingClient — mash-F reel minigame for canal fishing.

	Near a FishingZone: press F to cast, then spam F to fill the reel bar
	before the fish escapes. Shows the target fish name + 3D model preview.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FishingConfig = require(ReplicatedStorage:WaitForChild("Modules").FishingConfig)
local FishingModelPreview = require(ReplicatedStorage:WaitForChild("Modules").FishingModelPreview)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local fishingRemote = remotes:WaitForChild("Fishing", 30)
if not fishingRemote then
	warn("[FishingClient] Missing RemoteEvents.Fishing — is FishingService synced to Studio?")
	return
end

local COLORS = {
	panel = Color3.fromRGB(24, 30, 42),
	panelInner = Color3.fromRGB(32, 40, 54),
	track = Color3.fromRGB(52, 60, 78),
	fill = Color3.fromRGB(72, 190, 120),
	fillStroke = Color3.fromRGB(120, 230, 160),
	goal = Color3.fromRGB(245, 248, 255),
	text = Color3.fromRGB(236, 242, 252),
	subtext = Color3.fromRGB(170, 180, 198),
	hint = Color3.fromRGB(130, 210, 255),
	fishName = Color3.fromRGB(144, 220, 255),
}

local gui: ScreenGui? = nil
local hintLabel: TextLabel? = nil
local minigameFrame: Frame? = nil
local previewFrame: Frame? = nil
local fishViewport: ViewportFrame? = nil
local trackFrame: Frame? = nil
local fillFrame: Frame? = nil
local goalFrame: Frame? = nil
local zoneLabel: TextLabel? = nil
local fishNameLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil

local previewModel: Model? = nil
local previewSpin = 0

local inZone = false
local zoneName: string? = nil
local activeSession: {
	sessionId: string,
	progress: number,
	startedAt: number,
	timeout: number,
	lastProgressAt: number,
	modelName: string?,
}? = nil

local zoneRefreshAccumulator = 0

local function getRoot(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function refreshLocalZone()
	local root = getRoot()
	if not root then
		inZone = false
		zoneName = nil
		return
	end

	for _, part in CollectionService:GetTagged(FishingConfig.ZONE_TAG) do
		if part:IsA("BasePart") then
			local zoneId = part:GetAttribute("ZoneId")
			if typeof(zoneId) == "string" then
				local zone = FishingConfig.getZoneById(zoneId)
				if zone and FishingConfig.isPlayerNearZone(root.Position, zone) then
					inZone = true
					zoneName = zone.displayName
					return
				end
			end
		end
	end

	for _, zone in FishingConfig.ZONES do
		if FishingConfig.isPlayerNearZone(root.Position, zone) then
			inZone = true
			zoneName = zone.displayName
			return
		end
	end

	inZone = false
	zoneName = nil
end

local function corner(instance: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = instance
end

local function stroke(instance: Instance, color: Color3, thickness: number, transparency: number?)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.Transparency = transparency or 0
	uiStroke.Parent = instance
	return uiStroke
end

local function clearFishPreview()
	previewModel = nil
	if fishViewport then
		fishViewport:ClearAllChildren()
	end
end

local function showFishPreview(modelName: string?)
	clearFishPreview()
	if not fishViewport or not modelName then
		return
	end

	previewModel = FishingModelPreview.mount(fishViewport, modelName)
	if not previewModel then
		if fishNameLabel then
			fishNameLabel.TextColor3 = COLORS.subtext
		end
	end
end

local function buildGui()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "FishingMinigame"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 18
	gui.Parent = player:WaitForChild("PlayerGui")

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "ZoneHint"
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -120)
	hintLabel.Size = UDim2.fromOffset(420, 42)
	hintLabel.BackgroundColor3 = COLORS.panel
	hintLabel.BackgroundTransparency = 0.15
	hintLabel.Text = ""
	hintLabel.TextColor3 = COLORS.hint
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextSize = 18
	hintLabel.Visible = false
	hintLabel.Parent = gui
	corner(hintLabel, 12)
	stroke(hintLabel, Color3.fromRGB(18, 22, 30), 1.5, 0.25)

	minigameFrame = Instance.new("Frame")
	minigameFrame.Name = "Minigame"
	minigameFrame.AnchorPoint = Vector2.new(0.5, 1)
	minigameFrame.Position = UDim2.new(0.5, 0, 1, -36)
	minigameFrame.Size = UDim2.fromOffset(560, 188)
	minigameFrame.BackgroundColor3 = COLORS.panel
	minigameFrame.Visible = false
	minigameFrame.Parent = gui
	corner(minigameFrame, 16)
	stroke(minigameFrame, Color3.fromRGB(18, 22, 30), 2, 0.15)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = minigameFrame

	previewFrame = Instance.new("Frame")
	previewFrame.Name = "FishPreview"
	previewFrame.Size = UDim2.fromOffset(118, 92)
	previewFrame.BackgroundColor3 = COLORS.panelInner
	previewFrame.Parent = minigameFrame
	corner(previewFrame, 12)
	stroke(previewFrame, Color3.fromRGB(18, 22, 30), 1.5, 0.35)

	fishViewport = Instance.new("ViewportFrame")
	fishViewport.Name = "Viewport"
	fishViewport.Size = UDim2.new(1, -8, 1, -8)
	fishViewport.Position = UDim2.fromOffset(4, 4)
	fishViewport.BackgroundTransparency = 1
	fishViewport.Ambient = Color3.fromRGB(205, 215, 230)
	fishViewport.LightColor = Color3.fromRGB(255, 255, 255)
	fishViewport.LightDirection = Vector3.new(-0.35, -0.8, -0.5)
	fishViewport.Parent = previewFrame
	corner(fishViewport, 10)

	zoneLabel = Instance.new("TextLabel")
	zoneLabel.Name = "Zone"
	zoneLabel.Position = UDim2.fromOffset(132, 0)
	zoneLabel.Size = UDim2.new(1, -132, 0, 18)
	zoneLabel.BackgroundTransparency = 1
	zoneLabel.Text = "Canal Fishing"
	zoneLabel.TextColor3 = COLORS.subtext
	zoneLabel.Font = Enum.Font.Gotham
	zoneLabel.TextSize = 14
	zoneLabel.TextXAlignment = Enum.TextXAlignment.Left
	zoneLabel.Parent = minigameFrame

	fishNameLabel = Instance.new("TextLabel")
	fishNameLabel.Name = "FishName"
	fishNameLabel.Position = UDim2.fromOffset(132, 20)
	fishNameLabel.Size = UDim2.new(1, -132, 0, 30)
	fishNameLabel.BackgroundTransparency = 1
	fishNameLabel.Text = "Hooked Fish"
	fishNameLabel.TextColor3 = COLORS.fishName
	fishNameLabel.Font = Enum.Font.GothamBold
	fishNameLabel.TextSize = 24
	fishNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	fishNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	fishNameLabel.Parent = minigameFrame

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Position = UDim2.fromOffset(132, 52)
	statusLabel.Size = UDim2.new(1, -132, 0, 36)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Spam [F] to reel it in"
	statusLabel.TextColor3 = COLORS.subtext
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 15
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.Parent = minigameFrame

	trackFrame = Instance.new("Frame")
	trackFrame.Name = "Track"
	trackFrame.Position = UDim2.new(0, 0, 0, 104)
	trackFrame.Size = UDim2.new(1, 0, 0, 34)
	trackFrame.BackgroundColor3 = COLORS.track
	trackFrame.ClipsDescendants = true
	trackFrame.Parent = minigameFrame
	corner(trackFrame, 10)

	fillFrame = Instance.new("Frame")
	fillFrame.Name = "Fill"
	fillFrame.Size = UDim2.fromScale(0, 1)
	fillFrame.BackgroundColor3 = COLORS.fill
	fillFrame.BackgroundTransparency = 0.15
	fillFrame.BorderSizePixel = 0
	fillFrame.Parent = trackFrame
	corner(fillFrame, 10)
	stroke(fillFrame, COLORS.fillStroke, 2, 0.1)

	goalFrame = Instance.new("Frame")
	goalFrame.Name = "Goal"
	goalFrame.AnchorPoint = Vector2.new(1, 0.5)
	goalFrame.Size = UDim2.new(0, 4, 1, -8)
	goalFrame.Position = UDim2.new(1, -4, 0.5, 0)
	goalFrame.BackgroundColor3 = COLORS.goal
	goalFrame.BorderSizePixel = 0
	goalFrame.Parent = trackFrame
	corner(goalFrame, 2)
end

local function updateHint()
	buildGui()
	if not hintLabel then
		return
	end

	if activeSession then
		hintLabel.Visible = false
		return
	end

	if inZone then
		hintLabel.Visible = true
		hintLabel.Text = `Press [F] to start fishing{zoneName and ` at {zoneName}` or ""}`
	else
		hintLabel.Visible = false
	end
end

local function setMinigameVisible(visible: boolean)
	buildGui()
	if minigameFrame then
		minigameFrame.Visible = visible
	end
	if not visible then
		clearFishPreview()
	end
	updateHint()
end

local function applyLocalDecay()
	if not activeSession then
		return
	end

	local now = os.clock()
	local elapsed = now - activeSession.lastProgressAt
	if elapsed <= 0 then
		return
	end

	activeSession.progress = FishingConfig.applyDecay(activeSession.progress, elapsed)
	activeSession.lastProgressAt = now
end

local function setProgress(progress: number)
	if not activeSession then
		return
	end

	activeSession.progress = math.clamp(progress, 0, 1)
	activeSession.lastProgressAt = os.clock()
end

local function renderMinigame()
	if not activeSession or not fillFrame or not statusLabel then
		return
	end

	fillFrame.Size = UDim2.new(activeSession.progress, 0, 1, 0)

	local elapsed = os.clock() - activeSession.startedAt
	local remaining = math.max(0, activeSession.timeout - elapsed)
	local percent = math.floor(activeSession.progress * 100 + 0.5)
	statusLabel.Text = `Spam [F] to reel it in  •  {percent}%  •  {string.format("%.1f", remaining)}s left`
end

local function beginMinigame(payload: any)
	activeSession = {
		sessionId = payload.sessionId,
		progress = payload.progress or 0,
		startedAt = os.clock(),
		timeout = payload.timeout or FishingConfig.MINIGAME.SESSION_TIMEOUT,
		lastProgressAt = os.clock(),
		modelName = payload.modelName,
	}

	if zoneLabel then
		zoneLabel.Text = payload.displayName or "Canal Fishing"
	end
	if fishNameLabel then
		fishNameLabel.Text = payload.fishName or "Unknown Fish"
		fishNameLabel.TextColor3 = COLORS.fishName
	end
	if statusLabel then
		statusLabel.TextColor3 = COLORS.subtext
		statusLabel.Text = "Spam [F] to reel it in"
	end

	showFishPreview(payload.modelName)
	previewSpin = 0

	setMinigameVisible(true)
	renderMinigame()
end

local function endMinigame()
	activeSession = nil
	setMinigameVisible(false)
	updateHint()
end

local function sendTap()
	if not activeSession then
		return
	end

	applyLocalDecay()
	setProgress(FishingConfig.applyTap(activeSession.progress))
	renderMinigame()
	fishingRemote:FireServer("tap", {
		sessionId = activeSession.sessionId,
	})
end

local function tryStartCast()
	if activeSession then
		return
	end
	fishingRemote:FireServer("start")
end

fishingRemote.OnClientEvent:Connect(function(action: string, payload: any)
	if action == "startMinigame" then
		beginMinigame(payload)
	elseif action == "progress" then
		if activeSession and payload and payload.sessionId == activeSession.sessionId then
			setProgress(payload.progress or 0)
			renderMinigame()
		end
	elseif action == "result" then
		endMinigame()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode ~= Enum.KeyCode.F then
		if input.KeyCode == Enum.KeyCode.Escape and activeSession then
			local sessionId = activeSession.sessionId
			endMinigame()
			fishingRemote:FireServer("cancel", { sessionId = sessionId })
		end
		return
	end

	if processed and not activeSession then
		return
	end

	if activeSession then
		sendTap()
	else
		tryStartCast()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	refreshLocalZone()
	updateHint()

	if activeSession then
		applyLocalDecay()
		renderMinigame()

		if previewModel and previewModel.PrimaryPart then
			previewSpin += dt * 0.8
			local pivot = previewModel:GetPivot()
			previewModel:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, previewSpin, 0))
		end

		local elapsed = os.clock() - activeSession.startedAt
		if elapsed >= activeSession.timeout then
			endMinigame()
		end
	end

	zoneRefreshAccumulator += dt
	if zoneRefreshAccumulator >= 1 then
		zoneRefreshAccumulator = 0
		fishingRemote:FireServer("refreshZone")
	end
end)

buildGui()
fishingRemote:FireServer("refreshZone")
