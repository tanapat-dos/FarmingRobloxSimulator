--[[
	Seed Shop UI — StarterGui.Shop (Studio LocalScript reference copy).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SeedRarityColors = require(ReplicatedStorage:WaitForChild("Modules").SeedRarity)
local SeedData = require(ReplicatedStorage:WaitForChild("Modules").SeedData)
local Monetization = require(ReplicatedStorage:WaitForChild("Modules").Monetization)

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local seedModels = ReplicatedStorage:WaitForChild("SeedModels")

local player = Players.LocalPlayer
local gui = script.Parent
local shopFrame = gui:WaitForChild("Frame")
local Notification = gui:WaitForChild("Notification")
local scrollFrame = shopFrame:WaitForChild("ScrollingFrame")
local timerLabel = shopFrame:WaitForChild("Timer")
local listLayout = scrollFrame.UIListLayout
local BuyFrameTemplate = script:WaitForChild("BuyFrameTemplate")
local CropFrameTemplate = script:WaitForChild("CropFrameTemplate")
local RestockSound = Sounds:WaitForChild("Restock")
local PurchaseSound = Sounds:WaitForChild("Purchase")

local currentOpenFrame = nil
local currentBuyClone = nil
local isTweening = false
local CurrentShopData = {}
local dataLoaded = false
local playerShopData = {}

-- Scale-based template size (0.1 height) + UIAspectRatioConstraint shrinks rows badly.
local CROP_ITEM_SIZE = UDim2.new(0.94, 0, 0, 110)
local BUY_FRAME_OPEN_SIZE = UDim2.new(0.94, 0, 0, 52)
local BUY_FRAME_CLOSED_SIZE = UDim2.new(0.94, 0, 0, 0)

local function prepareCropFrame(cropFrame)
	local aspect = cropFrame:FindFirstChild("UIAspectRatioConstraint")
	if aspect then
		aspect:Destroy()
	end
	cropFrame.Size = CROP_ITEM_SIZE
end

local function refreshCropRowSizes()
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("GuiObject") and child.Name:find(" Seed$") then
			prepareCropFrame(child)
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

local function getSeedPreviewModel(cropName: string, displayName: string?)
	return seedModels:FindFirstChild(cropName)
		or (displayName and seedModels:FindFirstChild(displayName))
		or (displayName and seedModels:FindFirstChild(displayName .. " Seed"))
end

local function setupViewportModel(viewport: ViewportFrame, cropName: string, displayName: string?)
	viewport:ClearAllChildren()

	local model = getSeedPreviewModel(cropName, displayName)
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
	local maxDim = math.max(size.X, size.Y, size.Z)
	local zoomDistance = maxDim * 0.55 + 0.35
	cam.CFrame = CFrame.new(center + Vector3.new(0, 0, zoomDistance), center)
end

local function applyRarityBadge(rarityFrame, rarity: string)
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

local function scrollBuyFrameIntoView(buyFrame: GuiObject)
	task.defer(function()
		task.wait()
		local frameTop = buyFrame.AbsolutePosition.Y
		local frameBottom = frameTop + buyFrame.AbsoluteSize.Y
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

scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 100)
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 100)
end)

RemoteEvents.Purchase.OnClientEvent:Connect(function()
	PurchaseSound:Play()
end)

RemoteEvents.SeedShopTimer.OnClientEvent:Connect(function(timeLeft)
	timerLabel.Text = "New Seeds in: " .. tostring(timeLeft)
end)

local restockButton = shopFrame:WaitForChild("RESTOCKButton")
local RESTOCK_PRODUCT_ID = Monetization.DevProducts.RestockShop
local requestRestockRemote = RemoteEvents:WaitForChild("RequestSeedShopRestock", 10)
restockButton.MouseButton1Click:Connect(function()
	if RunService:IsStudio() and requestRestockRemote then
		requestRestockRemote:FireServer()
	else
		MarketplaceService:PromptProductPurchase(player, RESTOCK_PRODUCT_ID)
	end
end)

