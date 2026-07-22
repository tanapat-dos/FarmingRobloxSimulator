--!strict
-- Simple backpack panel (tools in Backpack + equipped). Client-only.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local BackpackPanelUi = {}

local COLORS = {
	panel = Color3.fromRGB(18, 20, 30),
	panelBorder = Color3.fromRGB(40, 44, 60),
	btn = Color3.fromRGB(30, 34, 48),
	btnHover = Color3.fromRGB(44, 50, 68),
	text = Color3.fromRGB(235, 240, 250),
	subtext = Color3.fromRGB(150, 158, 180),
}

local mounted = false
local panel: Frame? = nil
local title: TextLabel? = nil
local scroll: ScrollingFrame? = nil
local listLayout: UIListLayout? = nil
local player: Player? = nil

local function enableRobloxBackpackCoreGui()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end)
end

local function getToolContainers(): { Instance }
	local out: { Instance } = {}
	if not player then
		return out
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		table.insert(out, backpack)
	end
	local character = player.Character
	if character then
		table.insert(out, character)
	end
	return out
end

local function collectTools(): { Tool }
	local tools: { Tool } = {}
	local seen: { [Tool]: boolean } = {}
	for _, container in getToolContainers() do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and not seen[child] then
				seen[child] = true
				table.insert(tools, child)
			end
		end
	end
	table.sort(tools, function(a, b)
		return a.Name < b.Name
	end)
	return tools
end

local function refreshToolList()
	if not scroll or not title or not listLayout then
		return
	end

	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") and child ~= listLayout then
			child:Destroy()
		end
	end

	local tools = collectTools()
	title.Text = string.format("Backpack (%d)", #tools)

	if #tools == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 13
		empty.TextColor3 = COLORS.subtext
		empty.Text = "No tools yet — harvest or buy seeds."
		empty.Parent = scroll
		return
	end

	for _, tool in tools do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = COLORS.btn
		row.BackgroundTransparency = 0.1
		row.AutoButtonColor = false
		row.Font = Enum.Font.Gotham
		row.TextSize = 13
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = COLORS.text
		row.Text = "  " .. tool.Name
		row.Parent = scroll

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		row.MouseEnter:Connect(function()
			row.BackgroundColor3 = COLORS.btnHover
		end)
		row.MouseLeave:Connect(function()
			row.BackgroundColor3 = COLORS.btn
		end)

		row.MouseButton1Click:Connect(function()
			if not player then
				return
			end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and tool.Parent then
				humanoid:EquipTool(tool)
			end
		end)
	end
end

function BackpackPanelUi.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

function BackpackPanelUi.setOpen(open: boolean)
	if not panel then
		return
	end
	panel.Visible = open
	if open then
		refreshToolList()
	end
end

function BackpackPanelUi.toggle()
	BackpackPanelUi.setOpen(not BackpackPanelUi.isOpen())
end

local function hookContainer(container: Instance)
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and BackpackPanelUi.isOpen() then
			refreshToolList()
		end
	end)
	container.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and BackpackPanelUi.isOpen() then
			refreshToolList()
		end
	end)
end

function BackpackPanelUi.mount(localPlayer: Player)
	if mounted then
		return
	end
	mounted = true
	player = localPlayer

	enableRobloxBackpackCoreGui()
	task.defer(enableRobloxBackpackCoreGui)

	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "BackpackUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local panelFrame = Instance.new("Frame")
	panelFrame.Name = "Panel"
	panelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	panelFrame.Position = UDim2.fromScale(0.5, 0.5)
	panelFrame.Size = UDim2.fromOffset(300, 340)
	panelFrame.BackgroundColor3 = COLORS.panel
	panelFrame.BackgroundTransparency = 0.06
	panelFrame.Visible = false
	panelFrame.Parent = gui
	panel = panelFrame

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panelFrame

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = COLORS.panelBorder
	panelStroke.Thickness = 1.5
	panelStroke.Transparency = 0.3
	panelStroke.Parent = panelFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 0, 32)
	titleLabel.Position = UDim2.fromOffset(8, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 17
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = COLORS.text
	titleLabel.Text = "Backpack"
	titleLabel.Parent = panelFrame
	title = titleLabel

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -16, 0, 32)
	hint.Position = UDim2.fromOffset(8, 38)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = COLORS.subtext
	hint.TextWrapped = true
	hint.Text = "Click a tool to equip. Press B to close. Keys 1–0 = hotbar."
	hint.Parent = panelFrame

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ToolList"
	scrollFrame.Position = UDim2.fromOffset(8, 74)
	scrollFrame.Size = UDim2.new(1, -16, 1, -82)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new()
	scrollFrame.Parent = panelFrame
	scroll = scrollFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.Name
	layout.Parent = scrollFrame
	listLayout = layout

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(28, 28)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -6, 0, 6)
	closeBtn.BackgroundColor3 = COLORS.btn
	closeBtn.Text = "X"
	closeBtn.TextColor3 = COLORS.text
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.Parent = panelFrame
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		BackpackPanelUi.setOpen(false)
	end)

	local function bindCharacter(character: Model)
		hookContainer(character)
	end

	local backpack = localPlayer:WaitForChild("Backpack")
	hookContainer(backpack)
	localPlayer.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		enableRobloxBackpackCoreGui()
		bindCharacter(character)
	end)
	if localPlayer.Character then
		bindCharacter(localPlayer.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			BackpackPanelUi.toggle()
		end
	end)
end

return BackpackPanelUi
