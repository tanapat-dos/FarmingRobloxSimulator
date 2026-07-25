--!strict
--[[
	FishCoinShopService — small server-authoritative shop for crops bought
	with Fish Coins (earned from fishing) instead of Cash.

	Unlike SeedShopService there's no restock timer or MemoryStore-backed
	global stock — offers are a static list, always available. Server is
	still the source of truth for price: the client never sends a price,
	only the item key.

	Remote protocol (RemoteEvent "BuyFishCoinItem"):
	  client -> server: (seedName: string)   purchase request
	  server -> client: nothing directly — SeedShopService.giveSeed fires
	    InventoryService.inventoryUpdated, and "Notify" reports success/failure.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeedData = require(ReplicatedStorage:WaitForChild("Modules").SeedData)
local CropTierConfig = require(ReplicatedStorage:WaitForChild("Modules").CropTierConfig)

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

--[[
	Crystal Blooms is the apex crop: highest baseValue in the game (1000) and the highest
	profit per slot-hour (~$39K), because it costs no cash so its entire output is profit.

	Fish Coin supply is the only throttle, which makes this price the balancing lever.
	Fishing yields roughly 1,100 coins/hour (avg catch ~4.4 coins), so at 150 coins a seed
	that is ~7 seeds/hour. One slot consumes 3 seeds/hour on a 1,200s cycle, so steady
	fishing sustains only ~2-3 Crystal Bloom slots — a strong reward for a second activity,
	never a dominant strategy.

	It is also tier-gated (Mythical), otherwise a fresh player could skip the whole crop
	ladder by fishing.
]]
local OFFERS = {
	{ seedName = "Crystal Blooms Seed", price = 150, layoutOrder = 1 },
}

local function ensureRemote(name: string): RemoteEvent
	local remote = RemoteEvents:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = RemoteEvents
	end
	return remote :: RemoteEvent
end

local buyRemote = ensureRemote("BuyFishCoinItem")
local resetRemote = ensureRemote("ResetFishCoinShop")

local function notify(player: Player, message: string, kind: string?)
	local notifyRemote = RemoteEvents:FindFirstChild("Notify")
	if notifyRemote then
		notifyRemote:FireClient(player, message, kind or "info")
	end
end

--[[
	Builds the client-facing offer list from live SeedData (name/rarity) combined with the
	Fish Coin price above. Locked offers are still sent, flagged with `Locked` and their
	unlock progress, so the shop can show what the player is working toward. The purchase
	handler re-checks the gate regardless.
]]
function Service.GetOffers(player: Player?): { [string]: any }
	local stats
	if player then
		local dataService = cachedModules.Cache.DataService
		stats = CropTierConfig.buildStats(dataService and dataService.getData(player))
	end

	local map = {}
	for _, offer in OFFERS do
		local seed = SeedData.getData(offer.seedName)
		if seed then
			local tier = CropTierConfig.getTierForSeed(offer.seedName)
			local locked = false
			local progress = nil
			if stats and tier then
				locked = not CropTierConfig.isUnlocked(stats, tier)
				if locked then
					progress = CropTierConfig.getUnlockProgress(stats, tier)
				end
			end

			map[offer.seedName] = {
				Name = seed:FindFirstChild("Name") and seed.Name.Value or offer.seedName,
				Rarity = seed:FindFirstChild("Rarity") and seed.Rarity.Value or "Mythical",
				Price = offer.price,
				LayoutOrder = offer.layoutOrder,
				Locked = locked,
				UnlockProgress = progress,
			}
		end
	end
	return map
end

local function findOffer(seedName: string)
	for _, offer in OFFERS do
		if offer.seedName == seedName then
			return offer
		end
	end
	return nil
end

function Service.init()
	local moneyService = cachedModules.Cache.MoneyService
	local seedShopService = cachedModules.Cache.SeedShopService

	buyRemote.OnServerEvent:Connect(function(player: Player, seedName: any)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if typeof(seedName) ~= "string" then
			return
		end

		local offer = findOffer(seedName)
		if not offer then
			return
		end

		-- Tier gate, re-checked here rather than trusting the offer list the client received.
		-- Unknown seeds fail closed.
		local dataService = cachedModules.Cache.DataService
		local stats = CropTierConfig.buildStats(dataService and dataService.getData(player))
		if not CropTierConfig.isSeedUnlocked(stats, seedName) then
			notify(player, "You haven't unlocked that seed tier yet.", "error")
			return
		end

		-- Server-authoritative price: never trust a client-sent value.
		local price = offer.price
		if not moneyService.hasEnoughFishCoins(player, price) then
			notify(player, `You need {price} 🐟 Fish Coins for {seedName}.`, "error")
			return
		end

		if not moneyService.removeFishCoins(player, price) then
			return
		end

		seedShopService.giveSeed(player, seedName, 1)
		notify(player, `Bought {seedName} for {price} 🐟 Fish Coins!`, "success")
	end)

	local Players = game:GetService("Players")

	-- Offers include per-player lock state, so wait for the profile before pushing.
	local function pushOffers(player: Player)
		task.spawn(function()
			for _ = 1, 30 do
				if player.Parent == nil then
					return
				end
				if player:GetAttribute("DataLoaded") == true then
					resetRemote:FireClient(player, Service.GetOffers(player))
					return
				end
				task.wait(1)
			end
		end)
	end

	Players.PlayerAdded:Connect(pushOffers)
	for _, player in Players:GetPlayers() do
		pushOffers(player)
	end
end

return Service
