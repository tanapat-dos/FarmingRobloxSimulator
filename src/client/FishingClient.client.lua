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
local TweenService = game:GetService("TweenService")

local FishingConfig = require(ReplicatedStorage:WaitForChild("Modules").FishingConfig)
local FishingStandRegistry = require(ReplicatedStorage:WaitForChild("Modules").FishingStandRegistry)
local FishingModelPreview = require(ReplicatedStorage:WaitForChild("Modules").FishingModelPreview)
local SeedRarity = require(ReplicatedStorage:WaitForChild("Modules").SeedRarity)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local sounds = ReplicatedStorage:WaitForChild("Sounds")
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
	miss = Color3.fromRGB(235, 90, 90),
	pipFilled = Color3.fromRGB(255, 255, 255),
	pipEmpty = Color3.fromRGB(60, 68, 84),
}

local RARITY_FALLBACK_COLOR = Color3.fromRGB(200, 200, 200)

local function getRarityColor(rarity: string?): Color3
	local value = rarity and SeedRarity[rarity]
	if typeof(value) == "Color3" then
		return value
	end
	return RARITY_FALLBACK_COLOR
end

-- Plays a one-shot clone of a Sounds/<name> template so overlapping plays don't cut each
-- other off. Silently no-ops if the template is missing rather than erroring the whole file.
local function playSound(name: string, volume: number?, pitch: number?)
	local template = sounds:FindFirstChild(name)
	if not (template and template:IsA("Sound")) then
		return
	end
	local sound = template:Clone()
	sound.Volume = volume or template.Volume
	if pitch then
		sound.PlaybackSpeed = pitch
	end
	sound.Parent = player:WaitForChild("PlayerGui")
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

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
local timerBarFrame: Frame? = nil
local timerFillFrame: Frame? = nil
local pipsContainer: Frame? = nil
local pipFrames: { Frame } = {}
local revealGui: ScreenGui? = nil
local dismissActiveReveal: (() -> ())? = nil

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
	minigameFrame.Size = UDim2.fromOffset(560, 208)
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
	statusLabel.Size = UDim2.new(1, -132, 0, 22)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Press [F] when the marker hits the zone!"
	statusLabel.TextColor3 = COLORS.subtext
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 15
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.Parent = minigameFrame

	-- Attempt pips: small dots, one per MAX_ATTEMPTS, filled in from the left. Reads at a
	-- glance ("2 of 3 left") without parsing a sentence, and each miss visibly snuffs one out.
	pipsContainer = Instance.new("Frame")
	pipsContainer.Name = "Pips"
	pipsContainer.Position = UDim2.fromOffset(132, 76)
	pipsContainer.Size = UDim2.fromOffset(120, 14)
	pipsContainer.BackgroundTransparency = 1
	pipsContainer.Parent = minigameFrame

	local pipsLayout = Instance.new("UIListLayout")
	pipsLayout.FillDirection = Enum.FillDirection.Horizontal
	pipsLayout.Padding = UDim.new(0, 6)
	pipsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pipsLayout.Parent = pipsContainer

	-- Countdown bar: a shrinking strip under the pips gives the timeout urgency a visible,
	-- glanceable shape instead of only the "3.2s" text ticking down.
	timerBarFrame = Instance.new("Frame")
	timerBarFrame.Name = "TimerBar"
	timerBarFrame.Position = UDim2.fromOffset(132, 96)
	timerBarFrame.Size = UDim2.new(1, -132, 0, 5)
	timerBarFrame.BackgroundColor3 = COLORS.track
	timerBarFrame.BorderSizePixel = 0
	timerBarFrame.ClipsDescendants = true
	timerBarFrame.Parent = minigameFrame
	corner(timerBarFrame, 3)

	timerFillFrame = Instance.new("Frame")
	timerFillFrame.Name = "Fill"
	timerFillFrame.Size = UDim2.fromScale(1, 1)
	timerFillFrame.BackgroundColor3 = COLORS.zone
	timerFillFrame.BorderSizePixel = 0
	timerFillFrame.Parent = timerBarFrame
	corner(timerFillFrame, 3)

	trackFrame = Instance.new("Frame")
	trackFrame.Name = "Track"
	trackFrame.Position = UDim2.new(0, 0, 0, 112)
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

