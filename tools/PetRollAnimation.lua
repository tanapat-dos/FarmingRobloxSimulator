-- CSGO-style horizontal reel when a pet egg roll succeeds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local petsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local sounds = ReplicatedStorage:WaitForChild("Sounds")
local SeedRarityColors = require(ReplicatedStorage:WaitForChild("Modules").SeedRarity)

local ITEM_SIZE = 128
local ITEM_PADDING = 8
local SLOT_WIDTH = ITEM_SIZE + ITEM_PADDING
local VIEWPORT_WIDTH = 620
local VIEWPORT_HEIGHT = 150
local WINNER_INDEX = 42
local TOTAL_ITEMS = 50
local SCROLL_DURATION = 5.2

local isAnimating = false

local function getClientSignals()
	local folder = ReplicatedStorage:FindFirstChild("ClientSignals")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientSignals"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function getAnimatingFlag()
	local signals = getClientSignals()
	local flag = signals:FindFirstChild("PetRollAnimating")
	if not flag then
		flag = Instance.new("BoolValue")
		flag.Name = "PetRollAnimating"
		flag.Value = false
		flag.Parent = signals
	end
	return flag
end

local animatingFlag = getAnimatingFlag()

local function playSound(name, volume)
	local template = sounds:FindFirstChild(name)
	if template and template:IsA("Sound") then
		local sound = template:Clone()
		sound.Volume = volume or template.Volume
		sound.Parent = playerGui
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
end

local function getEggPetNames(eggName)
	local folder = petsAssets:FindFirstChild(eggName)
	if not folder then
		return {}
	end
	local names = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(names, child.Name)
		end
	end
	return names
end

local function applyRarityStyle(frame, rarity)
	local style = SeedRarityColors[rarity]
	if typeof(style) == "Color3" then
		frame.BackgroundColor3 = style
	else
		frame.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		if typeof(style) == "Instance" and style:IsA("UIGradient") then
			style:Clone().Parent = frame
		end
	end
end

local function fillViewport(viewport, eggName, petName)
	viewport:ClearAllChildren()
	local folder = petsAssets:FindFirstChild(eggName)
	if not folder then
		return
	end
	local model = folder:FindFirstChild(petName)
	if not model or not model:IsA("Model") then
		return
	end
	local clone = model:Clone()
	clone.Parent = viewport
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local cf, size = clone:GetBoundingBox()
	local center = cf.Position
	local distance = size.Magnitude / 2 + 1.4
	camera.CFrame = CFrame.new(center + Vector3.new(0, 0, distance), center)
end

local function buildStrip(strip, eggName, winnerName, rarity)
	local petNames = getEggPetNames(eggName)
	if #petNames == 0 then
		table.insert(petNames, winnerName)
	end
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ITEM_PADDING)
	layout.Parent = strip
	for index = 1, TOTAL_ITEMS do
		local petName = petNames[math.random(1, #petNames)]
		if index == WINNER_INDEX then
			petName = winnerName
		end
		local card = Instance.new("Frame")
		card.Name = "Item_" .. index
		card.LayoutOrder = index
		card.Size = UDim2.fromOffset(ITEM_SIZE, ITEM_SIZE)
		card.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
		card.BorderSizePixel = 0
		card.Parent = strip
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(70, 70, 85)
		stroke.Parent = card
		local badge = Instance.new("Frame")
		badge.Name = "RarityBadge"
		badge.Size = UDim2.new(1, -10, 0, 18)
		badge.Position = UDim2.new(0, 5, 0, 5)
		badge.BorderSizePixel = 0
		badge.ZIndex = 2
		badge.Parent = card
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 6)
		badgeCorner.Parent = badge
		applyRarityStyle(badge, rarity)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, 0, 1, 0)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 11
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Text = petName
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.ZIndex = 3
		nameLabel.Parent = badge
		local viewport = Instance.new("ViewportFrame")
		viewport.Size = UDim2.new(1, -8, 1, -28)
		viewport.Position = UDim2.new(0, 4, 0, 24)
		viewport.BackgroundTransparency = 1
		viewport.Ambient = Color3.fromRGB(210, 210, 210)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
		viewport.Parent = card
		fillViewport(viewport, eggName, petName)
	end
	strip.Size = UDim2.fromOffset(TOTAL_ITEMS * SLOT_WIDTH, ITEM_SIZE)
end

local function createOverlay()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetRollOverlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end

