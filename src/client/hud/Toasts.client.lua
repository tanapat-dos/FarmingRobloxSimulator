--[[
	Toasts — lightweight notification popups for the "Notify" remote.

	Server usage: RemoteEvents.Notify:FireClient(player, message, kind)
	  kind: "info" (default) | "success" | "error"

	Messages stack top-center under the weather banner, slide in,
	and fade out after a few seconds. Fully procedural.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local COLORS = {
	info = Color3.fromRGB(120, 170, 255),
	success = Color3.fromRGB(90, 200, 120),
	error = Color3.fromRGB(235, 120, 110),
}

local LIFETIME = 3.5
local MAX_TOASTS = 4

local gui = Instance.new("ScreenGui")
gui.Name = "Toasts"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 48)
container.Size = UDim2.fromOffset(360, 200)
container.BackgroundTransparency = 1
container.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local toastCounter = 0

local function showToast(message: string, kind: string?)
	if typeof(message) ~= "string" or message == "" then
		return
	end

	-- Cap the stack: drop the oldest
	local existing = {}
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(existing, child)
		end
	end
	table.sort(existing, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #existing >= MAX_TOASTS do
		existing[1]:Destroy()
		table.remove(existing, 1)
	end

	toastCounter += 1

	local accent = COLORS[kind or "info"] or COLORS.info

	local label = Instance.new("TextLabel")
	label.LayoutOrder = toastCounter
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
	label.BackgroundTransparency = 1
	label.Text = message
	label.RichText = true
	label.TextColor3 = Color3.fromRGB(235, 240, 250)
	label.TextTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.5
	stroke.Transparency = 1
	stroke.Parent = label

	local fadeIn = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, fadeIn, { BackgroundTransparency = 0.15, TextTransparency = 0 }):Play()
	TweenService:Create(stroke, fadeIn, { Transparency = 0.35 }):Play()

	task.delay(LIFETIME, function()
		if not label.Parent then
			return
		end
		local fadeOut = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, fadeOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fadeOut, { Transparency = 1 }):Play()
		task.wait(0.45)
		label:Destroy()
	end)
end

remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)
