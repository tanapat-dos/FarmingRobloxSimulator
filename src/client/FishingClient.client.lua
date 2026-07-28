--[[
	FishingClient — Pangya-style swing-timing minigame for canal fishing.

	Near a FishingZone: press F to cast. A marker sweeps back and forth across a bar; press F
	ONCE when it overlaps the highlighted catch zone (dead-center = Perfect). Shows the target
	fish name + 3D model preview. The marker's position is computed locally from the session's
	startedAt/period (matching the server's own deterministic calculation), so no per-frame
	network sync is needed — only the single press is sent to the server for validation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FishingConfig = require(ReplicatedStorage:WaitForChild("Modules").FishingConfig)
local FishingStandRegistry = require(ReplicatedStorage:WaitForChild("Modules").FishingStandRegistry)
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
	zone = Color3.fromRGB(72, 190, 120),
	zoneStroke = Color3.fromRGB(120, 230, 160),
	zonePerfect = Color3.fromRGB(255, 205, 80),
	marker = Color3.fromRGB(245, 248, 255),
	markerStroke = Color3.fromRGB(30, 34, 44),
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
local catchZoneFrame: Frame? = nil
local perfectZoneFrame: Frame? = nil
local markerFrame: Frame? = nil
local zoneLabel: TextLabel? = nil
local fishNameLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local actionButton: TextButton? = nil

-- Forward-declared: buildGui wires this button to sendPress/tryStartCast, but those are
-- declared with `local function` further down the file. Without a forward declaration,
-- referencing them inside buildGui's body (which runs earlier in the file lexically) would
-- silently resolve to undeclared globals instead of the real local functions.
local sendPress: () -> ()
local tryStartCast: () -> ()

local previewModel: Model? = nil
local previewSpin = 0

local inZone = false
local zoneName: string? = nil
local activeSession: {
	sessionId: string,
	startedAt: number,
	timeout: number,
	period: number,
	zoneMin: number,
	zoneMax: number,
	resolved: boolean,
	modelName: string?,
	maxAttempts: number,
	attemptsUsed: number,
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

	local zone = FishingConfig.resolveZoneAtPosition(root.Position, FishingStandRegistry.collectStandParts())
	if zone then
		inZone = true
		zoneName = zone.displayName
		return
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
	statusLabel.Text = "Press [F] when the marker hits the zone!"
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
	trackFrame.ClipsDescendants = false
	trackFrame.Parent = minigameFrame
	corner(trackFrame, 10)

	-- Catch zone: a fixed highlighted band on the bar (position/width come from the server
	-- per cast). Pressing while the marker overlaps this band catches the fish.
	catchZoneFrame = Instance.new("Frame")
	catchZoneFrame.Name = "CatchZone"
	catchZoneFrame.BackgroundColor3 = COLORS.zone
	catchZoneFrame.BackgroundTransparency = 0.2
	catchZoneFrame.BorderSizePixel = 0
	catchZoneFrame.ZIndex = 2
	catchZoneFrame.Parent = trackFrame
	corner(catchZoneFrame, 6)
	stroke(catchZoneFrame, COLORS.zoneStroke, 2, 0.1)

	-- Perfect sub-zone: centered inside the catch zone, narrower, for the bonus payout.
	perfectZoneFrame = Instance.new("Frame")
	perfectZoneFrame.Name = "PerfectZone"
	perfectZoneFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	perfectZoneFrame.Position = UDim2.fromScale(0.5, 0.5)
	perfectZoneFrame.BackgroundColor3 = COLORS.zonePerfect
	perfectZoneFrame.BackgroundTransparency = 0.25
	perfectZoneFrame.BorderSizePixel = 0
	perfectZoneFrame.ZIndex = 3
	perfectZoneFrame.Parent = catchZoneFrame
	corner(perfectZoneFrame, 4)

	-- Marker: the moving indicator that sweeps 0..1..0 across the full track.
	markerFrame = Instance.new("Frame")
	markerFrame.Name = "Marker"
	markerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	markerFrame.Size = UDim2.new(0, 6, 1, 10)
	markerFrame.Position = UDim2.new(0, 0, 0.5, 0)
	markerFrame.BackgroundColor3 = COLORS.marker
	markerFrame.BorderSizePixel = 0
	markerFrame.ZIndex = 4
	markerFrame.Parent = trackFrame
	corner(markerFrame, 3)
	stroke(markerFrame, COLORS.markerStroke, 1.5, 0.1)

	--[[
		Mobile has no F key, so pressing F to cast/press the timing window is impossible on
		touch. This button calls the SAME tryStartCast/sendPress functions the F key uses
		further down this file — same debounce, same remote calls — just a different input
		trigger. Only shown when UserInputService.TouchEnabled, so PC (mouse/keyboard, and
		gamepad which already has ButtonX support elsewhere in this codebase) never sees it.
	]]
	if UserInputService.TouchEnabled then
		actionButton = Instance.new("TextButton")
		actionButton.Name = "TouchAction"
		actionButton.AnchorPoint = Vector2.new(0.5, 1)
		actionButton.Position = UDim2.new(0.5, 0, 1, -180)
		actionButton.Size = UDim2.fromOffset(160, 64)
		actionButton.BackgroundColor3 = COLORS.zone
		actionButton.Text = "Cast"
		actionButton.TextColor3 = COLORS.text
		actionButton.Font = Enum.Font.GothamBold
		actionButton.TextSize = 22
		actionButton.Visible = false
		actionButton.Parent = gui
		corner(actionButton, 16)
		stroke(actionButton, COLORS.zoneStroke, 2, 0.15)

		actionButton.MouseButton1Click:Connect(function()
			if activeSession then
				sendPress()
			else
				tryStartCast()
			end
		end)
	end
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

	if actionButton then
		actionButton.Text = "Cast"
		actionButton.Visible = inZone
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
	if actionButton then
		actionButton.Text = "Press!"
		actionButton.Visible = visible
	end
	updateHint()
end

-- Renders the catch zone / perfect sub-zone (fixed for the session) and the sweeping marker
-- (computed locally from elapsed time — same deterministic formula the server uses).
local function renderMinigame()
	if not activeSession or not statusLabel then
		return
	end

	if catchZoneFrame then
		local width = activeSession.zoneMax - activeSession.zoneMin
		catchZoneFrame.Size = UDim2.new(width, 0, 1, 0)
		catchZoneFrame.Position = UDim2.new(activeSession.zoneMin, 0, 0, 0)
	end
	if perfectZoneFrame then
		perfectZoneFrame.Size = UDim2.new(FishingConfig.MINIGAME.PERFECT_ZONE_FRACTION, 0, 1, -6)
	end

	local elapsed = os.clock() - activeSession.startedAt
	local markerPosition = FishingConfig.getMarkerPosition(elapsed, activeSession.period)
	if markerFrame then
		markerFrame.Position = UDim2.new(markerPosition, 0, 0.5, 0)
	end

	local remaining = math.max(0, activeSession.timeout - elapsed)
	local attemptsLeft = activeSession.maxAttempts - activeSession.attemptsUsed
	statusLabel.Text = `Press [F] when the marker hits the zone!  •  {attemptsLeft} attempt{if attemptsLeft == 1 then "" else "s"} left  •  {string.format("%.1f", remaining)}s`
end

local function beginMinigame(payload: any)
	activeSession = {
		sessionId = payload.sessionId,
		startedAt = os.clock(),
		timeout = payload.timeout or FishingConfig.MINIGAME.SESSION_TIMEOUT,
		period = payload.period or FishingConfig.MINIGAME.SWEEP_PERIOD_SECONDS,
		zoneMin = payload.zoneMin or 0.4,
		zoneMax = payload.zoneMax or 0.6,
		resolved = false,
		modelName = payload.modelName,
		maxAttempts = payload.maxAttempts or FishingConfig.MINIGAME.MAX_ATTEMPTS,
		attemptsUsed = 0,
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
		statusLabel.Text = "Press [F] when the marker hits the zone!"
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

sendPress = function()
	if not activeSession or activeSession.resolved then
		return
	end

	-- Increment local attempt count optimistically (server is the authority, but this
	-- prevents spamming extra presses faster than the server can respond).
	activeSession.attemptsUsed += 1
	if activeSession.attemptsUsed >= activeSession.maxAttempts then
		activeSession.resolved = true
	end

	fishingRemote:FireServer("press", {
		sessionId = activeSession.sessionId,
	})
end

tryStartCast = function()
	if activeSession then
		return
	end
	fishingRemote:FireServer("start")
end

fishingRemote.OnClientEvent:Connect(function(action: string, payload: any)
	if action == "startMinigame" then
		beginMinigame(payload)
	elseif action == "miss" then
		-- Server confirmed the press missed but the session is still alive (attempts remain).
		if activeSession and payload and payload.sessionId == activeSession.sessionId then
			activeSession.attemptsUsed = activeSession.maxAttempts - (payload.attemptsLeft or 0)
			activeSession.resolved = false -- ensure client doesn't lock out early
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
		sendPress()
	else
		tryStartCast()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	refreshLocalZone()
	updateHint()

	if activeSession then
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

task.spawn(function()
	local deadline = os.clock() + 20
	while workspace:GetAttribute("FishingStandsRegistered") ~= true and os.clock() < deadline do
		task.wait(0.25)
	end
	refreshLocalZone()
	updateHint()
	fishingRemote:FireServer("refreshZone")
end)
