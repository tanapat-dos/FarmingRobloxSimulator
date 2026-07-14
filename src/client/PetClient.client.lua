local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local petsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")

local clientSignals = ReplicatedStorage:FindFirstChild("ClientSignals")
if not clientSignals then
	clientSignals = Instance.new("Folder")
	clientSignals.Name = "ClientSignals"
	clientSignals.Parent = ReplicatedStorage
end
local togglePetShop = clientSignals:FindFirstChild("TogglePetShop")
if not togglePetShop then
	togglePetShop = Instance.new("BindableEvent")
	togglePetShop.Name = "TogglePetShop"
	togglePetShop.Parent = clientSignals
end

local EGG_ORDER = { "Common Egg", "Uncommon Egg", "Godly Egg", "Galactic Egg", "Divine Egg" }
local EGG_DATA = {
	["Common Egg"]   = { cost = 100,   boost = 1.05, rarity = "Common",    color = Color3.fromRGB(180,180,180) },
	["Uncommon Egg"] = { cost = 500,   boost = 1.15, rarity = "Uncommon",  color = Color3.fromRGB(100,200,100) },
	["Godly Egg"]    = { cost = 2000,  boost = 1.30, rarity = "Rare",      color = Color3.fromRGB(80,130,255)  },
	["Galactic Egg"] = { cost = 7500,  boost = 1.55, rarity = "Epic",      color = Color3.fromRGB(180,80,255)  },
	["Divine Egg"]   = { cost = 25000, boost = 2.00, rarity = "Legendary", color = Color3.fromRGB(255,200,50)  },
}
local PINK      = Color3.fromRGB(255, 150, 200)
local PINK_DARK = Color3.fromRGB(220, 80, 150)
local PINK_BG   = Color3.fromRGB(255, 220, 240)

local activePetModel = nil
local followConnection = nil

local function despawnPet()
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
	if activePetModel then
		activePetModel:Destroy()
		activePetModel = nil
	end
end

local function spawnPet(eggName, petName)
	despawnPet()

	local folder = petsAssets:FindFirstChild(eggName)
	if not folder then
		warn("[PetClient] Missing egg folder:", eggName)
		return
	end
	local src = folder:FindFirstChild(petName)
	if not src or not src:IsA("Model") then
		warn("[PetClient] Missing pet model:", petName, "in", eggName)
		return
	end

	local model = src:Clone()

	-- Anchor all parts so gravity doesn't sink them; Heartbeat drives position
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = false
		end
	end

	if not model.PrimaryPart then
		local primary = model:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			model.PrimaryPart = primary
		end
	end

	pcall(function()
		model:ScaleTo(0.75)
	end)

	local char = player.Character
	if not char then
		char = player.CharacterAdded:Wait()
	end
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if hrp then
		model:PivotTo(hrp.CFrame * CFrame.new(2.5, 0, 0))
	end

	model.Parent = workspace
	activePetModel = model

	followConnection = RunService.Heartbeat:Connect(function()
		if not activePetModel or not activePetModel.Parent then
			return
		end
		local character = player.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local pivot = activePetModel:GetPivot()
		local target = root.CFrame * CFrame.new(2.5, 0, 0)
		activePetModel:PivotTo(pivot:Lerp(target, 0.15))
	end)
end

local function makeLabel(parent, text, size, pos, textSize, bold, color)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize or 14
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextColor3 = color or Color3.fromRGB(50, 30, 50)
	label.TextScaled = false
	label.Parent = parent
	return label
end

local function makeButton(parent, text, size, pos, bg, textColor)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = pos
	button.BackgroundColor3 = bg or PINK
	button.BorderSizePixel = 0
	button.Text = text
	button.TextSize = 13
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = textColor or Color3.fromRGB(255,255,255)
	button.AutoButtonColor = true
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	button.Parent = parent
	return button
end

local function showToast(parent, text, color)
	local toast = makeLabel(parent, text, UDim2.new(0.88, 0, 0, 24), UDim2.new(0.06, 0, 1, -32), 12, true, color)
	toast.BackgroundTransparency = 0.2
	toast.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	toast.ZIndex = 5
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)
	task.delay(3, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

local petGui = Instance.new("ScreenGui")
petGui.Name = "PetShop"
petGui.ResetOnSpawn = false
petGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
petGui.Parent = PlayerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0.38, 0, 0, 0)
panel.Position = UDim2.new(0.31, 0, 0.1, 0)
panel.BackgroundColor3 = PINK_BG
panel.BorderSizePixel = 0
panel.Visible = false
panel.ClipsDescendants = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
panel.Parent = petGui

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = PINK_DARK
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)
makeLabel(titleBar, "🐾 Pet Shop", UDim2.new(0.8, 0, 0, 22), UDim2.new(0.05, 0, 0, 3), 16, true, Color3.fromRGB(255,255,255))
makeLabel(titleBar, "Roll pets — equip from your backpack", UDim2.new(0.8, 0, 0, 16), UDim2.new(0.05, 0, 0, 25), 10, false, Color3.fromRGB(255, 220, 240))
local closeBtn = makeButton(titleBar, "✕", UDim2.new(0, 32, 0, 32), UDim2.new(1, -40, 0.5, -16), Color3.fromRGB(200, 60, 120))

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Scroll"
scroll.Size = UDim2.new(1, -16, 1, -56)
scroll.Position = UDim2.new(0, 8, 0, 52)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = PINK_DARK
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingBottom = UDim.new(0, 4)
listPadding.Parent = scroll
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 16)
end)