local function playRollAnimation(result)
	if isAnimating then
		return
	end
	isAnimating = true
	animatingFlag.Value = true
	local eggName = result.eggName
	local petName = result.petName
	local rarity = result.rarity or "Common"
	local boostPct = result.boost and math.floor((result.boost - 1) * 100) or 0
	local growthReduction = result.growthReduction or 0
	local gui = createOverlay()
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.35
	dim.BorderSizePixel = 0
	dim.Parent = gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(VIEWPORT_WIDTH + 48, 320)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local panelStroke = Instance.new("UIStroke", panel)
	panelStroke.Color = Color3.fromRGB(255, 196, 66)
	panelStroke.Thickness = 2
	panelStroke.Transparency = 0.2
	local title = Instance.new("TextLabel", panel)
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.fromOffset(0, 10)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.Text = "Opening Egg..."
	local clip = Instance.new("Frame", panel)
	clip.Name = "ReelClip"
	clip.ClipsDescendants = true
	clip.AnchorPoint = Vector2.new(0.5, 0)
	clip.Position = UDim2.new(0.5, 0, 0, 56)
	clip.Size = UDim2.fromOffset(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	clip.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	clip.BorderSizePixel = 0
	Instance.new("UICorner", clip).CornerRadius = UDim.new(0, 10)
	local strip = Instance.new("Frame", clip)
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	buildStrip(strip, eggName, petName, rarity)
	local marker = Instance.new("Frame", panel)
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.new(0.5, 0, 0, 56)
	marker.Size = UDim2.new(0, 4, 0, VIEWPORT_HEIGHT)
	marker.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	marker.BorderSizePixel = 0
	marker.ZIndex = 5
	local resultLabel = Instance.new("TextLabel", panel)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Size = UDim2.new(1, -20, 0, 52)
	resultLabel.Position = UDim2.new(0, 10, 1, -110)
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.TextSize = 18
	resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	resultLabel.TextTransparency = 1
	resultLabel.TextWrapped = true
	local continueBtn = Instance.new("TextButton", panel)
	continueBtn.Name = "Continue"
	continueBtn.AnchorPoint = Vector2.new(0.5, 1)
	continueBtn.Position = UDim2.new(0.5, 0, 1, -16)
	continueBtn.Size = UDim2.fromOffset(180, 40)
	continueBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 70)
	continueBtn.Font = Enum.Font.GothamBold
	continueBtn.TextSize = 16
	continueBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	continueBtn.Text = "Continue"
	continueBtn.Visible = false
	Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0, 8)
	local endOffset = -(WINNER_INDEX * SLOT_WIDTH) + (VIEWPORT_WIDTH / 2 - ITEM_SIZE / 2)
	local startOffset = endOffset + 2400
	strip.Position = UDim2.fromOffset(startOffset, 0)
	playSound("Purchase", 0.55)
	local lastTickSlot = math.huge
	local tickConnection = RunService.RenderStepped:Connect(function()
		local currentX = strip.Position.X.Offset
		local slot = math.floor((startOffset - currentX) / SLOT_WIDTH)
		if slot ~= lastTickSlot and slot > 0 then
			lastTickSlot = slot
			playSound("Click", 0.18)
		end
	end)
	local scrollTween = TweenService:Create(strip, TweenInfo.new(SCROLL_DURATION, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(endOffset, 0),
	})
	scrollTween:Play()
	scrollTween.Completed:Wait()
	tickConnection:Disconnect()
	playSound("Coins", 0.7)
	title.Text = "You won!"
	local bonusText = string.format("+%d%% Cash Boost", boostPct)
	if growthReduction > 0 then
		bonusText ..= string.format("  •  -%d%% Grow Time", growthReduction)
	end
	resultLabel.Text = string.format("%s  •  %s", petName, bonusText)
	TweenService:Create(resultLabel, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	continueBtn.Visible = true
	local dismissed = Instance.new("BindableEvent")
	continueBtn.MouseButton1Click:Connect(function()
		dismissed:Fire()
	end)
	task.delay(4, function()
		dismissed:Fire()
	end)
	dismissed.Event:Wait()
	gui:Destroy()
	isAnimating = false
	animatingFlag.Value = false
end

local petRollResult = remotes:WaitForChild("PetRollResult", 60)
if petRollResult then
	petRollResult.OnClientEvent:Connect(function(result)
		if result.success and result.petName and result.eggName then
			task.spawn(function()
				local ok, err = pcall(playRollAnimation, result)
				if not ok then
					warn("[PetRollAnimation] Failed:", err)
					isAnimating = false
					animatingFlag.Value = false
				end
			end)
		end
	end)
end
