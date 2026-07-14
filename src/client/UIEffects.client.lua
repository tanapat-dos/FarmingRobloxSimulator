local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
---------------------------------

--[[ SOUND CLICKING ]]--

local clickSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Click"):Clone()
clickSound.Parent = playerGui

local function playClickSound()
	clickSound.TimePosition = 0
	clickSound:Play()
end

for _, object in ipairs(playerGui:GetDescendants()) do
	if (object:IsA("TextButton") or object:IsA("ImageButton")) and CollectionService:HasTag(object, "Clicked") then
		object.MouseButton1Click:Connect(function()
			playClickSound()
		end)
	end
end

CollectionService:GetInstanceAddedSignal("Clicked"):Connect(function(object)
	if (object:IsA("TextButton") or object:IsA("ImageButton")) and object:IsDescendantOf(playerGui) then
		object.MouseButton1Click:Connect(function()
			playClickSound()
		end)
	end
end)

---------------------------------

--[[ HOVER EFFECT ]]--

local function applyHoverEffect(button)
	local seedImage = button:WaitForChild("SeedImage")
	local viewportFrame = seedImage:WaitForChild("ViewportFrame")
	local model = viewportFrame:FindFirstChildWhichIsA("Model")

	if not model then
		warn("⚠️ Missing model or PrimaryPart in:", button.Name)
		return
	end

	local cf, size = model:GetBoundingBox()
	local baseCenter = cf.Position
	local baseSize = size.Magnitude
	local baseZoom = baseSize / 2 + 1
	local closerZoom = baseZoom + 0.10
	local defaultCameraCFrame = CFrame.new(baseCenter + Vector3.new(0, 0, baseZoom), baseCenter)

	local bounceTimer = 0
	local connection

	button.MouseEnter:Connect(function()

		connection = RunService.RenderStepped:Connect(function(dt)
			bounceTimer += dt * 6
			
			local offsetZ = math.sin(bounceTimer) * 0.1
			
			local angleX = math.sin(bounceTimer * 1.2) * math.rad(1.5)
			local angleY = math.cos(bounceTimer * 1.5) * math.rad(1.5)
		
			local camPos = baseCenter + Vector3.new(0, 0, closerZoom + offsetZ)
			local lookVector = (baseCenter - camPos).Unit

			local jiggleRotation = CFrame.Angles(angleX, angleY, 0)

			local cam = Instance.new("Camera")
			cam.Name = "ViewportCamera"
			cam.CFrame = CFrame.new(camPos, baseCenter) * jiggleRotation
			cam.Parent = viewportFrame
			viewportFrame.CurrentCamera = cam

			for _, obj in ipairs(viewportFrame:GetChildren()) do
				if obj:IsA("Camera") and obj ~= cam then
					obj:Destroy()
				end
			end
		end)
	end)

	button.MouseLeave:Connect(function()
		if connection then
			connection:Disconnect()
			connection = nil
		end

		local cam = Instance.new("Camera")
		cam.Name = "ViewportCamera"
		cam.CFrame = defaultCameraCFrame
		cam.Parent = viewportFrame
		viewportFrame.CurrentCamera = cam

		for _, obj in ipairs(viewportFrame:GetChildren()) do
			if obj:IsA("Camera") and obj ~= cam then
				obj:Destroy()
			end
		end
	end)
end


for _, object in ipairs(playerGui:GetDescendants()) do
	if (object:IsA("TextButton") or object:IsA("ImageButton")) and CollectionService:HasTag(object, "Hover") then
		applyHoverEffect(object)
	end
end

CollectionService:GetInstanceAddedSignal("Hover"):Connect(function(object)
	if (object:IsA("TextButton") or object:IsA("ImageButton")) and object:IsDescendantOf(playerGui) then
		applyHoverEffect(object)
	end
end)

----------------------------------------------------------

-- CASH NOTIFICATION --

local screenGui = playerGui:WaitForChild("Main") 
local cashLabel = screenGui:WaitForChild("Cash")
local cashSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Coins"):Clone()
cashSound.Parent = playerGui

local function formatNumber(n)
	return tostring(n):reverse():gsub("%d%d%d", "%0,"):reverse():gsub("^,", "")
end

local function createFloatingText(amount)
	local floatingLabel = cashLabel:Clone()
	floatingLabel.Text = ""
	floatingLabel.Name = "FloatingCash"
	floatingLabel.Parent = screenGui

	local basePos = cashLabel.Position
	floatingLabel.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale - 0.05, basePos.Y.Offset)
	floatingLabel.AnchorPoint = cashLabel.AnchorPoint
	floatingLabel.BackgroundTransparency = 1
	floatingLabel.TextStrokeTransparency = 0.6
	floatingLabel.TextScaled = true

	if amount > 0 then
		floatingLabel.Text = "+" .. formatNumber(amount)
		floatingLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
	else
		floatingLabel.Text = "-" .. formatNumber(math.abs(amount))
		floatingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
	end

	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenGoal = {
		Position = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale - 0.1, basePos.Y.Offset),
		TextTransparency = 1,
		TextStrokeTransparency = 1
	}

	local tween = TweenService:Create(floatingLabel, tweenInfo, tweenGoal)
	tween:Play()

	tween.Completed:Connect(function()
		floatingLabel:Destroy()
	end)
end

local function animateCashLabel(startValue, endValue, duration)
	local startTime = tick()
	local connection

	connection = RunService.RenderStepped:Connect(function()
		local now = tick()
		local alpha = math.clamp((now - startTime) / duration, 0, 1)
		local currentValue = math.floor(startValue + (endValue - startValue) * alpha)
		cashLabel.Text = "$" .. formatNumber(currentValue)

		if alpha >= 1 then
			cashLabel.Text = "$" .. formatNumber(endValue)
			connection:Disconnect()
		end
	end)
end

local function setupCashTracker()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")
	local lastCash = cash.Value

	cashLabel.Text = "$" .. formatNumber(lastCash)

	cash:GetPropertyChangedSignal("Value"):Connect(function()
		local newCash = cash.Value
		local diff = newCash - lastCash

		animateCashLabel(lastCash, newCash, 0.6)
		cashSound:Play()

		if diff ~= 0 then
			createFloatingText(diff)
		end

		lastCash = newCash
	end)
end

setupCashTracker()
