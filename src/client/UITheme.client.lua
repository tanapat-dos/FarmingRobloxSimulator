--[[
	UITheme — runtime theme pass over the existing PlayerGui.

	The place file's UI was assembled ad-hoc (mixed fonts, square corners,
	flat gray frames). Rather than rebuilding every screen in Studio, this
	script normalizes what already exists at runtime:

	- rounded corners + soft strokes on visible frames/buttons
	- one font family everywhere (Gotham / GothamBold)
	- hover / press feedback on the main HUD buttons
	- consistent pill styling for the top boost labels

	Everything is additive and idempotent (tagged with an attribute), so it
	is safe on respawn and safe to re-run while iterating in Studio.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local THEME = {
	cornerRadius = 10,
	buttonCornerRadius = 12,
	strokeColor = Color3.fromRGB(15, 17, 22),
	strokeTransparency = 0.35,
	strokeThickness = 1.5,
	fontBold = Enum.Font.GothamBold,
	fontRegular = Enum.Font.Gotham,
	pillBackground = Color3.fromRGB(25, 28, 36),
	pillTransparency = 0.25,
	pillTextColor = Color3.fromRGB(235, 240, 250),
	hoverScale = 1.06,
	pressScale = 0.94,
	tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local BOLD_FONTS = {
	[Enum.Font.SourceSansBold] = true,
	[Enum.Font.SourceSansSemibold] = true,
	[Enum.Font.FredokaOne] = true,
	[Enum.Font.Cartoon] = true,
	[Enum.Font.GothamBold] = true,
	[Enum.Font.GothamBlack] = true,
	[Enum.Font.LuckiestGuy] = true,
}

local function alreadyThemed(instance: Instance): boolean
	return instance:GetAttribute("UIThemed") == true
end

local function markThemed(instance: Instance)
	instance:SetAttribute("UIThemed", true)
end

local function ensureCorner(instance: Instance, radius: number)
	if not instance:FindFirstChildWhichIsA("UICorner") then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = instance
	end
end

local function ensureStroke(instance: Instance)
	if not instance:FindFirstChildWhichIsA("UIStroke") then
		local stroke = Instance.new("UIStroke")
		stroke.Color = THEME.strokeColor
		stroke.Transparency = THEME.strokeTransparency
		stroke.Thickness = THEME.strokeThickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = instance
	end
end

local function normalizeFont(textObject: TextLabel | TextButton | TextBox)
	local ok, currentFont = pcall(function()
		return textObject.Font
	end)
	if not ok then
		return
	end
	if currentFont == THEME.fontBold or currentFont == THEME.fontRegular then
		return
	end
	textObject.Font = BOLD_FONTS[currentFont] and THEME.fontBold or THEME.fontRegular
end

local function addButtonFeedback(button: GuiButton)
	if button:FindFirstChild("UIThemeScale") then
		return
	end

	local scale = Instance.new("UIScale")
	scale.Name = "UIThemeScale"
	scale.Parent = button

	local function tweenTo(value: number)
		TweenService:Create(scale, THEME.tweenInfo, { Scale = value }):Play()
	end

	button.MouseEnter:Connect(function()
		tweenTo(THEME.hoverScale)
	end)
	button.MouseLeave:Connect(function()
		tweenTo(1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenTo(THEME.pressScale)
	end)
	button.MouseButton1Up:Connect(function()
		tweenTo(THEME.hoverScale)
	end)
end

local function styleAsPill(label: TextLabel)
	label.BackgroundColor3 = THEME.pillBackground
	label.BackgroundTransparency = THEME.pillTransparency
	label.TextColor3 = THEME.pillTextColor
	label.Font = THEME.fontBold
	ensureCorner(label, 8)
end

local function themeInstance(instance: Instance)
	if alreadyThemed(instance) then
		return
	end

	-- Buttons: corners, strokes, fonts, hover/press feedback
	if instance:IsA("TextButton") or instance:IsA("ImageButton") then
		markThemed(instance)
		if instance.BackgroundTransparency < 0.95 then
			ensureCorner(instance, THEME.buttonCornerRadius)
			ensureStroke(instance)
		end
		if instance:IsA("TextButton") then
			normalizeFont(instance)
		end
		addButtonFeedback(instance)
		return
	end

	-- Visible frames become soft panels
	if instance:IsA("Frame") or instance:IsA("ScrollingFrame") then
		markThemed(instance)
		if instance.BackgroundTransparency < 0.7 then
			ensureCorner(instance, THEME.cornerRadius)
			local absoluteSize = instance.AbsoluteSize
			-- Strokes only on panel-sized frames, not every little row
			if absoluteSize.X > 150 and absoluteSize.Y > 100 then
				ensureStroke(instance)
			end
		end
		return
	end

	-- Text: one family, rounded when it has its own background
	if instance:IsA("TextLabel") or instance:IsA("TextBox") then
		markThemed(instance)
		normalizeFont(instance)
		if instance.BackgroundTransparency < 0.7 then
			ensureCorner(instance, 8)
		end
		return
	end
end

local function themeBoostLabels()
	local mainGui = playerGui:FindFirstChild("Main")
	if not mainGui then
		return
	end
	for _, name in { "FriendBoost", "PetBoost" } do
		local label = mainGui:FindFirstChild(name)
		if label and label:IsA("TextLabel") then
			styleAsPill(label)
		end
	end
end

local function themeAll()
	for _, instance in playerGui:GetDescendants() do
		task.spawn(themeInstance, instance)
	end
	themeBoostLabels()
end

-- Initial pass once the main HUD exists, then keep up with new UI
playerGui:WaitForChild("Main", 15)
themeAll()

playerGui.DescendantAdded:Connect(function(instance)
	-- Give sibling layout objects (UICorner etc. from the asset) a beat to arrive
	task.defer(themeInstance, instance)
	if instance.Name == "FriendBoost" or instance.Name == "PetBoost" then
		task.defer(themeBoostLabels)
	end
end)