Notification.TextTransparency = 1
Notification.Visible = true
local fadeInTween = TweenService:Create(Notification, TweenInfo.new(0.5), { TextTransparency = 0 })
local fadeOutTween = TweenService:Create(Notification, TweenInfo.new(0.5), { TextTransparency = 1 })

local function toggleBuyFrame(cropFrame, cropName)
	if not dataLoaded then
		warn("Shop data not yet loaded. Click ignored.")
		return
	end

	if isTweening then
		return
	end
	isTweening = true

	local ok, err = pcall(function()
		if currentBuyClone then
			local closeTween = TweenService:Create(currentBuyClone, TweenInfo.new(0.2), { Size = BUY_FRAME_CLOSED_SIZE })
			closeTween:Play()
			closeTween.Completed:Wait()
			currentBuyClone:Destroy()
			currentBuyClone = nil

			if currentOpenFrame == cropFrame then
				currentOpenFrame = nil
				return
			end
		end

		local buyClone = BuyFrameTemplate:Clone()
		buyClone.Name = "BuyFrame_" .. cropName
		buyClone.Size = BUY_FRAME_CLOSED_SIZE
		buyClone.Parent = scrollFrame
		buyClone.LayoutOrder = cropFrame.LayoutOrder + 1
		buyClone.Visible = true
		buyClone.ZIndex = cropFrame.ZIndex + 1

		local openTween = TweenService:Create(buyClone, TweenInfo.new(0.2), { Size = BUY_FRAME_OPEN_SIZE })
		openTween:Play()
		openTween.Completed:Wait()

		local buyButton = buyClone:WaitForChild("BuyButton")
		local buyProductButton = buyClone:WaitForChild("BuyProductButton")
		local stockLabel = cropFrame:WaitForChild("SeedStock")

		local seedInfo = playerShopData[cropName] or CurrentShopData[cropName]
		local stock = seedInfo and seedInfo.StockAmount or 0
		local devProductId = seedInfo and seedInfo.DevProduct

		local function updateBuyButton()
			buyButton.Text = stock <= 0 and "OUT OF STOCK" or "Purchase"
			buyButton.BackgroundColor3 = stock <= 0 and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(50, 200, 50)
			buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			buyButton.UIStroke.Color = stock <= 0 and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(24, 147, 24)
			buyButton.AutoButtonColor = stock > 0
			stockLabel.Text = stock <= 0 and "OUT OF STOCK" or "X" .. stock .. " Stock"

			if devProductId and devProductId > 0 then
				buyProductButton.Visible = true
				buyProductButton:SetAttribute("DevProductId", devProductId)
				local success, productInfo = pcall(function()
					return MarketplaceService:GetProductInfo(devProductId, Enum.InfoType.Product)
				end)
				if success and productInfo and productInfo.PriceInRobux then
					buyProductButton.Text = "$" .. tostring(productInfo.PriceInRobux)
				else
					buyProductButton.Text = "N/A"
				end
			else
				buyProductButton.Visible = false
			end
		end

		updateBuyButton()

		buyButton.MouseButton1Click:Connect(function()
			local price = seedInfo and seedInfo.Price or 0
			local leaderstats = player:FindFirstChild("leaderstats")
			local cash = leaderstats and leaderstats:FindFirstChild("Cash")
			local shopEntry = playerShopData[cropName] or CurrentShopData[cropName]
			if cash and cash.Value >= price and stock > 0 and shopEntry then
				RemoteEvents.BuyCrop:FireServer(cropName, price)
				shopEntry.StockAmount -= 1
				stock = shopEntry.StockAmount
				cropFrame:SetAttribute("StockAmount", stock)
				updateBuyButton()
			end
		end)

		buyProductButton.MouseButton1Click:Connect(function()
			local productId = buyProductButton:GetAttribute("DevProductId")
			if productId then
				MarketplaceService:PromptProductPurchase(player, productId)
			end
		end)

		currentOpenFrame = cropFrame
		currentBuyClone = buyClone
		scrollBuyFrameIntoView(buyClone)
	end)

	if not ok then
		warn("Shop buy frame error:", err)
		if currentBuyClone then
			currentBuyClone:Destroy()
			currentBuyClone = nil
		end
		currentOpenFrame = nil
	end

	isTweening = false
