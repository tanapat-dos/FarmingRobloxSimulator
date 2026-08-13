local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PurchaseEvent = RemoteEvents:WaitForChild("Purchase")

local SeedData = require(ReplicatedStorage:WaitForChild("Modules").SeedData)
local Monetization = require(ReplicatedStorage:WaitForChild("Modules").Monetization)

local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local IS_STUDIO = RunService:IsStudio()

-- Cap on remembered PurchaseIds per profile (idempotency log).
local MAX_RECEIPT_LOG = 50

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

-- Map DevProduct IDs to diamond payouts (premium currency packs).
local ProductIdToDiamonds = {}
for _, pack in ipairs(Monetization.DiamondPacks) do
	if typeof(pack.id) == "number" and pack.id > 0 then
		ProductIdToDiamonds[pack.id] = pack.diamonds
	end
end

-- Restock shop stock globally. The shop stock is shared via MemoryStore and
-- BuyCrop re-reads it on every purchase, so the bump MUST be persisted there —
-- mutating a local copy only updates UI and every buy still sees the old stock.
local function HandleDevProductRestock(player): boolean
	local SeedShopService = cachedModules.Cache.SeedShopService
	local stock = SeedShopService:GetCurrentStock()
	if not stock then
		return false
	end
	for _, crop in pairs(stock) do
		if crop.IsInStock then
			crop.StockAmount += math.random(3, 5)
		end
	end
	SeedShopService:SaveStockToMemoryStore(stock)
	RemoteEvents.ResetSeedShop:FireAllClients(stock)
	if not IS_STUDIO then
		-- Let other servers pull the updated stock from MemoryStore.
		pcall(function()
			MessagingService:PublishAsync("GlobalShopRestock", true)
		end)
	end
	PurchaseEvent:FireClient(player) -- Optional UI feedback
	return true
end

-- Attempt the actual grant. Returns true only when the product was delivered.
local function grantProduct(player: Player, productId: number): boolean
	local seedName = ProductIdToSeed[productId]
	if seedName then
		local SeedShopService = cachedModules.Cache.SeedShopService
		local ok, granted = pcall(SeedShopService.giveSeed, player, seedName, 1)
		return ok and granted == true
	end

	local diamondAmount = ProductIdToDiamonds[productId]
	if diamondAmount then
		local MoneyService = cachedModules.Cache.MoneyService
		local ok, granted = pcall(MoneyService.giveDiamonds, player, diamondAmount)
		return ok and typeof(granted) == "number" and granted > 0
	end

	if productId == RESTOCK_PRODUCT_ID then
		local ok, granted = pcall(HandleDevProductRestock, player)
		return ok and granted == true
	end

	return false -- Unknown product: never mark the receipt processed.
end

-- Process receipt function
function Service.init()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Grants write to profile data; if the profile isn't loaded yet the
		-- grant would silently no-op. Retry the receipt later instead of
		-- eating the player's Robux.
		local DataService = cachedModules.Cache.DataService
		local profileData = DataService.getData(player)
		if not profileData then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Idempotency: Roblox may retry receipts we already granted (e.g. the
		-- server returned PurchaseGranted but the response was lost).
		local receiptLog = profileData.ProcessedReceipts
		if typeof(receiptLog) ~= "table" then
			receiptLog = {}
			profileData.ProcessedReceipts = receiptLog
		end
		if table.find(receiptLog, receiptInfo.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		if not grantProduct(player, receiptInfo.ProductId) then
			warn("❌ Failed to grant product", receiptInfo.ProductId, "to", player.Name)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Record the receipt and force a save so a crash after this point
		-- can't lose a paid grant (ProfileStore otherwise autosaves on a
		-- periodic cadence only).
		table.insert(receiptLog, receiptInfo.PurchaseId)
		while #receiptLog > MAX_RECEIPT_LOG do
			table.remove(receiptLog, 1)
		end
		local profile = DataService.Profiles[player]
		if profile and typeof(profile.Save) == "function" then
			pcall(function()
				profile:Save()
			end)
		end

		print("✅ Granted product", receiptInfo.ProductId, "to", player.Name)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Service
