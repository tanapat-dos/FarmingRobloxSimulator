--[[
	MenuBarClient — collapsible left-side navigation bar.

	Collapsed by default into a single hamburger toggle button so it never
	clutters the screen or overlaps the Friend/Pet boost labels. Clicking the
	toggle expands it into the full vertical list of feature buttons (same
	as before, morphing the hamburger into an X); clicking again collapses
	it back down to just the toggle.

	Buttons clone real art templates from ReplicatedStorage.Assets.MenuBarTemplates
	(sourced from the "YourUIPack!" asset pack) so the expanded list matches
	that pack's look (FredokaOne labels, glow hover-base, icon art) instead of
	emoji+flat color pills. Teleport buttons with no matching pack icon fall
	back to the generic emoji template so the whole bar stays visually
	consistent.

	Feature buttons (top to bottom when expanded):
	  🎒 Bag         — open backpack tool list (or press B)
	  🌱 Garden      — teleport to own plot
	  🌾 Seeds       — teleport to seed shop
	  💰 Sell        — teleport to sell shop
	  🥚 Pet Shop    — teleport to pet shop
	  🐾 My Pets     — open PetMenu panel
	  🎣 Fishing     — teleport to the fishing bridge
	  🐟 Fish Shop   — open the Fish Coin Shop panel
	  🌟 Rebirth     — teleport to the Rebirth Altar
	  🏆 Achievements — open Achievements panel
	  🗓️ Daily Login — open Daily Login panel

	A small notification dot mirrors onto the collapsed toggle button
	whenever Daily Login or Achievements have something claimable, so
	players still notice even without expanding the menu.

	Sizing uses fixed pixel offsets (UDim2.fromOffset), which look
	comfortable at ~1280x720 but shrink relative to the screen on higher
	desktop resolutions and can feel small as a touch target on mobile.
	A single "ResponsiveScale" UIScale on the outer Bar frame compensates:
	it scales up gently with viewport width (bigger monitor => bigger UI)
	and applies an extra multiplier on touch devices so buttons stay a
	comfortable tap size, while still floored so tiny phone screens don't
	shrink it below the accessible minimum.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local NavigationHudState = require(ReplicatedStorage:WaitForChild("Modules").NavigationHudState)
local BackpackPanelUi = require(ReplicatedStorage:WaitForChild("Modules").BackpackPanelUi)
local EconomyBalance = require(ReplicatedStorage:WaitForChild("Modules").EconomyBalance)

local templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("MenuBarTemplates")

local COLORS = {
	bar         = Color3.fromRGB(18, 20, 30),
	barBorder   = Color3.fromRGB(40, 44, 60),
	toggle      = Color3.fromRGB(30, 34, 48),
	toggleHover = Color3.fromRGB(44, 50, 68),
	text        = Color3.fromRGB(235, 240, 250),
}

-- Base sizes at 1x scale (roughly 1280x720 desktop). ResponsiveScale below
-- multiplies these at runtime for higher resolutions and touch devices.
-- Bumped up from the original 48px — buttons read as too small/cramped,
-- especially as a touch target on mobile.
local BTN_W       = 64
local BTN_H       = 64
local BAR_PAD_X   = 12
local BAR_PAD_Y   = 10
local BTN_GAP     = 7
local CORNER_R    = 14
local TOGGLE_SIZE = 60

-- Expanded list is a grid instead of one tall column, so it reads as a
-- short, wide block (3 rows for the current 11 buttons) instead of a
-- single stacked column running down the screen.
local GRID_COLUMNS = 4
local GRID_WIDTH = GRID_COLUMNS * BTN_W + (GRID_COLUMNS - 1) * BTN_GAP
local BAR_MAX_WIDTH = GRID_WIDTH + BAR_PAD_X * 2

-- Anchored near the top-left (not vertically centered) so the bar's height
-- never grows down into the bottom-left Friend/Pet boost labels. The bar
-- itself auto-sizes to whichever child is visible (collapsed toggle or the
-- expanded grid) — BAR_MAX_WIDTH is only needed to fully hide it off-screen.
local BAR_TOP_OFFSET = UDim2.new(0, 12, 0.1, 0)
local BAR_HIDDEN_OFFSET = UDim2.new(0, -BAR_MAX_WIDTH - 20, 0.1, 0)

-- ------------------------------------------------------------------ responsive scale
-- Reference viewport width the base pixel sizes above were tuned for.
local REFERENCE_VIEWPORT_WIDTH = 1280
local DESKTOP_MIN_SCALE = 0.95
local DESKTOP_MAX_SCALE = 1.35
local TOUCH_MULTIPLIER = 1.1
local TOUCH_MAX_SCALE = 1.6

local function computeResponsiveScale(): number
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(REFERENCE_VIEWPORT_WIDTH, 720)
	local widthRatio = viewport.X / REFERENCE_VIEWPORT_WIDTH
	local scale = math.clamp(widthRatio, DESKTOP_MIN_SCALE, DESKTOP_MAX_SCALE)

	if UserInputService.TouchEnabled then
		-- Phones/tablets: floor first so a narrow portrait viewport doesn't
		-- shrink the multiplier away, then boost for comfortable tap size.
		scale = math.clamp(scale * TOUCH_MULTIPLIER, DESKTOP_MIN_SCALE, TOUCH_MAX_SCALE)
	end

	return scale
end

-- Button definitions in order. `template` picks the cloned art asset;
-- `icon` is only used by the generic (emoji) template. Laid out as a
-- GRID_COLUMNS-wide grid (see below) instead of one long column, so with
-- 11 buttons this reads as 3 short rows rather than a tall stack.
local ALL_BUTTONS = {
	{ name = "BackpackBtn",       template = "BtnTemplate_Backpack", label = "Bag",      panel = "Backpack" },
	{ name = "GardenTeleport",    template = "BtnTemplate_Generic",  icon = "🌱", label = "Garden" },
	{ name = "SeedsTeleport",     template = "BtnTemplate_Generic",  icon = "🌾", label = "Seeds" },
	{ name = "SellTeleport",      template = "BtnTemplate_Shop",     label = "Sell" },
	{ name = "PetsTeleport",      template = "BtnTemplate_Generic",  icon = "🥚", label = "Pets" },
	{ name = "MyPetsBtn",         template = "BtnTemplate_Generic",  icon = "🐾", label = "My Pets", panel = "PetMenu" },
	{ name = "FishingTeleport",   template = "BtnTemplate_Generic",  icon = "🎣", label = "Fishing" },
	{ name = "FishShopBtn",       template = "BtnTemplate_Generic",  icon = "🐟", label = "Fish Shop", panel = "FishCoinShop" },
	{ name = "RebirthTeleport",   template = "BtnTemplate_Rebirth",  label = "Rebirth" },
	{ name = "RebirthBoardBtn",   template = "BtnTemplate_Generic",  icon = "🏆", label = "Leaderboard", panel = "RebirthLeaderboard" },
	{ name = "AchievementsBtn",   template = "BtnTemplate_Book",     label = "Achieve",  panel = "Achievements" },
	{ name = "CollectionBtn",     template = "BtnTemplate_Book",     icon = "📖", label = "Collection", panel = "Collection" },
	{ name = "DailyLoginBtn",     template = "BtnTemplate_Gift",     label = "Daily",    panel = "DailyLogin" },
}

-- Rebirth is disabled per economy rebalance: drop both Rebirth buttons entirely rather than
-- leaving dead/disabled entries in the bar.
local REBIRTH_ONLY_BUTTONS = { RebirthTeleport = true, RebirthBoardBtn = true }
local BUTTONS = {}
for _, def in ALL_BUTTONS do
	if not REBIRTH_ONLY_BUTTONS[def.name] or EconomyBalance.REBIRTH_ENABLED then
		table.insert(BUTTONS, def)
	end
end

local gui: ScreenGui
local bar: Frame
local barScale: UIScale
local toggleBtn: TextButton
local toggleIconFrame: Frame
local hamburgerBars: { Frame }
local toggleNotifDot: Frame
local buttonsList: Frame
local isVisible = true
local isExpanded = false
local notifDots: { [string]: Frame } = {}

-- ------------------------------------------------------------------ helpers
local function corner(inst: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

-- Roblox's default fonts don't reliably render the ☰ / ✕ Unicode glyphs
-- (shows as a tofu box on some clients), so the toggle icon is drawn from
-- real UI elements instead: three bars for "menu", which rotate into an X.
local function buildHamburgerIcon(parent: GuiObject): (Frame, { Frame })
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "Icon"
	iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	iconFrame.Position = UDim2.fromScale(0.5, 0.5)
	iconFrame.Size = UDim2.fromOffset(28, 22)
	iconFrame.BackgroundTransparency = 1
	iconFrame.Parent = parent

	local bars = {}
	local barYPositions = { 0, 0.5, 1 }
	for i, yPos in ipairs(barYPositions) do
		local barFrame = Instance.new("Frame")
		barFrame.Name = "Bar" .. i
		barFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		barFrame.Position = UDim2.new(0.5, 0, yPos, 0)
		barFrame.Size = UDim2.new(1, 0, 0, 2.4)
		barFrame.BackgroundColor3 = COLORS.text
		barFrame.BorderSizePixel = 0
		barFrame.Parent = iconFrame
		corner(barFrame, 2)
		table.insert(bars, barFrame)
	end

	return iconFrame, bars
end

-- Morph the three hamburger bars into an X (or back) with a quick tween.
local function setHamburgerExpanded(expanded: boolean)
	local topBar, midBar, botBar = hamburgerBars[1], hamburgerBars[2], hamburgerBars[3]
	local quickTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if expanded then
		TweenService:Create(midBar, quickTween, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(topBar, quickTween, { Rotation = 45, Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
		TweenService:Create(botBar, quickTween, { Rotation = -45, Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
	else
		TweenService:Create(midBar, quickTween, { BackgroundTransparency = 0 }):Play()
		TweenService:Create(topBar, quickTween, { Rotation = 0, Position = UDim2.new(0.5, 0, 0, 0) }):Play()
		TweenService:Create(botBar, quickTween, { Rotation = 0, Position = UDim2.new(0.5, 0, 1, 0) }):Play()
	end
end

local function findRebirthAltarPart(): BasePart?
	local altar = workspace:FindFirstChild("RebirthAltar")
	if not altar then
		return nil
	end
	local pedestal = altar:FindFirstChild("Pedestal")
	if pedestal and pedestal:IsA("BasePart") then
		return pedestal
	end
	return altar:FindFirstChildWhichIsA("BasePart")
end

local function findRebirthBoardPart(): BasePart?
	local board = workspace:FindFirstChild("RebirthPriceBoard")
	if not board then
		return nil
	end
	local sign = board:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") then
		return sign
	end
	return board:FindFirstChildWhichIsA("BasePart")
end

local function findBridgePart(): BasePart?
	local bridge = workspace:FindFirstChild("Bridge")
	if not bridge then
		return nil
	end
	if bridge:IsA("BasePart") then
		return bridge
	end
	return bridge:FindFirstChildWhichIsA("BasePart")
end

local function refreshToggleNotifDot()
	if not toggleNotifDot then
		return
	end
	local anyPending = false
	for _, dot in notifDots do
		if dot.Visible then
			anyPending = true
			break
		end
	end
	toggleNotifDot.Visible = anyPending
end

local function setExpanded(expanded: boolean)
	isExpanded = expanded
	buttonsList.Visible = expanded
	setHamburgerExpanded(expanded)

	if expanded then
		-- Quick pop-in once the list becomes visible and has its real size
		local scale = buttonsList:FindFirstChildWhichIsA("UIScale")
		if scale then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }):Play()
		end
	end
end

local function makeBar()
	gui = Instance.new("ScreenGui")
	gui.Name = "MenuBarGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Outer container — anchored top-left so it can't grow down into the
	-- bottom-left Friend/Pet boost labels regardless of button count. Auto
	-- sizes on both axes: narrow (toggle-only) when collapsed, grid-wide
	-- when expanded — no fixed width to fight the grid layout below.
	bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 0)
	bar.Position = BAR_TOP_OFFSET
	bar.Size = UDim2.fromOffset(0, 0)
	bar.AutomaticSize = Enum.AutomaticSize.XY
	bar.BackgroundColor3 = COLORS.bar
	bar.BackgroundTransparency = 0.08
	bar.ClipsDescendants = false
	bar.Parent = gui
	corner(bar, CORNER_R)

	-- Scales the whole bar (toggle + expanded list) up on larger desktop
	-- viewports and touch devices so icons stay comfortably readable/tappable.
	barScale = Instance.new("UIScale")
	barScale.Name = "ResponsiveScale"
	barScale.Scale = computeResponsiveScale()
	barScale.Parent = bar

	-- Organizational folder only (non-visual bookkeeping); actual buttons
	-- stay as direct children of the relevant Frame so UIListLayout can
	-- arrange them — Folder is not a GuiObject and would be skipped.
	local dataFolder = Instance.new("Folder")
	dataFolder.Name = "Data"
	dataFolder.Parent = bar

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = COLORS.barBorder
	barStroke.Thickness = 1.5
	barStroke.Transparency = 0.3
	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barStroke.Parent = bar

	local outerLayout = Instance.new("UIListLayout")
	outerLayout.FillDirection = Enum.FillDirection.Vertical
	outerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	outerLayout.Padding = UDim.new(0, BTN_GAP)
	outerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	outerLayout.Parent = bar

	local barPad = Instance.new("UIPadding")
	barPad.PaddingTop = UDim.new(0, BAR_PAD_Y)
	barPad.PaddingBottom = UDim.new(0, BAR_PAD_Y)
	barPad.PaddingLeft = UDim.new(0, BAR_PAD_X)
	barPad.PaddingRight = UDim.new(0, BAR_PAD_X)
	barPad.Parent = bar

	-- ------------------------------------------------------------ toggle
	toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "ToggleBtn"
	toggleBtn.LayoutOrder = 0
	toggleBtn.Size = UDim2.fromOffset(TOGGLE_SIZE, TOGGLE_SIZE)
	toggleBtn.BackgroundColor3 = COLORS.toggle
	toggleBtn.BackgroundTransparency = 0.1
	toggleBtn.AutoButtonColor = false
	toggleBtn.Text = ""
	toggleBtn.Parent = bar
	corner(toggleBtn, 12)

	toggleIconFrame, hamburgerBars = buildHamburgerIcon(toggleBtn)

	toggleNotifDot = Instance.new("Frame")
	toggleNotifDot.Name = "NotifDot"
	toggleNotifDot.Size = UDim2.fromOffset(10, 10)
	toggleNotifDot.AnchorPoint = Vector2.new(1, 0)
	toggleNotifDot.Position = UDim2.new(1, 2, 0, -2)
	toggleNotifDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	toggleNotifDot.Visible = false
	toggleNotifDot.ZIndex = 10
	toggleNotifDot.Parent = toggleBtn
	corner(toggleNotifDot, 5)

	local toggleScale = Instance.new("UIScale")
	toggleScale.Parent = toggleBtn
	local toggleTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	toggleBtn.MouseEnter:Connect(function()
		toggleBtn.BackgroundColor3 = COLORS.toggleHover
		TweenService:Create(toggleScale, toggleTweenInfo, { Scale = 1.06 }):Play()
	end)
	toggleBtn.MouseLeave:Connect(function()
		toggleBtn.BackgroundColor3 = COLORS.toggle
		TweenService:Create(toggleScale, toggleTweenInfo, { Scale = 1 }):Play()
	end)
	toggleBtn.MouseButton1Down:Connect(function()
		TweenService:Create(toggleScale, toggleTweenInfo, { Scale = 0.93 }):Play()
	end)
	toggleBtn.MouseButton1Up:Connect(function()
		TweenService:Create(toggleScale, toggleTweenInfo, { Scale = 1.06 }):Play()
	end)
	toggleBtn.MouseButton1Click:Connect(function()
		setExpanded(not isExpanded)
	end)

	-- ------------------------------------------------------------ expandable grid
	-- Fixed width sized exactly to GRID_COLUMNS buttons; a UIGridLayout wraps
	-- extra buttons onto new rows automatically instead of one tall column.
	buttonsList = Instance.new("Frame")
	buttonsList.Name = "ButtonsList"
	buttonsList.LayoutOrder = 1
	buttonsList.Size = UDim2.fromOffset(GRID_WIDTH, 0)
	buttonsList.AutomaticSize = Enum.AutomaticSize.Y
	buttonsList.BackgroundTransparency = 1
	buttonsList.Visible = false
	buttonsList.Parent = bar

	local listScale = Instance.new("UIScale")
	listScale.Parent = buttonsList

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(BTN_W, BTN_H)
	gridLayout.CellPadding = UDim2.fromOffset(BTN_GAP, BTN_GAP)
	gridLayout.FillDirectionMaxCells = GRID_COLUMNS
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = buttonsList

	for i, def in ipairs(BUTTONS) do
		local template = templates:FindFirstChild(def.template)
		if not template then
			warn("[MenuBarClient] Missing template:", def.template)
			continue
		end

		local btn = template:Clone()
		btn.Name = def.name
		btn.LayoutOrder = i
		-- Size is driven by UIGridLayout.CellSize on buttonsList, not set here.
		btn.AutoButtonColor = false
		btn.Parent = buttonsList

		-- Generic template's emoji icon needs its text set per-button
		local emojiIcon = btn:FindFirstChild("EmojiIcon")
		if emojiIcon and def.icon then
			emojiIcon.Text = def.icon
		end

		-- Label text + let it auto-fit the smaller bar button (pack's
		-- fixed TextSize was tuned for a much larger panel).
		local label = btn:FindFirstChild("Label01")
		if label and label:IsA("TextLabel") then
			label.Text = def.label
			label.TextScaled = true
			local sizeConstraint = Instance.new("UITextSizeConstraint")
			sizeConstraint.MaxTextSize = 13
			sizeConstraint.Parent = label
		end

		-- Hover / press scale (whole button, works regardless of the
		-- cloned template's internal layout)
		local scale = Instance.new("UIScale")
		scale.Parent = btn
		local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		btn.MouseEnter:Connect(function()
			TweenService:Create(scale, tweenInfo, { Scale = 1.08 }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(scale, tweenInfo, { Scale = 1 }):Play()
		end)
		btn.MouseButton1Down:Connect(function()
			TweenService:Create(scale, tweenInfo, { Scale = 0.93 }):Play()
		end)
		btn.MouseButton1Up:Connect(function()
			TweenService:Create(scale, tweenInfo, { Scale = 1.08 }):Play()
		end)

		-- Notification dot (for Daily Login, Achievements)
		if def.panel == "DailyLogin" or def.panel == "Achievements" then
			local dot = Instance.new("Frame")
			dot.Name = "NotifDot"
			dot.Size = UDim2.fromOffset(10, 10)
			dot.AnchorPoint = Vector2.new(1, 0)
			dot.Position = UDim2.new(1, 2, 0, -2)
			dot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
			dot.Visible = false
			dot.ZIndex = 10
			dot.Parent = btn
			corner(dot, 5)
			notifDots[def.name] = dot
		end

		-- Wire click
		btn.MouseButton1Click:Connect(function()
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")

			if def.name == "GardenTeleport" and hrp then
				for _, plot in ipairs(workspace.Plots:GetChildren()) do
					if plot:GetAttribute("USERID") == player.UserId then
						hrp.CFrame = CFrame.new(plot.TPPart.Position + Vector3.new(0, 3, 0))
						return
					end
				end
			elseif def.name == "SeedsTeleport" and hrp then
				hrp.CFrame = CFrame.new(workspace.Shops.SeedShop.TPPart.Position + Vector3.new(0, 3, 0))
			elseif def.name == "SellTeleport" and hrp then
				hrp.CFrame = CFrame.new(workspace.Shops.SellStuff.TPPart.Position + Vector3.new(0, 3, 0))
			elseif def.name == "PetsTeleport" and hrp then
				hrp.CFrame = CFrame.new(workspace.Shops.PetShop.TPPart.Position + Vector3.new(0, 3, 0))
			elseif def.name == "RebirthTeleport" and hrp then
				local altarPart = findRebirthAltarPart()
				if altarPart then
					hrp.CFrame = CFrame.new(altarPart.Position + Vector3.new(0, 3, 0))
				end
			elseif def.name == "RebirthBoardBtn" and hrp then
				-- Teleport to the physical board first, then fall through below to also
				-- open the podium panel — clicking "Leaderboard" should feel like walking up
				-- to the sign and triggering it, not just opening a floating panel.
				local boardPart = findRebirthBoardPart()
				if boardPart then
					hrp.CFrame = CFrame.new(boardPart.Position + Vector3.new(0, 3, 0))
				end
				local signals = ReplicatedStorage:FindFirstChild("ClientSignals")
				local toggleEvent = signals and signals:FindFirstChild("ToggleRebirthLeaderboard")
				if toggleEvent then
					(toggleEvent :: BindableEvent):Fire()
				end
			elseif def.name == "FishingTeleport" and hrp then
				local bridgePart = findBridgePart()
				if bridgePart then
					-- Raycast down from well above the bridge to land on the actual
					-- walkable deck surface (the mesh's bounding box isn't vertically
					-- symmetric — it includes railings above the deck).
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Include
					rayParams.FilterDescendantsInstances = { bridgePart }
					local origin = bridgePart.Position + Vector3.new(0, bridgePart.Size.Y, 0)
					local hit = workspace:Raycast(origin, Vector3.new(0, -bridgePart.Size.Y * 2, 0), rayParams)
					local standPos = hit and hit.Position or bridgePart.Position
					hrp.CFrame = CFrame.new(standPos + Vector3.new(0, 3, 0))
				end
			elseif def.panel == "Backpack" then
				BackpackPanelUi.toggle()
			elseif def.panel == "PetMenu" then
				local petMenu = remotes:FindFirstChild("PetMenu")
				if petMenu then
					petMenu:FireServer("refresh")
				end
				-- The pet MENU panel (not shop) is in PetMenuGui — trigger its toggle
				local pmGui = playerGui:FindFirstChild("PetMenuGui")
				local panel = pmGui and pmGui:FindFirstChild("Panel")
				if panel then
					panel.Visible = not panel.Visible
				end
			elseif def.panel == "FishCoinShop" then
				local fcGui = playerGui:FindFirstChild("FishCoinShopGui")
				local panel = fcGui and fcGui:FindFirstChild("Panel")
				if panel then
					panel.Visible = not panel.Visible
				end
			elseif def.panel == "Collection" then
				local collectionRemote = remotes:FindFirstChild("Collection")
				if collectionRemote then
					collectionRemote:FireServer("request")
				end
				local colGui = playerGui:FindFirstChild("CollectionGui")
				local panel = colGui and colGui:FindFirstChild("Panel")
				if panel then
					panel.Visible = not panel.Visible
				end
			elseif def.panel == "Achievements" then
				local achieveRemote = remotes:FindFirstChild("Achievements")
				if achieveRemote then
					achieveRemote:FireServer("request")
				end
				local pmGui = playerGui:FindFirstChild("AchievementGui")
				if pmGui then
					pmGui.Enabled = not pmGui.Enabled
				end
				if notifDots["AchievementsBtn"] then
					notifDots["AchievementsBtn"].Visible = false
					refreshToggleNotifDot()
				end
			elseif def.panel == "DailyLogin" then
				local dailyRemote = remotes:FindFirstChild("DailyLogin")
				if dailyRemote then
					dailyRemote:FireServer("request")
				end
				local pmGui = playerGui:FindFirstChild("DailyLoginGui")
				if pmGui then
					pmGui.Enabled = not pmGui.Enabled
				end
				if notifDots["DailyLoginBtn"] then
					notifDots["DailyLoginBtn"].Visible = false
					refreshToggleNotifDot()
				end
			end
		end)
	end

	-- Slide-in animation on load
	bar.Position = BAR_HIDDEN_OFFSET
	task.wait(0.3)
	TweenService:Create(bar, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = BAR_TOP_OFFSET }):Play()
end

-- ------------------------------------------------------------------ responsive rescale
-- Re-applies the scale on viewport changes (window resize on PC, device
-- rotation on mobile) so the bar stays correctly sized without a rejoin.
local function refreshResponsiveScale()
	if barScale then
		barScale.Scale = computeResponsiveScale()
	end
end

local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshResponsiveScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshResponsiveScale)
		refreshResponsiveScale()
	end
end)

-- ------------------------------------------------------------------ visibility sync
local function applyVisibility(visible: boolean)
	isVisible = visible
	if bar then
		if visible then
			TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{ Position = BAR_TOP_OFFSET }):Play()
		else
			TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{ Position = BAR_HIDDEN_OFFSET }):Play()
		end
	end
end

-- ------------------------------------------------------------------ notification dots
-- Show red dot when daily login is claimable
local dailyRemote = remotes:WaitForChild("DailyLogin", 30)
if dailyRemote then
	dailyRemote.OnClientEvent:Connect(function(action)
		local dot = notifDots["DailyLoginBtn"]
		if dot then
			dot.Visible = (action == "claimable")
			refreshToggleNotifDot()
		end
	end)
end

-- Show red dot when a new achievement is unlocked (state contains newly completed unclaimed)
local achieveRemote = remotes:WaitForChild("Achievements", 30)
if achieveRemote then
	achieveRemote.OnClientEvent:Connect(function(action, payload)
		if action == "state" and payload then
			local hasNew = false
			for _, a in ipairs(payload.achievements or {}) do
				if a.completed and not a.claimed then
					hasNew = true
					break
				end
			end
			local dot = notifDots["AchievementsBtn"]
			if dot then
				dot.Visible = hasNew
				refreshToggleNotifDot()
			end
		end
	end)
end

-- ------------------------------------------------------------------ init
NavigationHudState.onChanged(applyVisibility)

BackpackPanelUi.mount(player)

task.spawn(makeBar)
