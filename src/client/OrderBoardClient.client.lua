--[[
	OrderBoardClient — panel UI for OrderService.

	Opens from the physical board's ProximityPrompt. Fully procedural
	(no .rbxl UI assets); UITheme's pass adds nothing here because the
	panel ships pre-styled to match.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local orderRemote = remotes:WaitForChild("OrderBoard")

local COLORS = {
	panel = Color3.fromRGB(25, 28, 36),
	row = Color3.fromRGB(38, 42, 54),
	rowReady = Color3.fromRGB(38, 56, 44),
	text = Color3.fromRGB(235, 240, 250),
	subtext = Color3.fromRGB(170, 178, 192),
	accent = Color3.fromRGB(90, 200, 120),
	accentDisabled = Color3.fromRGB(70, 76, 90),
	reward = Color3.fromRGB(255, 216, 120),
	close = Color3.fromRGB(210, 90, 90),
}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local rowsFolder: Frame? = nil
local headerLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil

local function corner(instance: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function buildPanel()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "OrderBoardGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 330)
	panel.BackgroundColor3 = COLORS.panel
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	corner(panel, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(15, 17, 22)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = panel

	headerLabel = Instance.new("TextLabel")
	headerLabel.Name = "Header"
	headerLabel.Size = UDim2.new(1, -60, 0, 44)
	headerLabel.Position = UDim2.fromOffset(16, 4)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "📋 Order Board"
	headerLabel.TextColor3 = COLORS.text
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 22
	headerLabel.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 10)
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.BackgroundColor3 = COLORS.close
	closeButton.Text = "✕"
	closeButton.TextColor3 = COLORS.text
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 16
	closeButton.Parent = panel
	corner(closeButton, 8)
	closeButton.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)

	rowsFolder = Instance.new("Frame")
	rowsFolder.Name = "Rows"
	rowsFolder.Position = UDim2.fromOffset(12, 52)
	rowsFolder.Size = UDim2.new(1, -24, 1, -96)
	rowsFolder.BackgroundTransparency = 1
	rowsFolder.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rowsFolder

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.AnchorPoint = Vector2.new(0, 1)
	statusLabel.Position = UDim2.new(0, 16, 1, -10)
	statusLabel.Size = UDim2.new(1, -32, 0, 24)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.RichText = true
	statusLabel.TextColor3 = COLORS.subtext
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 14
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Parent = panel
end

local function buildRow(order, layoutOrder: number): Frame
	local ready = order.have >= order.count

	local row = Instance.new("Frame")
	row.Name = order.id
	row.Size = UDim2.new(1, 0, 0, 72)
	row.BackgroundColor3 = ready and COLORS.rowReady or COLORS.row
	row.LayoutOrder = layoutOrder
	corner(row, 10)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -140, 0, 24)
	title.BackgroundTransparency = 1
	local rarityNote = order.minRarity and (" <font color=\"rgb(170,178,192)\">(" .. order.minRarity .. "+)</font>") or ""
	title.Text = ("%dx %s%s"):format(order.count, order.fruitName, rarityNote)
	title.RichText = true
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.Parent = row

	local progress = Instance.new("TextLabel")
	progress.Position = UDim2.fromOffset(12, 36)
	progress.Size = UDim2.new(1, -140, 0, 20)
	progress.BackgroundTransparency = 1
	progress.Text = ("You have %d / %d"):format(math.min(order.have, order.count), order.count)
	progress.TextColor3 = ready and COLORS.accent or COLORS.subtext
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.Font = Enum.Font.Gotham
	progress.TextSize = 14
	progress.Parent = row

	local reward = Instance.new("TextLabel")
	reward.AnchorPoint = Vector2.new(1, 0)
	reward.Position = UDim2.new(1, -12, 0, 8)
	reward.Size = UDim2.fromOffset(110, 22)
	reward.BackgroundTransparency = 1
	reward.Text = "$" .. tostring(order.reward)
	reward.TextColor3 = COLORS.reward
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward.Font = Enum.Font.GothamBold
	reward.TextSize = 17
	reward.Parent = row

	local deliverButton = Instance.new("TextButton")
	deliverButton.AnchorPoint = Vector2.new(1, 1)
	deliverButton.Position = UDim2.new(1, -12, 1, -8)
	deliverButton.Size = UDim2.fromOffset(96, 28)
	deliverButton.BackgroundColor3 = ready and COLORS.accent or COLORS.accentDisabled
	deliverButton.Text = "Deliver"
	deliverButton.TextColor3 = COLORS.text
	deliverButton.Font = Enum.Font.GothamBold
	deliverButton.TextSize = 15
	deliverButton.AutoButtonColor = ready
	deliverButton.Parent = row
	corner(deliverButton, 8)

	deliverButton.MouseButton1Click:Connect(function()
		if ready then
			orderRemote:FireServer("deliver", order.id)
		else
			orderRemote:FireServer("refreshRequest")
		end
	end)

	return row
end

local function renderState(state)
	buildPanel()

	for _, child in rowsFolder:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, order in state.orders do
		buildRow(order, index).Parent = rowsFolder
	end

	headerLabel.Text = ("📋 Order Board  <font size=\"14\" color=\"rgb(170,178,192)\">— %d completed</font>"):format(state.completed or 0)
	headerLabel.RichText = true

	if state.refreshIn and state.refreshIn > 0 then
		local minutes = math.floor(state.refreshIn / 60)
		local seconds = state.refreshIn % 60
		statusLabel.Text = ("New orders in %d:%02d"):format(minutes, seconds)
	end
end

orderRemote.OnClientEvent:Connect(function(action, payload)
	if action == "state" and typeof(payload) == "table" then
		renderState(payload)
	elseif action == "open" then
		buildPanel()
		gui.Enabled = true
	elseif action == "result" and typeof(payload) == "table" then
		buildPanel()
		statusLabel.Text = payload.msg or ""
		statusLabel.TextColor3 = payload.success and COLORS.accent or Color3.fromRGB(235, 150, 140)
	end
end)