-- (Re)builds the attempt-pip row for the current session's maxAttempts. Called once per cast
-- rather than every frame since the count is fixed for the session's lifetime.
local function buildPips(maxAttempts: number)
	if not pipsContainer then
		return
	end
	for _, pip in pipFrames do
		pip:Destroy()
	end
	table.clear(pipFrames)

	for i = 1, maxAttempts do
		local pip = Instance.new("Frame")
		pip.Name = "Pip" .. i
		pip.LayoutOrder = i
		pip.Size = UDim2.fromOffset(14, 14)
		pip.BackgroundColor3 = COLORS.pipFilled
		pip.BorderSizePixel = 0
		pip.Parent = pipsContainer
		corner(pip, 7)
		table.insert(pipFrames, pip)
	end
end

-- Snuffs out the pip for the attempt that was just used (left to right), with a quick shrink.
local function popPip(attemptsUsed: number)
	local pip = pipFrames[attemptsUsed]
	if not pip then
		return
	end
	pip.BackgroundColor3 = COLORS.miss
	TweenService:Create(pip, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundColor3 = COLORS.pipEmpty,
	}):Play()
	local scale = pip:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale")
	scale.Parent = pip
	scale.Scale = 1
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.55 }):Play()
end

-- Quick red flash across the track on a miss — the "ouch, so close" cue that mashing gave for
-- free and single-press timing needs an explicit substitute for.
local function flashTrackMiss()
	if not trackFrame then
		return
	end
	local original = trackFrame.BackgroundColor3
	trackFrame.BackgroundColor3 = COLORS.miss
	TweenService:Create(trackFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = original,
	}):Play()
	playSound("Click", 0.4, 0.7)
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

	local elapsed = FishingConfig.now() - activeSession.startedAt
	local markerPosition = FishingConfig.getMarkerPosition(elapsed, activeSession.period)
	if markerFrame then
		markerFrame.Position = UDim2.new(markerPosition, 0, 0.5, 0)
	end

	local remaining = math.max(0, activeSession.timeout - elapsed)
	if timerFillFrame then
		timerFillFrame.Size = UDim2.fromScale(math.clamp(remaining / activeSession.timeout, 0, 1), 1)
		timerFillFrame.BackgroundColor3 = if remaining <= 1.5 then COLORS.miss else COLORS.zone
	end
	statusLabel.Text = "Press [F] when the marker hits the zone!"
end

