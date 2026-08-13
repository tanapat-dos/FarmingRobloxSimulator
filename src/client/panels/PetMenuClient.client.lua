--[[
	PetMenuClient — "My Pets" panel replacing the old backpack pet tools.

	A paw HUD button toggles a procedural panel listing every owned pet;
	clicking a row's button equips that pet (it flies beside you) or
	unequips the currently active one. State comes from PetService's
	PetMenu remote, so the list is always server-truth.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local petMenu = remotes:WaitForChild("PetMenu")
local petUse = remotes:WaitForChild("PetUse")

local COLORS = {
	panel = Color3.fromRGB(25, 28, 36),
	row = Color3.fromRGB(38, 42, 54),
	rowEquipped = Color3.fromRGB(38, 56, 44),
	text = Color3.fromRGB(235, 240, 250),
	subtext = Color3.fromRGB(170, 178, 192),
	accent = Color3.fromRGB(90, 200, 120),
	neutral = Color3.fromRGB(70, 76, 90),
	close = Color3.fromRGB(210, 90, 90),
}

local EGG_COLORS = {
	["Common Egg"] = Color3.fromRGB(180, 186, 196),
	["Uncommon Egg"] = Color3.fromRGB(120, 210, 130),
	["Godly Egg"] = Color3.fromRGB(190, 140, 255),
	["Galactic Egg"] = Color3.fromRGB(110, 210, 245),
	["Divine Egg"] = Color3.fromRGB(255, 214, 110),
}

local gui: ScreenGui
local panel: Frame
local listFrame: ScrollingFrame
local headerLabel: TextLabel
local lastState = {}

local function corner(instance: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function buildUi()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "PetMenuGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")

	-- HUD toggle button
	local toggle = Instance.new("TextButton")
	toggle.Name = "PetMenuToggle"
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	toggle.Position = UDim2.new(1, -12, 0.42, 0)
	toggle.Size = UDim2.fromOffset(52, 52)
	toggle.BackgroundColor3 = COLORS.panel
	toggle.BackgroundTransparency = 0.15
	toggle.Text = "🐾"
	toggle.TextSize = 26
	toggle.Font = Enum.Font.GothamBold
	toggle.TextColor3 = COLORS.text
	toggle.Parent = gui
	corner(toggle, 14)

	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Color = Color3.fromRGB(15, 17, 22)
	toggleStroke.Thickness = 1.5
	toggleStroke.Transparency = 0.35
	toggleStroke.Parent = toggle

	-- Panel
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -74, 0.42, 0)
	panel.Size = UDim2.fromOffset(330, 360)
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
	headerLabel.Size = UDim2.new(1, -24, 0, 40)
	headerLabel.Position = UDim2.fromOffset(14, 4)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "🐾 My Pets"
	headerLabel.RichText = true
	headerLabel.TextColor3 = COLORS.text
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 20
	headerLabel.Parent = panel

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "List"
	listFrame.Position = UDim2.fromOffset(10, 46)
	listFrame.Size = UDim2.new(1, -20, 1, -56)
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

	toggle.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			petMenu:FireServer("refresh")
		end
	end)
end

local function buildRow(pet, layoutOrder: number): Frame
	local row = Instance.new("Frame")
	row.Name = pet.id
	row.Size = UDim2.new(1, -6, 0, 62)
	row.BackgroundColor3 = pet.equipped and COLORS.rowEquipped or COLORS.row
	row.LayoutOrder = layoutOrder
	corner(row, 10)

	local eggBar = Instance.new("Frame")
	eggBar.Size = UDim2.new(0, 4, 1, -12)
	eggBar.Position = UDim2.fromOffset(6, 6)
	eggBar.BackgroundColor3 = EGG_COLORS[pet.egg] or COLORS.subtext
	eggBar.BorderSizePixel = 0
	eggBar.Parent = row
	corner(eggBar, 2)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(18, 7)
	title.Size = UDim2.new(1, -116, 0, 22)
	title.BackgroundTransparency = 1
	title.Text = pet.name
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.Parent = row

	local details = Instance.new("TextLabel")
	details.Position = UDim2.fromOffset(18, 32)
	details.Size = UDim2.new(1, -116, 0, 20)
	details.BackgroundTransparency = 1
	local text = ("+%d%% cash"):format(pet.boostPct or 0)
	if (pet.growthReduction or 0) > 0 then
		text ..= (" · -%d%% grow"):format(pet.growthReduction)
	end
	details.Text = text
	details.TextColor3 = COLORS.subtext
	details.TextXAlignment = Enum.TextXAlignment.Left
	details.Font = Enum.Font.Gotham
	details.TextSize = 13
	details.Parent = row

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(84, 30)
	button.BackgroundColor3 = pet.equipped and COLORS.neutral or COLORS.accent
	button.Text = pet.equipped and "Unequip" or "Equip"
	button.TextColor3 = COLORS.text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Parent = row
	corner(button, 8)

	button.MouseButton1Click:Connect(function()
		if pet.equipped then
			petUse:FireServer("unequip", pet.id)
		else
			petUse:FireServer("equip", pet.id)
		end
	end)

	return row
end

local function renderState(pets)
	buildUi()
	lastState = pets

	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if #pets == 0 then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1, -6, 0, 62)
		empty.BackgroundTransparency = 1
		empty.Parent = listFrame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "No pets yet — roll an egg at the Pet Shop!"
		label.TextWrapped = true
		label.TextColor3 = COLORS.subtext
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.Parent = empty
	else
		for index, pet in pets do
			buildRow(pet, index).Parent = listFrame
		end
	end

	headerLabel.Text = ("🐾 My Pets  <font size=\"14\" color=\"rgb(170,178,192)\">— %d owned</font>"):format(#pets)
end

petMenu.OnClientEvent:Connect(function(action, payload)
	if action == "state" and typeof(payload) == "table" then
		renderState(payload)
	end
end)

buildUi()
petMenu:FireServer("refresh")