makeLabel(scroll, "🥚 Roll for Pets", UDim2.new(1, 0, 0, 24), UDim2.new(0, 4, 0, 0), 13, true, PINK_DARK).LayoutOrder = 0

for index, eggName in ipairs(EGG_ORDER) do
	local egg = EGG_DATA[eggName]
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 72)
	card.BackgroundColor3 = Color3.fromRGB(255, 235, 248)
	card.BorderSizePixel = 0
	card.LayoutOrder = index
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	card.Parent = scroll

	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 6, 1, 0)
	stripe.BackgroundColor3 = egg.color
	stripe.BorderSizePixel = 0
	Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 10)
	stripe.Parent = card

	makeLabel(card, eggName, UDim2.new(0.55, 0, 0, 24), UDim2.new(0.06, 0, 0, 8), 15, true)
	makeLabel(card, egg.rarity, UDim2.new(0.55, 0, 0, 20), UDim2.new(0.06, 0, 0, 30), 12, false, egg.color)
	makeLabel(card, "$" .. tostring(egg.cost), UDim2.new(0.55, 0, 0, 20), UDim2.new(0.06, 0, 0, 50), 12, false, Color3.fromRGB(80, 60, 80))
	local boostPct = math.floor((egg.boost - 1) * 100)
	makeLabel(card, "+" .. boostPct .. "% cash", UDim2.new(0.28, 0, 0, 20), UDim2.new(0.62, 0, 0, 12), 11, false, Color3.fromRGB(60, 150, 60))

	local rollBtn = makeButton(card, "🥚 Roll!", UDim2.new(0.28, 0, 0, 28), UDim2.new(0.62, 0, 0, 34), PINK_DARK)
	local capturedEgg = eggName
	rollBtn.MouseButton1Click:Connect(function()
		rollBtn.Text = "Rolling..."
		rollBtn.AutoButtonColor = false
		local petRoll = remotes:WaitForChild("PetRoll", 5)
		if petRoll then
			petRoll:FireServer(capturedEgg)
		end
		task.delay(1.5, function()
			rollBtn.Text = "🥚 Roll!"
			rollBtn.AutoButtonColor = true
		end)
	end)
end

local panelOpen = false
local function openPanel()
	panelOpen = true
	panel.Size = UDim2.new(0.38, 0, 0, 0)
	panel.Visible = true
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.38, 0, 0.62, 0),
	}):Play()
end

local function closePanel()
	panelOpen = false
	TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0.38, 0, 0, 0),
	}):Play()
	task.delay(0.22, function()
		panel.Visible = false
	end)
end

closeBtn.MouseButton1Click:Connect(closePanel)
togglePetShop.Event:Connect(function(action)
	if action == "open" then
		if panelOpen then
			closePanel()
		else
			openPanel()
		end
	elseif action == "close" then
		if panelOpen then
			closePanel()
		end
	end
end)

local petFollowUpdate = remotes:WaitForChild("PetFollowUpdate", 60)
if petFollowUpdate then
	petFollowUpdate.OnClientEvent:Connect(function(state)
		if state.equipped and state.name and state.egg then
			spawnPet(state.egg, state.name)
		else
			despawnPet()
		end
	end)
end

local petRollResult = remotes:WaitForChild("PetRollResult", 60)
if petRollResult then
	petRollResult.OnClientEvent:Connect(function(result)
		if result.success then
			if not panelOpen then
				openPanel()
			end
			local boostPct = result.boost and math.floor((result.boost - 1) * 100) or 0
			showToast(
				panel,
				"🎉 You got " .. result.petName .. "! +" .. boostPct .. "% cash boost active.",
				Color3.fromRGB(40, 120, 60)
			)
		else
			showToast(panel, "⚠ " .. result.msg, Color3.fromRGB(200, 50, 50))
		end
	end)
end

player.CharacterAdded:Connect(function()
	if activePetModel then
		task.wait(0.5)
	end
end)
