--[[
	GearShopClient — panel opened by Maddy the Gear NPC's "OpenGearShop" prompt.

	Lists the same catalog as the crate kiosk (GearService.buildKiosk) since both read
	EconomyBalance.GEAR directly — no server catalog push needed, unlike the seed/fish-coin
	shops where stock rolls and changes at runtime. Buying fires the (previously orphaned)
	BuyGear remote; GearService.init's OnServerEvent handler runs the same buyGear() the crate
	kiosk uses, so price/ownership rules stay identical between both entry points.

	Opened via ProximityPrompts.client.lua's "OpenGearShop" case, same toggle-Panel.Visible
	pattern as PetClient/FishCoinShopClient.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local buyGearRemote = remotes:WaitForChild("BuyGear")

local modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyBalance = require(modules.EconomyBalance)
local CloseIconUi = require(modules.CloseIconUi)

local COLORS = {
	panel = Color3.fromRGB(20, 26, 38),
	header = Color3.fromRGB(28, 36, 52),
	row = Color3.fromRGB(34, 42, 58),
	text = Color3.fromRGB(235, 240, 250),
	subtext = Color3.fromRGB(170, 180, 198),
	accent = Color3.fromRGB(90, 190, 220),
	owned = Color3.fromRGB(120, 128, 145),
	close = Color3.fromRGB(210, 90, 90),
}

local gui: ScreenGui
local panel: Frame
local listFrame: ScrollingFrame
local panelOpen = false

local function corner(instance: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

-- Ordered by price, same convention as the crate kiosk.
local function getGearOrder(): { string }
	local names = {}
	for gearName in EconomyBalance.GEAR do
		table.insert(names, gearName)
	end
	table.sort(names, function(a, b)
		return EconomyBalance.GEAR[a].price < EconomyBalance.GEAR[b].price
	end)
	return names
end

local function ownsNonConsumable(gearName: string): boolean
	local inventoryFolder = player:FindFirstChild("Backpack")
	if not inventoryFolder then
		return false
	end
	-- nonConsumable gear (Pickaxe) is a real permanent tool; if it's not in the backpack or
	-- equipped, the player doesn't have it. Character tools are checked too so the button
	-- doesn't say "Buy" while it's in-hand.
	for _, container in { player.Backpack, player.Character } do
		if container then
			local tool = container:FindFirstChild(gearName)
			if tool then
				return true
			end
		end
	end
	return false
end

local function buildRow(gearName: string, config: any, layoutOrder: number): Frame
	local row = Instance.new("Frame")
	row.Name = gearName
	row.Size = UDim2.new(1, -6, 0, 78)
	row.BackgroundColor3 = COLORS.row
	row.LayoutOrder = layoutOrder
	corner(row, 10)

	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(6, 66)
	swatch.Position = UDim2.fromOffset(6, 6)
	swatch.BackgroundColor3 = config.color or COLORS.subtext
	swatch.BorderSizePixel = 0
	swatch.Parent = row
	corner(swatch, 3)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(24, 8)
	title.Size = UDim2.new(1, -150, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = gearName
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Position = UDim2.fromOffset(24, 28)
	desc.Size = UDim2.new(1, -150, 0, 44)
	desc.BackgroundTransparency = 1
	desc.Text = config.description or ""
	desc.TextColor3 = COLORS.subtext
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.Parent = row

	local button = Instance.new("TextButton")
	button.Name = "BuyButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(110, 40)
	button.TextColor3 = COLORS.text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.Parent = row
	corner(button, 8)

	local function refreshButton()
		if config.nonConsumable and ownsNonConsumable(gearName) then
			button.BackgroundColor3 = COLORS.owned
			button.Text = "Owned"
			button.AutoButtonColor = false
		else
			button.BackgroundColor3 = COLORS.accent
			button.Text = ("$%d"):format(config.price)
			button.AutoButtonColor = true
		end
	end
	refreshButton()

	button.MouseButton1Click:Connect(function()
		if config.nonConsumable and ownsNonConsumable(gearName) then
			return
		end
		buyGearRemote:FireServer(gearName)
		-- Server is authoritative on cash/ownership; Notify toasts report success/failure.
		-- Re-check the "Owned" state shortly after for nonConsumable gear so the button
		-- flips without needing a full panel rebuild.
		if config.nonConsumable then
			task.delay(0.4, refreshButton)
		end
	end)

	return row
end

local function renderCatalog()
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, gearName in getGearOrder() do
		local config = EconomyBalance.GEAR[gearName]
		buildRow(gearName, config, index).Parent = listFrame
	end
end

local function buildUi()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "GearShopPanelGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(430, 420)
	panel.BackgroundColor3 = COLORS.panel
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(12, 15, 22)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, 0, 52)
	headerBar.BackgroundColor3 = COLORS.header
	headerBar.Parent = panel
	corner(headerBar, 14)

	local headerFill = Instance.new("Frame")
	headerFill.Size = UDim2.new(1, 0, 0.5, 0)
	headerFill.Position = UDim2.fromScale(0, 0.5)
	headerFill.BackgroundColor3 = COLORS.header
	headerFill.BorderSizePixel = 0
	headerFill.Parent = headerBar

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -60, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "🛠️ Gear Shop"
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.Parent = headerBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseShop"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.BackgroundColor3 = COLORS.close
	closeBtn.Text = ""
	closeBtn.Parent = headerBar
	corner(closeBtn, 8)
	CloseIconUi.build(closeBtn, { color = COLORS.text })
	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
		panelOpen = false
	end)

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "List"
	listFrame.Position = UDim2.fromOffset(12, 64)
	listFrame.Size = UDim2.new(1, -24, 1, -76)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.new()
	listFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame

	renderCatalog()
end

local function showPanel()
	buildUi()
	renderCatalog()
	panel.Visible = true
	panelOpen = true
end

local function hidePanel()
	if panel then
		panel.Visible = false
	end
	panelOpen = false
end

-- Fired by ProximityPrompts.client.lua on the "OpenGearShop" trigger, same
-- ClientSignals/BindableEvent convention as TogglePetShop.
local clientSignals = ReplicatedStorage:FindFirstChild("ClientSignals")
if not clientSignals then
	clientSignals = Instance.new("Folder")
	clientSignals.Name = "ClientSignals"
	clientSignals.Parent = ReplicatedStorage
end
local toggleGearShop = clientSignals:FindFirstChild("ToggleGearShop")
if not toggleGearShop then
	toggleGearShop = Instance.new("BindableEvent")
	toggleGearShop.Name = "ToggleGearShop"
	toggleGearShop.Parent = clientSignals
end

toggleGearShop.Event:Connect(function(action: string?)
	if action == "close" then
		hidePanel()
	elseif panelOpen then
		hidePanel()
	else
		showPanel()
	end
end)