end

local function buildSeedCards()
	for shopIndex, cropName in ipairs(SeedData.getSeedOrder()) do
		if scrollFrame:FindFirstChild(cropName) then
			continue
		end

		local dataFolder = SeedData.getData(cropName)
		if not dataFolder then
			warn("Couldn't find data for", cropName)
			continue
		end

		local cropClone = CropFrameTemplate:Clone()
		cropClone.Name = cropName
		prepareCropFrame(cropClone)
		cropClone.LayoutOrder = shopIndex * 2
		cropClone.Visible = false
		cropClone.Parent = scrollFrame

		local name = dataFolder:FindFirstChild("Name") and dataFolder.Name.Value or cropName
		local price = dataFolder:FindFirstChild("Price") and dataFolder.Price.Value or 0
		local rarity = dataFolder:FindFirstChild("Rarity") and dataFolder.Rarity.Value or "Common"

		cropClone.SeedName.Text = name
		cropClone.SeedPrice.Text = "$" .. tostring(price)
		cropClone.Rarity.TextLabel.Text = rarity

		CollectionService:AddTag(cropClone, "Hover")
		applyRarityBadge(cropClone.Rarity, rarity)

		local viewport = cropClone.SeedImage:WaitForChild("ViewportFrame")
		setupViewportModel(viewport, cropName, name)

		cropClone.MouseButton1Click:Connect(function()
			toggleBuyFrame(cropClone, cropName)
		end)
	end

	refreshCropRowSizes()
end

task.defer(function()
	waitForShopLayout()
	buildSeedCards()
end)

shopFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if shopFrame.AbsoluteSize.X > 0 and shopFrame.AbsoluteSize.Y > 0 then
		refreshCropRowSizes()
	end
end)

RemoteEvents.ResetSeedShop.OnClientEvent:Connect(function(cropData)
	CurrentShopData = cropData
	playerShopData = {}
	dataLoaded = true

	buildSeedCards()

	for _, child in scrollFrame:GetChildren() do
		if child:IsA("GuiObject") and child.Name:find(" Seed$") then
			child.Visible = cropData[child.Name] ~= nil
		elseif child:IsA("GuiObject") and child.Name:find("^BuyFrame_") then
			child:Destroy()
		end
	end

	currentOpenFrame = nil
	currentBuyClone = nil

	for cropName, data in pairs(cropData) do
		local cropFrame = scrollFrame:FindFirstChild(cropName)
		playerShopData[cropName] = table.clone(data)
		if cropFrame then
			prepareCropFrame(cropFrame)
			cropFrame.Visible = true
			if data.LayoutOrder then
				cropFrame.LayoutOrder = data.LayoutOrder * 2
			end
			cropFrame.SeedName.Text = data.Name
			cropFrame.SeedPrice.Text = "$" .. tostring(data.Price)
			cropFrame.SeedStock.Text = data.StockAmount <= 0 and "OUT OF STOCK" or "X" .. tostring(data.StockAmount) .. " Stock"
			cropFrame.Rarity.TextLabel.Text = data.Rarity
			CollectionService:AddTag(cropFrame, "Hover")
			applyRarityBadge(cropFrame.Rarity, data.Rarity)
			cropFrame:SetAttribute("Price", data.Price)
			cropFrame:SetAttribute("StockAmount", data.StockAmount)
			cropFrame:SetAttribute("InStock", data.IsInStock)

			local viewportFrame = cropFrame.SeedImage:WaitForChild("ViewportFrame")
			setupViewportModel(viewportFrame, cropName, data.Name)
		end
	end

	refreshCropRowSizes()
	RestockSound:Play()

	task.spawn(function()
		Notification.Text = "🌱🛠️ The shops have been restocked!"
		Notification.Visible = true
		fadeInTween:Play()
		task.wait(2.5)
		fadeOutTween:Play()
		fadeOutTween.Completed:Wait()
		Notification.Visible = false
	end)
end)
