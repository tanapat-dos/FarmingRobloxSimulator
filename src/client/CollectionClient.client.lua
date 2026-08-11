--[[
	CollectionClient — "Collection" panel: browsable checklist of every crop, fish, pet, and
	mutation the player has ever discovered. Read-only, no rewards granted here (that's
	AchievementService) — this is the completionist "how much have I seen" screen.

	Opened via the "Collection" button in the left menu bar (MenuBarClient), same
	toggle-Panel.Visible + fire-a-refresh pattern as PetMenu/Achievements.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local collectionRemote = remotes:WaitForChild("Collection")
local SeedRarityColors = require(ReplicatedStorage:WaitForChild("Modules").SeedRarity)
local CloseIconUi = require(ReplicatedStorage:WaitForChild("Modules").CloseIconUi)

local COLORS = {
	panel = Color3.fromRGB(25, 28, 36),
	tabBar = Color3.fromRGB(20, 22, 29),
	tabActive = Color3.fromRGB(58, 64, 82),
	tabInactive = Color3.fromRGB(32, 36, 46),
	cardFound = Color3.fromRGB(38, 42, 54),
	cardMissing = Color3.fromRGB(26, 28, 36),
	text = Color3.fromRGB(235, 240, 250),
	subtext = Color3.fromRGB(150, 158, 172),
	missing = Color3.fromRGB(80, 86, 100),
	close = Color3.fromRGB(210, 90, 90),
	accent = Color3.fromRGB(120, 210, 245),
}

local FALLBACK_RARITY_COLOR = Color3.fromRGB(180, 186, 196)

local MUTATION_COLORS = {
	Golden = Color3.fromRGB(255, 214, 90),
	Rainbow = Color3.fromRGB(210, 140, 255),
	Wet = Color3.fromRGB(120, 175, 255),
	Shocked = Color3.fromRGB(255, 240, 120),
}

local TABS = { "Crops", "Fish", "Pets", "Mutations" }

local gui: ScreenGui
local panel: Frame
local headerLabel: TextLabel
local tabBar: Frame
local listFrame: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Crops"
local lastState: any = nil

-- Forward-declared: tab button click handlers (wired in buildUi, which runs before this is
-- defined lexically) call renderCurrentTab. Without this, that reference would silently
-- resolve to an undeclared global instead of the real local function.
local renderCurrentTab: () -> ()

local function corner(instance: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function getRarityColor(rarity: string?): Color3
	local value = rarity and SeedRarityColors[rarity]
	if typeof(value) == "Color3" then
		return value
	end
	return FALLBACK_RARITY_COLOR
end

local function buildUi()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "CollectionGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 480)
	panel.BackgroundColor3 = COLORS.panel
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(15, 17, 22)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = panel

	headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, -60, 0, 44)
	headerLabel.Position = UDim2.fromOffset(14, 4)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "📖 Collection"
	headerLabel.RichText = true
	headerLabel.TextColor3 = COLORS.text
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 20
	headerLabel.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 10)
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.BackgroundColor3 = COLORS.close
	closeButton.Text = ""
	closeButton.Parent = panel
	corner(closeButton, 8)
	CloseIconUi.build(closeButton, { color = COLORS.text })
	closeButton.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.Position = UDim2.fromOffset(10, 48)
	tabBar.Size = UDim2.new(1, -20, 0, 32)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	for index, tabName in TABS do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = tabName
		tabButton.LayoutOrder = index
		tabButton.Size = UDim2.new(1 / #TABS, -5, 1, 0)
		tabButton.BackgroundColor3 = COLORS.tabInactive
		tabButton.Text = tabName
		tabButton.TextColor3 = COLORS.subtext
		tabButton.Font = Enum.Font.GothamBold
		tabButton.TextSize = 14
		tabButton.Parent = tabBar
		corner(tabButton, 8)

		tabButton.MouseButton1Click:Connect(function()
			currentTab = tabName
			-- render defined below; forward ref via task.defer avoids ordering issues
			task.defer(function()
				if lastState then
					renderCurrentTab()
				end
			end)
		end)

		tabButtons[tabName] = tabButton
	end

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "List"
	listFrame.Position = UDim2.fromOffset(10, 88)
	listFrame.Size = UDim2.new(1, -20, 1, -98)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.new()
	listFrame.Parent = panel

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(128, 64)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = listFrame
end

local function updateTabHighlight()
	for tabName, button in tabButtons do
		local active = tabName == currentTab
		button.BackgroundColor3 = active and COLORS.tabActive or COLORS.tabInactive
		button.TextColor3 = active and COLORS.text or COLORS.subtext
	end
end

local function buildEntryCard(discovered: boolean, title: string, accentColor: Color3, layoutOrder: number): Frame
	local card = Instance.new("Frame")
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = discovered and COLORS.cardFound or COLORS.cardMissing
	corner(card, 8)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 4, 1, -10)
	bar.Position = UDim2.fromOffset(5, 5)
	bar.BackgroundColor3 = discovered and accentColor or COLORS.missing
	bar.BorderSizePixel = 0
	bar.Parent = card
	corner(bar, 2)

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(16, 0)
	label.Size = UDim2.new(1, -22, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = discovered and title or "???"
	label.TextColor3 = discovered and COLORS.text or COLORS.missing
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.Parent = card

	if not discovered then
		local lock = Instance.new("TextLabel")
		lock.AnchorPoint = Vector2.new(1, 1)
		lock.Position = UDim2.new(1, -6, 1, -4)
		lock.Size = UDim2.fromOffset(16, 16)
		lock.BackgroundTransparency = 1
		lock.Text = "🔒"
		lock.TextSize = 12
		lock.Parent = card
	end

	return card
end

renderCurrentTab = function()
	if not lastState or not listFrame then
		return
	end
	updateTabHighlight()

	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if currentTab == "Crops" then
		for index, entry in lastState.crops do
			buildEntryCard(entry.discovered, entry.name, getRarityColor(entry.rarity), index).Parent = listFrame
		end
	elseif currentTab == "Fish" then
		for index, entry in lastState.fish do
			buildEntryCard(entry.discovered, entry.displayName, getRarityColor(entry.rarity), index).Parent = listFrame
		end
	elseif currentTab == "Pets" then
		for index, entry in lastState.pets do
			buildEntryCard(entry.discovered, entry.name, getRarityColor(nil), index).Parent = listFrame
		end
	elseif currentTab == "Mutations" then
		for index, entry in lastState.mutations do
			local accent = MUTATION_COLORS[entry.name] or FALLBACK_RARITY_COLOR
			buildEntryCard(entry.discovered, entry.name, accent, index).Parent = listFrame
		end
	end

	local totals = lastState.totals[currentTab:lower()]
	if totals then
		headerLabel.Text = ("📖 Collection  <font size=\"14\" color=\"rgb(150,158,172)\">— %s: %d/%d</font>"):format(
			currentTab, totals.have, totals.total)
	end
end

local function renderState(state)
	buildUi()
	lastState = state
	renderCurrentTab()
end

collectionRemote.OnClientEvent:Connect(function(action, payload)
	if action == "state" and typeof(payload) == "table" then
		renderState(payload)
	end
end)

buildUi()
collectionRemote:FireServer("request")
