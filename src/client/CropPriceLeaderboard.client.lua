--!strict
-- Crop sell leaderboard panel (synced with world board at sell NPC).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local CropSellPriceBoard = require(ReplicatedStorage:WaitForChild("Modules").CropSellPriceBoard)
local NavigationHudState = require(ReplicatedStorage:WaitForChild("Modules").NavigationHudState)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local blur = game.Lighting:WaitForChild("Blur")

local PANEL_SIZE = UDim2.new(0.58, 0, 0.82, 0)
local panelOpen = false
local mainButtons: Instance? = nil
local scrollFrame: ScrollingFrame
local listLayout: UIListLayout

local function getClientSignals(): Folder
	local folder = ReplicatedStorage:FindFirstChild("ClientSignals")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientSignals"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function getToggleEvent(): BindableEvent
	local signals = getClientSignals()
	local toggleEvent = signals:FindFirstChild("ToggleCropPriceBoard")
	if not toggleEvent then
		toggleEvent = Instance.new("BindableEvent")
		toggleEvent.Name = "ToggleCropPriceBoard"
		toggleEvent.Parent = signals
	end
	return toggleEvent :: BindableEvent
end

local toggleCropPriceBoard = getToggleEvent()

local function setHudButtonsVisible(visible: boolean)
	if not mainButtons then
		mainButtons = playerGui:WaitForChild("Main"):WaitForChild("Buttons")
	end
	if visible then
		NavigationHudState.applyMainButtons(mainButtons)
	else
		for _, child in mainButtons:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
	end
end

local function toggleBlur(enable: boolean)
	TweenService:Create(blur, TweenInfo.new(0.3), { Size = enable and 15 or 0 }):Play()
end

local function createLabel(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	textSize: number,
	align: Enum.TextXAlignment,
	color: Color3?,
	bold: boolean?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = pos
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextSize = textSize
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = align
	label.Text = text
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function getColumnOffset(index: number): number
	local offset = 0
	for i = 1, index - 1 do
		offset += CropSellPriceBoard.COLUMNS[i].width
	end
	return offset
end

local function refreshCanvasSize()
	if scrollFrame and listLayout then
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
	end
end

local function renderEntries(entries: { CropSellPriceBoard.LeaderboardEntry })
	CropSellPriceBoard.renderRows(scrollFrame, entries, 56)
	refreshCanvasSize()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CropPriceLeaderboard"
screenGui.ResetOnSpawn = false
screenGui.Enabled = true
screenGui.DisplayOrder = 12
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Frame"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0, 0, 0, 0)
panel.Visible = false
panel.BackgroundColor3 = Color3.fromRGB(24, 34, 24)
panel.BorderSizePixel = 0
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(72, 110, 72)
stroke.Thickness = 2

createLabel(
	panel,
	"Title",
	"Crop Sell Leaderboard",
	UDim2.new(1, -80, 0, 34),
	UDim2.new(0, 20, 0, 14),
	24,
	Enum.TextXAlignment.Left,
	Color3.fromRGB(240, 240, 240),
	true
)
createLabel(
	panel,
	"Subtitle",
	"Rank · Player · Crop · Weight · Selling Price",
	UDim2.new(1, -40, 0, 18),
	UDim2.new(0, 20, 0, 46),
	13,
	Enum.TextXAlignment.Left,
	Color3.fromRGB(170, 190, 170)
)

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseShop"
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.Position = UDim2.new(1, -44, 0, 12)
closeButton.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = panel
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)
CollectionService:AddTag(closeButton, "Clicked")

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, -24, 0, 32)
header.Position = UDim2.new(0, 12, 0, 72)
header.BackgroundColor3 = Color3.fromRGB(18, 28, 18)
header.BorderSizePixel = 0
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

for index, column in CropSellPriceBoard.COLUMNS do
	createLabel(
		header,
		column.name,
		column.name,
		UDim2.new(column.width, -6, 1, 0),
		UDim2.new(getColumnOffset(index), 3, 0, 0),
		14,
		column.align,
		Color3.fromRGB(180, 200, 180),
		true
	)
end

scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollingFrame"
scrollFrame.Size = UDim2.new(1, -24, 1, -116)
scrollFrame.Position = UDim2.new(0, 12, 0, 108)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new()
scrollFrame.Parent = panel

listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshCanvasSize)

renderEntries(CropSellPriceBoard.getDisplayEntries(nil))

local updateRemote = remotes:WaitForChild("UpdateCropSellLeaderboard") :: RemoteEvent
updateRemote.OnClientEvent:Connect(function(entries: { CropSellPriceBoard.LeaderboardEntry })
	if typeof(entries) == "table" then
		renderEntries(entries)
	end
end)

local function showPanel()
	if panelOpen then
		return
	end
	panelOpen = true
	screenGui.DisplayOrder = 12
	pcall(setHudButtonsVisible, false)
	panel.Visible = true
	panel.Size = UDim2.new(0, 0, 0, 0)
	toggleBlur(true)
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = PANEL_SIZE,
	}):Play()
end

local function hidePanel()
	if not panelOpen then
		return
	end
	panelOpen = false
	TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
	}):Play()
	toggleBlur(false)
	task.delay(0.2, function()
		panel.Visible = false
		pcall(setHudButtonsVisible, true)
	end)
end

closeButton.MouseButton1Click:Connect(hidePanel)

toggleCropPriceBoard.Event:Connect(function(action: string?)
	if action == "close" then
		hidePanel()
	elseif panelOpen then
		hidePanel()
	else
		showPanel()
	end
end)
