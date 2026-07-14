local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PurchaseEvent = RemoteEvents:WaitForChild("Purchase")

local SeedData = require(ReplicatedStorage:WaitForChild("Modules").SeedData)
local Monetization = require(ReplicatedStorage:WaitForChild("Modules").Monetization)

local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {
}

-- Setup
local RESTOCK_PRODUCT_ID = Monetization.DevProducts.RestockShop

-- Map DevProduct IDs to Seed Names
local ProductIdToSeed = {}
for _, seedName in ipairs(SeedData.getSeedOrder()) do
	local seedDataFolder = SeedData.getData(seedName)
	if seedDataFolder and seedDataFolder:FindFirstChild("DevProduct") then
		local devProductId = seedDataFolder.DevProduct.Value
		ProductIdToSeed[devProductId] = seedName
	end
end

-- Restock shop for a single player
local function HandleDevProductRestock(player)
	local SeedShopService = cachedModules.Cache.SeedShopService
	local stock = SeedShopService:GetCurrentStock()
	if stock then
		for _, crop in pairs(stock) do
			if crop.IsInStock then
				crop.StockAmount += math.random(3, 5)
			end
		end
		RemoteEvents.ResetSeedShop:FireClient(player, stock)
	end
end

-- Process receipt function
function Service.init()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local productId = receiptInfo.ProductId

		-- 🌱 Handle seed purchase
		local seedName = ProductIdToSeed[productId]
		if seedName then
			local success, err = pcall(function()
				local SeedShopService = cachedModules.Cache.SeedShopService
				SeedShopService.giveSeed(player, seedName, 1)
			end)

			if success then
				print("✅ Granted seed:", seedName, "to", player.Name)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			else
				warn("❌ Failed to grant seed:", err)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end

		-- 🛒 Handle personal shop restock
		if productId == RESTOCK_PRODUCT_ID then
			PurchaseEvent:FireClient(player) -- Optional UI feedback
			HandleDevProductRestock(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		-- ❓ Unknown product
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return Service
