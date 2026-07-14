--[[
	Pet Shop UI — matches Seed Shop panel design (StarterGui.PetShop clone).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local SeedRarityColors = require(ReplicatedStorage:WaitForChild("Modules").SeedRarity)
local EconomyBalance = require(ReplicatedStorage:WaitForChild("Modules").EconomyBalance)

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local ResetPetShop = RemoteEvents:WaitForChild("ResetPetShop")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local petsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")

local EGG_ORDER = EconomyBalance.getEggOrder()
local EGG_DATA = EconomyBalance.getEggData()

local player = Players.LocalPlayer
local gui = script.Parent
local shopFrame = gui:WaitForChild("Frame")
local Notification = gui:WaitForChild("Notification")
local scrollFrame = shopFrame:WaitForChild("ScrollingFrame")
local timerLabel = shopFrame:WaitForChild("Timer")
local listLayout = scrollFrame.UIListLayout
local RollFrameTemplate = script:WaitForChild("BuyFrameTemplate")
local EggFrameTemplate = script:WaitForChild("CropFrameTemplate")
local RestockSound = Sounds:WaitForChild("Restock")

local currentOpenFrame = nil
local currentRollClone = nil
local isTweening = false
local CurrentShopData = {}
local dataLoaded = false
local playerShopData = {}
local eggFrameByName = {}

local function waitForRollAnimationEnd()
	local signals = ReplicatedStorage:FindFirstChild("ClientSignals")
	if not signals then
		return
	end
	local flag = signals:FindFirstChild("PetRollAnimating")
	if not flag or not flag:IsA("BoolValue") then
		return
	end
	local deadline = os.clock() + 2
	while not flag.Value and os.clock() < deadline do
		task.wait(0.05)
	end
	while flag.Value do
		task.wait(0.05)
	end
end

local function resetRollButton(eggName)
	local rollFrame = scrollFrame:FindFirstChild("RollFrame_" .. eggName)
	if not rollFrame then
		return
	end
	local rollButton = rollFrame:FindFirstChild("BuyButton")
	local shopEntry = playerShopData[eggName]
	if rollButton and shopEntry then
		local stock = shopEntry.StockAmount
		rollButton.Text = stock <= 0 and "OUT OF STOCK" or "Roll!"
		rollButton.AutoButtonColor = stock > 0
	end
end

-- Scale-based template size (0.1 height) shrinks rows via UIAspectRatioConstraint.
-- Use fixed full-width rows so a few eggs still fill the panel like the seed shop.
local EGG_ITEM_SIZE = UDim2.new(0.94, 0, 0, 110)
local ROLL_OPEN_SIZE = UDim2.new(0.94, 0, 0, 52)
local ROLL_CLOSED_SIZE = UDim2.new(0.94, 0, 0, 0)

local function getEggItemSize()
	return EGG_ITEM_SIZE
end

local function getRollOpenSize()
	return ROLL_OPEN_SIZE
end

local function getRollClosedSize()
	return ROLL_CLOSED_SIZE
end

local function prepareEggFrame(eggFrame)
	local aspect = eggFrame:FindFirstChild("UIAspectRatioConstraint")
	if aspect then
		aspect:Destroy()
	end
	eggFrame.Size = EGG_ITEM_SIZE
end

local function refreshEggRowSizes()
	for _, eggFrame in eggFrameByName do
		if eggFrame.Parent then
			prepareEggFrame(eggFrame)
		end
	end
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 100)
end

local function waitForShopLayout()
	if shopFrame.AbsoluteSize.X > 0 and shopFrame.AbsoluteSize.Y > 0 then
		return
	end
	local deadline = os.clock() + 15
	repeat
		task.wait()
	until (shopFrame.AbsoluteSize.X > 0 and shopFrame.AbsoluteSize.Y > 0) or os.clock() > deadline
end

local function getEggPreviewModel(eggName)
	local folder = petsAssets:FindFirstChild(eggName)
	if not folder then
		return nil
	end
	return folder:FindFirstChildWhichIsA("Model")
end

local function setupViewportModel(viewport, eggName)
	viewport:ClearAllChildren()

	local model = getEggPreviewModel(eggName)
	if not model then
		return
	end

	local modelClone = model:Clone()
	modelClone.Parent = viewport

	local cam = Instance.new("Camera")
	cam.Name = "ViewportCamera"
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	local cf, size = modelClone:GetBoundingBox()
	local center = cf.Position
	local zoomDistance = size.Magnitude / 2 + 1.5
	cam.CFrame = CFrame.new(center + Vector3.new(0, 0, zoomDistance), center)
end

local function applyRarityBadge(rarityFrame, rarity)
	local rarityStyle = SeedRarityColors[rarity]
	local oldGradient = rarityFrame:FindFirstChildOfClass("UIGradient")
	if oldGradient then
		oldGradient:Destroy()
	end
	if typeof(rarityStyle) == "Color3" then
		rarityFrame.BackgroundColor3 = rarityStyle
	elseif rarityStyle then
		rarityStyle:Clone().Parent = rarityFrame
	end
end

local function scrollRollFrameIntoView(rollFrame)
	task.defer(function()
		task.wait()
		local frameTop = rollFrame.AbsolutePosition.Y
		local frameBottom = frameTop + rollFrame.AbsoluteSize.Y
		local viewTop = scrollFrame.AbsolutePosition.Y
		local viewBottom = viewTop + scrollFrame.AbsoluteSize.Y

		if frameTop < viewTop then
			scrollFrame.CanvasPosition = Vector2.new(
				scrollFrame.CanvasPosition.X,
				scrollFrame.CanvasPosition.Y - (viewTop - frameTop) - 8
			)
		elseif frameBottom > viewBottom then
			scrollFrame.CanvasPosition = Vector2.new(
				scrollFrame.CanvasPosition.X,
				scrollFrame.CanvasPosition.Y + (frameBottom - viewBottom) + 8
			)
		end
	end)
end

local function showNotification(text)
	Notification.Text = text
	Notification.Visible = true
	Notification.TextTransparency = 1
	local fadeIn = TweenService:Create(Notification, TweenInfo.new(0.5), { TextTransparency = 0 })
	local fadeOut = TweenService:Create(Notification, TweenInfo.new(0.5), { TextTransparency = 1 })
	fadeIn:Play()
	fadeIn.Completed:Wait()
	task.wait(2.5)
	fadeOut:Play()
	fadeOut.Completed:Wait()
	Notification.Visible = false
end

scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 100)
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 100)
end)

