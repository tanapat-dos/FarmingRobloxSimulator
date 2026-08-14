--!strict
-- Press H to toggle Garden / Seeds / Sell / Pets navigation HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local NavigationHudState = require(ReplicatedStorage:WaitForChild("Modules").NavigationHudState)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function refreshHud()
	NavigationHudState.applyToPlayerGui(playerGui)
end

local function showHint(text: string)
	local existing = playerGui:FindFirstChild("NavigationHudHint")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "NavigationHudHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(260, 28)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 44)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.fromRGB(235, 240, 250)
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.Text = text
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	task.delay(2, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

NavigationHudState.onChanged(refreshHud)

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "Main" or child.Name == "PetMenuGui" then
		refreshHud()
	end
end)

task.defer(function()
	playerGui:WaitForChild("Main", 30)
	refreshHud()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.H then
		return
	end

	NavigationHudState.toggle()
	local message = if NavigationHudState.isVisible()
		then "Navigation HUD shown (H to hide)"
		else "Navigation HUD hidden (H to show)"
	showHint(message)
end)
