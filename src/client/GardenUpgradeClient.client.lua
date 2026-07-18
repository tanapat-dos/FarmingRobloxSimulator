--[[
	GardenUpgradeClient — big icon panel for GardenUpgradeService.

	Opens from the farm's Upgrade Board ProximityPrompt. Renders two large
	upgrade cards (Extra Plots, Growth Speed), each with an icon badge, level,
	description and a buy button. View + request layer only; the server owns
	all validation and state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local upgradeRemote = remotes:WaitForChild("GardenUpgrade")

local COLORS = {
	panel = Color3.fromRGB(28, 32, 42),
	panelTop = Color3.fromRGB(36, 42, 55),
	card = Color3.fromRGB(42, 48, 62),
	cardMax = Color3.fromRGB(40, 56, 46),
	text = Color3.fromRGB(238, 243, 252),
	subtext = Color3.fromRGB(176, 184, 200),
	green = Color3.fromRGB(88, 202, 110),
	greenDark = Color3.fromRGB(58, 150, 78),
	maxBadge = Color3.fromRGB(120, 210, 140),
	price = Color3.fromRGB(255, 216, 120),
	close = Color3.fromRGB(214, 92, 92),
	plotIcon = Color3.fromRGB(96, 190, 104),
	growthIcon = Color3.fromRGB(96, 176, 240),
}

local CARDS = {
	plots = {
		order = 1,
		action = "buyPlot",
		icon = "🌱",
		name = "Extra Plots",
		iconColor = COLORS.plotIcon,
	},
	growth = {
		order = 2,
		action = "buyGrowth",
		icon = "⏳",
		name = "Growth Speed",
		iconColor = COLORS.growthIcon,
	},
}

local gui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local cardRefs: { [string]: any } = {}

local function corner(instance: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function stroke(instance: Instance, color: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = instance
	return s
end

local function formatMoney(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Builds one big upgrade card. Returns the labels/button we refresh later.
local function buildCard(key: string)
	local def = CARDS[key]

	local card = Instance.new("Frame")
	card.Name = def.name
	card.Size = UDim2.new(0.5, -10, 1, 0)
	card.BackgroundColor3 = COLORS.card
	card.LayoutOrder = def.order
	corner(card, 16)
	stroke(card, Color3.fromRGB(18, 20, 27), 1.5, 0.3)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = card

	-- Level pill (top)
	local levelPill = Instance.new("Frame")
	levelPill.Name = "LevelPill"
	levelPill.AnchorPoint = Vector2.new(0.5, 0)
	levelPill.Position = UDim2.fromScale(0.5, 0)
	levelPill.Size = UDim2.fromOffset(120, 30)
	levelPill.BackgroundColor3 = COLORS.panelTop
	levelPill.Parent = card
	corner(levelPill, 15)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.Size = UDim2.fromScale(1, 1)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Lv 0 / 0"
	levelLabel.TextColor3 = COLORS.green
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 16
	levelLabel.Parent = levelPill

	-- Circular icon badge
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0.18)
	badge.Size = UDim2.fromOffset(96, 96)
	badge.BackgroundColor3 = def.iconColor
	badge.Parent = card
	corner(badge, 48)
	stroke(badge, Color3.fromRGB(255, 255, 255), 2, 0.55)

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Text = def.icon
	icon.TextColor3 = COLORS.text
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 52
	icon.Parent = badge

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "TitleName"
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.fromScale(0.5, 0.56)
	nameLabel.Size = UDim2.new(1, 0, 0, 26)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = COLORS.text
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 22
	nameLabel.Parent = card

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Desc"
	descLabel.AnchorPoint = Vector2.new(0.5, 0)
	descLabel.Position = UDim2.fromScale(0.5, 0.68)
	descLabel.Size = UDim2.new(1, 0, 0, 58)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = ""
	descLabel.RichText = true
	descLabel.TextWrapped = true
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextColor3 = COLORS.subtext
	descLabel.Font = Enum.Font.GothamMedium
	descLabel.TextSize = 15
	descLabel.Parent = card

	-- Buy button (bottom)
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "Buy"
	buyButton.AnchorPoint = Vector2.new(0.5, 1)
	buyButton.Position = UDim2.new(0.5, 0, 1, 0)
	buyButton.Size = UDim2.new(1, 0, 0, 46)
	buyButton.BackgroundColor3 = COLORS.green
	buyButton.Text = "Upgrade"
	buyButton.TextColor3 = COLORS.text
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 18
	buyButton.Parent = card
	corner(buyButton, 12)
	stroke(buyButton, COLORS.greenDark, 2, 0.1)

	buyButton.MouseButton1Click:Connect(function()
		upgradeRemote:FireServer(def.action)
	end)

	return {
		card = card,
		level = levelLabel,
		desc = descLabel,
		button = buyButton,
		buttonStroke = buyButton:FindFirstChildWhichIsA("UIStroke"),
	}
end

local function buildPanel()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "GardenUpgradeGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(640, 480)
	panel.BackgroundColor3 = COLORS.panel
	panel.Parent = gui
	corner(panel, 20)
	stroke(panel, Color3.fromRGB(14, 16, 22), 2, 0.2)

	-- Header bar
	local headerBar = Instance.new("Frame")
	headerBar.Name = "Header"
	headerBar.Size = UDim2.new(1, 0, 0, 64)
	headerBar.BackgroundColor3 = COLORS.panelTop
	headerBar.Parent = panel
	corner(headerBar, 20)

	local headerFill = Instance.new("Frame")
	headerFill.Size = UDim2.new(1, 0, 0.5, 0)
	headerFill.Position = UDim2.fromScale(0, 0.5)
	headerFill.BackgroundColor3 = COLORS.panelTop
	headerFill.BorderSizePixel = 0
	headerFill.Parent = headerBar

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -64, 1, 0)
	header.Position = UDim2.fromOffset(24, 0)
	header.BackgroundTransparency = 1
	header.Text = "⬆️  Garden Upgrades"
	header.TextColor3 = COLORS.text
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Font = Enum.Font.GothamBold
	header.TextSize = 26
	header.Parent = headerBar

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -14, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(38, 38)
	closeButton.BackgroundColor3 = COLORS.close
	closeButton.Text = "✕"
	closeButton.TextColor3 = COLORS.text
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.Parent = headerBar
	corner(closeButton, 10)
	closeButton.MouseButton1Click:Connect(function()
		if gui then
			gui.Enabled = false
		end
	end)

	-- Cards container
	local cardsFrame = Instance.new("Frame")
	cardsFrame.Name = "Cards"
	cardsFrame.Position = UDim2.fromOffset(20, 80)
	cardsFrame.Size = UDim2.new(1, -40, 1, -128)
	cardsFrame.BackgroundTransparency = 1
	cardsFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 20)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cardsFrame

	cardRefs.plots = buildCard("plots")
	cardRefs.plots.card.Parent = cardsFrame
	cardRefs.growth = buildCard("growth")
	cardRefs.growth.card.Parent = cardsFrame

	-- Footer / balance
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.AnchorPoint = Vector2.new(0.5, 1)
	statusLabel.Position = UDim2.new(0.5, 0, 1, -14)
	statusLabel.Size = UDim2.new(1, -40, 0, 26)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.RichText = true
	statusLabel.TextColor3 = COLORS.subtext
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 16
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Parent = panel
end

local function applyMaxed(ref)
	ref.card.BackgroundColor3 = COLORS.cardMax
	ref.button.Text = "MAXED"
	ref.button.BackgroundColor3 = COLORS.maxBadge
	ref.button.AutoButtonColor = false
	if ref.buttonStroke then
		ref.buttonStroke.Color = COLORS.maxBadge
	end
end

local function applyBuyable(ref, price: number)
	ref.card.BackgroundColor3 = COLORS.card
	ref.button.Text = "Upgrade  $" .. formatMoney(price)
	ref.button.BackgroundColor3 = COLORS.green
	ref.button.AutoButtonColor = true
	if ref.buttonStroke then
		ref.buttonStroke.Color = COLORS.greenDark
	end
end

local function renderState(state)
	buildPanel()

	-- Extra Plots card
	local plots = state.plots
	local plotRef = cardRefs.plots
	plotRef.level.Text = ("Lv %d / %d"):format(plots.level, plots.maxLevel)
	if plots.maxed then
		plotRef.desc.Text = ("All plots unlocked.\nGrowing up to <b>%d crops</b>."):format(plots.currentCrops)
		applyMaxed(plotRef)
	else
		plotRef.desc.Text = ("Grow up to <b>%d</b> crops now.\nNext level: <font color=\"rgb(144,220,150)\"><b>%d crops</b></font>."):format(
			plots.currentCrops, plots.nextCrops)
		applyBuyable(plotRef, plots.nextPrice)
	end

	-- Growth Speed card
	local growth = state.growth
	local growthRef = cardRefs.growth
	growthRef.level.Text = ("Lv %d / %d"):format(growth.level, growth.maxLevel)
	if growth.maxed then
		growthRef.desc.Text = ("Crops grow <b>%d%% faster</b>.\nFully upgraded!"):format(growth.currentPct)
		applyMaxed(growthRef)
	else
		growthRef.desc.Text = ("Crops grow <b>%d%%</b> faster now.\nNext level: <font color=\"rgb(150,200,255)\"><b>%d%% faster</b></font>."):format(
			growth.currentPct, growth.nextPct)
		applyBuyable(growthRef, growth.nextPrice)
	end

	if statusLabel then
		statusLabel.Text = ("💰 Balance:  <font color=\"rgb(255,216,120)\">$%s</font>"):format(formatMoney(state.cash))
		statusLabel.TextColor3 = COLORS.subtext
	end
end

upgradeRemote.OnClientEvent:Connect(function(action, payload)
	if action == "state" and typeof(payload) == "table" then
		renderState(payload)
	elseif action == "open" then
		buildPanel()
		if gui then
			gui.Enabled = true
		end
	elseif action == "result" and typeof(payload) == "table" then
		buildPanel()
		if statusLabel then
			statusLabel.Text = payload.msg or ""
			statusLabel.TextColor3 = payload.success and COLORS.green or Color3.fromRGB(238, 150, 140)
		end
	end
end)