RemoteEvents.SeedShopTimer.OnClientEvent:Connect(function(timeLeft)
	timerLabel.Text = "New Eggs in: " .. tostring(timeLeft)
end)

Notification.TextTransparency = 1
Notification.Visible = true

local function toggleRollFrame(eggFrame, eggName)
	if not dataLoaded then
		return
	end
	if isTweening then
		return
	end
	isTweening = true

	local ok, err = pcall(function()
		if currentRollClone then
			local closeTween = TweenService:Create(currentRollClone, TweenInfo.new(0.2), { Size = getRollClosedSize() })
			closeTween:Play()
			closeTween.Completed:Wait()
			currentRollClone:Destroy()
			currentRollClone = nil

			if currentOpenFrame == eggFrame then
				currentOpenFrame = nil
				return
			end
		end

		local rollClone = RollFrameTemplate:Clone()
		rollClone.Name = "RollFrame_" .. eggName
		rollClone.Size = getRollClosedSize()
		rollClone.Parent = scrollFrame
		rollClone.LayoutOrder = eggFrame.LayoutOrder + 1
		rollClone.Visible = true
		rollClone.ZIndex = eggFrame.ZIndex + 1

		local openTween = TweenService:Create(rollClone, TweenInfo.new(0.2), { Size = getRollOpenSize() })
		openTween:Play()
		openTween.Completed:Wait()

		local rollButton = rollClone:WaitForChild("BuyButton")
		local robuxButton = rollClone:FindFirstChild("BuyProductButton")
		if robuxButton then
			robuxButton.Visible = false
		end
		local stockLabel = eggFrame:WaitForChild("SeedStock")

		local eggInfo = playerShopData[eggName] or CurrentShopData[eggName]
		local stock = eggInfo and eggInfo.StockAmount or 0
		local boostPct = eggInfo and eggInfo.Boost and math.floor((eggInfo.Boost - 1) * 100) or 0

		local function updateRollButton()
			rollButton.Text = stock <= 0 and "OUT OF STOCK" or "Roll!"
			rollButton.BackgroundColor3 = stock <= 0 and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(50, 200, 50)
			rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			if rollButton:FindFirstChild("UIStroke") then
				rollButton.UIStroke.Color = stock <= 0 and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(24, 147, 24)
			end
			rollButton.AutoButtonColor = stock > 0
			stockLabel.Text = stock <= 0 and "OUT OF STOCK" or "X" .. stock .. " Stock"
		end

		updateRollButton()

		rollButton.MouseButton1Click:Connect(function()
			if stock <= 0 then
				return
			end
			local price = eggInfo and eggInfo.Price or 0
			local leaderstats = player:FindFirstChild("leaderstats")
			local cash = leaderstats and leaderstats:FindFirstChild("Cash")
			local shopEntry = playerShopData[eggName] or CurrentShopData[eggName]
			if cash and cash.Value >= price and stock > 0 and shopEntry then
				rollButton.Text = "Rolling..."
				rollButton.AutoButtonColor = false
				RemoteEvents.PetRoll:FireServer(eggName)
			end
		end)

		currentOpenFrame = eggFrame
		currentRollClone = rollClone
		scrollRollFrameIntoView(rollClone)
	end)

	if not ok then
		warn("Pet shop roll frame error:", err)
		if currentRollClone then
			currentRollClone:Destroy()
			currentRollClone = nil
		end
		currentOpenFrame = nil
	end

	isTweening = false
end