local function beginMinigame(payload: any)
	activeSession = {
		sessionId = payload.sessionId,
		-- Anchor to the server's absolute start time on the shared GetServerTimeNow clock, NOT
		-- to our arrival time — otherwise download latency offsets our sweep from the
		-- server's and visually-correct presses get scored as misses. Falls back to "now" only
		-- if an old server build omits the field.
		startedAt = payload.startedAt or FishingConfig.now(),
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
	buildPips(activeSession.maxAttempts)

	setMinigameVisible(true)
	renderMinigame()
	playSound("Click", 0.5, 1.15)
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

--[[
	Catch reveal — a full-screen popup so landing a fish actually feels like a payoff instead
	of the minigame panel just quietly closing. Sequence:
	  1. Dim the screen, fish model pops in with an overshoot bounce (Back easing) inside a
	     rarity-colored glow ring, spinning slowly.
	  2. Fish name + rarity badge fade in; "PERFECT!" banner only for a centered hit.
	  3. Cash/Fish Coin rewards count up from 0 rather than snapping in.
	  4. Auto-dismisses after a few seconds, or immediately on click/F/Enter.
	Best-effort: any failure here must never break the fishing loop itself, so it's wrapped in
	pcall by its only caller.
]]
local function buildCatchReveal(payload: any)
	if revealGui then
		revealGui:Destroy()
		revealGui = nil
	end

	local rarityColor = getRarityColor(payload.rarity)
	local perfect = payload.perfect == true

	local revealScreenGui = Instance.new("ScreenGui")
	revealScreenGui.Name = "FishingCatchReveal"
	revealScreenGui.ResetOnSpawn = false
	revealScreenGui.IgnoreGuiInset = true
	revealScreenGui.DisplayOrder = 60
	revealScreenGui.Parent = player:WaitForChild("PlayerGui")
	revealGui = revealScreenGui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Active = true -- plain Frames only fire InputBegan when Active, needed for click-to-dismiss
	dim.Parent = revealScreenGui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(360, 420)
	card.BackgroundColor3 = COLORS.panel
	card.BorderSizePixel = 0
	card.Active = true
	card.Parent = revealScreenGui
	corner(card, 20)
	stroke(card, rarityColor, 3, 0.1)

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.5
	cardScale.Parent = card

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.AnchorPoint = Vector2.new(0.5, 0)
	rarityLabel.Position = UDim2.new(0.5, 0, 0, 16)
	rarityLabel.Size = UDim2.fromOffset(160, 24)
	rarityLabel.BackgroundColor3 = rarityColor
	rarityLabel.BackgroundTransparency = 0.1
	rarityLabel.Text = string.upper(payload.rarity or "Common")
	rarityLabel.TextColor3 = Color3.fromRGB(20, 20, 24)
	rarityLabel.Font = Enum.Font.GothamBlack
	rarityLabel.TextSize = 14
	rarityLabel.TextTransparency = 1
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Parent = card
	corner(rarityLabel, 12)

	-- Glow ring behind the viewport: a soft rarity-colored halo that pulses once on arrival.
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0, 150)
	glow.Size = UDim2.fromOffset(200, 200)
	glow.BackgroundColor3 = rarityColor
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Parent = card
	corner(glow, 100)

	local viewportHolder = Instance.new("Frame")
	viewportHolder.Name = "ViewportHolder"
	viewportHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	viewportHolder.Position = UDim2.new(0.5, 0, 0, 150)
	viewportHolder.Size = UDim2.fromOffset(190, 190)
	viewportHolder.BackgroundColor3 = COLORS.panelInner
	viewportHolder.BorderSizePixel = 0
	viewportHolder.Parent = card
	corner(viewportHolder, 95)
	stroke(viewportHolder, rarityColor, 2, 0.3)

	local viewportScale = Instance.new("UIScale")
	viewportScale.Scale = 0.3
	viewportScale.Parent = viewportHolder

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.new(1, -12, 1, -12)
	viewport.Position = UDim2.fromOffset(6, 6)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(210, 215, 230)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.35, -0.8, -0.5)
	viewport.Parent = viewportHolder
	corner(viewport, 90)

	local revealModel = if payload.modelName then FishingModelPreview.mount(viewport, payload.modelName) else nil

	local perfectBanner = Instance.new("TextLabel")
	perfectBanner.Name = "PerfectBanner"
	perfectBanner.AnchorPoint = Vector2.new(0.5, 0)
	perfectBanner.Position = UDim2.new(0.5, 0, 0, 250)
	perfectBanner.Size = UDim2.fromOffset(260, 30)
	perfectBanner.BackgroundTransparency = 1
	perfectBanner.Text = "★ PERFECT CATCH! ★"
	perfectBanner.TextColor3 = COLORS.zonePerfect
	perfectBanner.Font = Enum.Font.GothamBlack
	perfectBanner.TextSize = 20
	perfectBanner.TextTransparency = 1
	perfectBanner.Visible = perfect
	perfectBanner.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "FishName"
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, perfect and 284 or 256)
	nameLabel.Size = UDim2.fromOffset(320, 32)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = payload.fishName or "Fish"
	nameLabel.TextColor3 = COLORS.text
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 26
	nameLabel.TextTransparency = 1
	nameLabel.Parent = card

	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Name = "Reward"
	rewardLabel.AnchorPoint = Vector2.new(0.5, 0)
	rewardLabel.Position = UDim2.new(0.5, 0, 0, (perfect and 284 or 256) + 38)
	rewardLabel.Size = UDim2.fromOffset(320, 28)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.Text = "+$0"
	rewardLabel.TextColor3 = Color3.fromRGB(120, 230, 140)
	rewardLabel.Font = Enum.Font.GothamBold
	rewardLabel.TextSize = 20
	rewardLabel.TextTransparency = 1
	rewardLabel.Parent = card

	local closeHint = Instance.new("TextLabel")
	closeHint.Name = "CloseHint"
	closeHint.AnchorPoint = Vector2.new(0.5, 1)
	closeHint.Position = UDim2.new(0.5, 0, 1, -14)
	closeHint.Size = UDim2.fromOffset(260, 20)
	closeHint.BackgroundTransparency = 1
	closeHint.Text = "click anywhere to continue"
	closeHint.TextColor3 = COLORS.subtext
	closeHint.Font = Enum.Font.Gotham
	closeHint.TextSize = 13
	closeHint.TextTransparency = 1
	closeHint.Parent = card

	-- ---------------------------------------------------------------- animation sequence
	playSound("Coins", 0.6, perfect and 1.15 or 1)

	TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
	TweenService:Create(cardScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- Fish model pop: overshoot-bounce in, slightly delayed after the card so it reads as a
	-- distinct "reveal" beat rather than everything arriving at once.
	task.delay(0.12, function()
		if not viewportHolder.Parent then
			return
		end
		playSound("Purchase", 0.5, 1.3)
		TweenService:Create(viewportScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local glowTween = TweenService:Create(glow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.55,
		})
		glowTween:Play()
		glowTween.Completed:Connect(function()
			TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()
		end)
	end)

	task.delay(0.3, function()
		if not rarityLabel.Parent then
			return
		end
		TweenService:Create(rarityLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		if perfect then
			TweenService:Create(perfectBanner, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		end
		TweenService:Create(nameLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	end)

	-- Reward count-up: ticks from 0 to the final amount instead of snapping straight to it.
	task.delay(0.45, function()
		if not rewardLabel.Parent then
			return
		end
		TweenService:Create(rewardLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
		local finalReward = tonumber(payload.reward) or 0
		local finalCoins = tonumber(payload.fishCoins) or 0
		local duration = 0.5
		local startTime = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
			local shownReward = math.floor(finalReward * alpha)
			local shownCoins = math.floor(finalCoins * alpha)
			if not rewardLabel.Parent then
				conn:Disconnect()
				return
			end
			rewardLabel.Text = if finalCoins > 0
				then `+$%d  •  +🐟%d`:format(shownReward, shownCoins)
				else `+$%d`:format(shownReward)
			if alpha >= 1 then
				conn:Disconnect()
			end
		end)
	end)

	task.delay(0.6, function()
		if closeHint.Parent then
			TweenService:Create(closeHint, TweenInfo.new(0.3), { TextTransparency = 0.4 }):Play()
		end
	end)

	-- ---------------------------------------------------------------- dismissal
	local dismissed = Instance.new("BindableEvent")
	local closedAlready = false
	local function requestClose()
		if closedAlready then
			return
		end
		closedAlready = true
		dismissActiveReveal = nil
		dismissed:Fire()
	end
	dismissActiveReveal = requestClose

	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			requestClose()
		end
	end)
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			requestClose()
		end
	end)

	local autoCloseDelay = if perfect then 4.5 else 3.5
	task.delay(autoCloseDelay, requestClose)

	local spin = 0
	local spinConn: RBXScriptConnection
	spinConn = RunService.RenderStepped:Connect(function(dt)
		if revealModel and revealModel.PrimaryPart then
			spin += dt * 0.6
			local pivot = revealModel:GetPivot()
			revealModel:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, spin, 0))
		end
	end)

	dismissed.Event:Wait()
	spinConn:Disconnect()

	local fadeOut = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(dim, fadeOut, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(cardScale, fadeOut, { Scale = 0.8 }):Play()
	task.wait(0.25)
	if revealGui == revealScreenGui then
		revealGui = nil
	end
	revealScreenGui:Destroy()
end

local function showCatchReveal(payload: any)
	task.spawn(function()
		local ok, err = pcall(buildCatchReveal, payload)
		if not ok then
			warn("[FishingClient] Catch reveal failed:", err)
			if revealGui then
				revealGui:Destroy()
				revealGui = nil
			end
		end
	end)
end

fishingRemote.OnClientEvent:Connect(function(action: string, payload: any)
	if action == "startMinigame" then
		beginMinigame(payload)
	elseif action == "miss" then
		-- Server confirmed the press missed but the session is still alive (attempts remain).
		if activeSession and payload and payload.sessionId == activeSession.sessionId then
			activeSession.attemptsUsed = activeSession.maxAttempts - (payload.attemptsLeft or 0)
			activeSession.resolved = false -- ensure client doesn't lock out early
			popPip(activeSession.attemptsUsed)
			flashTrackMiss()
		end
	elseif action == "result" then
		endMinigame()
		if payload and payload.success then
			showCatchReveal(payload)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if dismissActiveReveal and (
		input.KeyCode == Enum.KeyCode.F
		or input.KeyCode == Enum.KeyCode.Return
		or input.KeyCode == Enum.KeyCode.Space
	) then
		dismissActiveReveal()
		return
	end

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

		local elapsed = FishingConfig.now() - activeSession.startedAt
		if elapsed >= activeSession.timeout then
			-- Tell the server so it retires the session now rather than up to 0.25s later on
			-- its expiry sweep; otherwise recasting in that window is rejected as "Finish your
			-- current cast first."
			local sessionId = activeSession.sessionId
			endMinigame()
			fishingRemote:FireServer("timedOut", { sessionId = sessionId })
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