local function buildEggCards()
	for shopIndex, eggName in ipairs(EGG_ORDER) do
		local egg = EGG_DATA[eggName]
		if not egg then
			continue
		end

		if eggFrameByName[eggName] then
			continue
		end

		local eggClone = EggFrameTemplate:Clone()
		eggClone.Name = eggName
		prepareEggFrame(eggClone)
		eggClone.LayoutOrder = shopIndex * 2
		eggClone.Visible = false
		eggClone.Parent = scrollFrame

		local boostLabel = EconomyBalance.formatEggBoostRange(eggName)

		eggClone.SeedName.Text = eggName
		eggClone.SeedPrice.Text = "$" .. tostring(egg.cost)
		eggClone.SeedStock.Text = "..."
		eggClone.Rarity.TextLabel.Text = egg.rarity .. "  " .. boostLabel

		CollectionService:AddTag(eggClone, "Hover")
		applyRarityBadge(eggClone.Rarity, egg.rarity)

		local viewport = eggClone.SeedImage:WaitForChild("ViewportFrame")
		setupViewportModel(viewport, eggName)

		eggClone.MouseButton1Click:Connect(function()
			toggleRollFrame(eggClone, eggName)
		end)

		eggFrameByName[eggName] = eggClone
	end

	refreshEggRowSizes()
end

task.defer(function()
	waitForShopLayout()
	buildEggCards()
end)

shopFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if shopFrame.AbsoluteSize.X > 0 and shopFrame.AbsoluteSize.Y > 0 then
		if not next(eggFrameByName) then
			buildEggCards()
		else
			refreshEggRowSizes()
		end
	end
end)

ResetPetShop.OnClientEvent:Connect(function(eggData)
	CurrentShopData = eggData
	playerShopData = {}
	dataLoaded = true

	if not next(eggFrameByName) then
		buildEggCards()
	end

	for _, child in scrollFrame:GetChildren() do
		if child:IsA("GuiObject") and EGG_DATA[child.Name] then
			child.Visible = eggData[child.Name] ~= nil
		elseif child:IsA("GuiObject") and child.Name:find("^RollFrame_") then
			child:Destroy()
		end
	end

	currentOpenFrame = nil
	currentRollClone = nil

	for eggName, data in pairs(eggData) do
		local eggFrame = eggFrameByName[eggName] or scrollFrame:FindFirstChild(eggName)
		playerShopData[eggName] = table.clone(data)
		if eggFrame then
			prepareEggFrame(eggFrame)
			eggFrame.Visible = true
			if data.LayoutOrder then
				eggFrame.LayoutOrder = data.LayoutOrder * 2
			end
			local boostLabel = EconomyBalance.formatEggBoostRange(eggName)
			if data.BoostMin and data.BoostMax then
				boostLabel = string.format("+%d-%d%%", data.BoostMin, data.BoostMax)
			end
			eggFrame.SeedName.Text = data.Name or eggName
			eggFrame.SeedPrice.Text = "$" .. tostring(data.Price)
			eggFrame.SeedStock.Text = data.StockAmount <= 0 and "OUT OF STOCK" or "X" .. tostring(data.StockAmount) .. " Stock"
			eggFrame.Rarity.TextLabel.Text = data.Rarity .. "  " .. boostLabel
			CollectionService:AddTag(eggFrame, "Hover")
			applyRarityBadge(eggFrame.Rarity, data.Rarity)
			eggFrame:SetAttribute("Price", data.Price)
			eggFrame:SetAttribute("StockAmount", data.StockAmount)
			eggFrame:SetAttribute("InStock", data.IsInStock)

			local viewportFrame = eggFrame.SeedImage:WaitForChild("ViewportFrame")
			setupViewportModel(viewportFrame, eggName)
		end
	end

	refreshEggRowSizes()

	RestockSound:Play()
	task.spawn(function()
		showNotification("🐾🥚 The pet shop has been restocked!")
	end)
end)

RemoteEvents.PetRollResult.OnClientEvent:Connect(function(result)
	if result.success then
		local eggName = result.eggName
		if eggName and playerShopData[eggName] then
			playerShopData[eggName].StockAmount = math.max(0, playerShopData[eggName].StockAmount - 1)
			local eggFrame = eggFrameByName[eggName] or scrollFrame:FindFirstChild(eggName)
			if eggFrame then
				local stock = playerShopData[eggName].StockAmount
				eggFrame.SeedStock.Text = stock <= 0 and "OUT OF STOCK" or "X" .. stock .. " Stock"
				eggFrame:SetAttribute("StockAmount", stock)
			end
			local rollFrame = scrollFrame:FindFirstChild("RollFrame_" .. eggName)
			if rollFrame then
				local rollButton = rollFrame:FindFirstChild("BuyButton")
				if rollButton then
					rollButton.Text = "Opening..."
					rollButton.AutoButtonColor = false
				end
			end
		end
		task.spawn(function()
			waitForRollAnimationEnd()
			if result.eggName then
				resetRollButton(result.eggName)
			end
		end)
		-- Success reveal is handled by PetRollAnimation (CSGO-style reel).
	else
		if result.eggName then
			resetRollButton(result.eggName)
		end
		task.spawn(function()
			showNotification("⚠ " .. (result.msg or "Roll failed."))
		end)
	end
end)
