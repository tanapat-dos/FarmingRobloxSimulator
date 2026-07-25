--[[
	GIVE TEST SEEDS + FAST GROWTH   (for testing the fixed crops)

	Paste into the Studio Command Bar WHILE PLAY-TESTING, with the context
	dropdown at the bottom of the Command Bar set to  >>> Server <<<  (not Client).
	(Start a playtest with F5 first, then switch the Command Bar to "Server".)

	What it does — all changes are SESSION-ONLY and vanish when you Stop the playtest,
	so nothing here touches your saved economy:
	  1. Gives every player 25 of each test seed (no buying needed).
	  2. Optionally shrinks those crops' GrowthTime so they ripen in a few seconds.

	Re-run any time during the same playtest to top up seeds.
]]

--=============================== CONFIGURE ===============================
local SEEDS = { "Potato Seed", "Carrot Seed", "Tomato Seed", "Wheat Seed", "Candy Vine Seed" }
local AMOUNT = 25 -- how many of each seed to grant
local FAST_GROW = true -- true = also make these crops ripen quickly
local TEST_GROWTH_SECONDS = 8 -- grow time used when FAST_GROW is on

local GIVE_CASH = true -- true = set each player's cash to CASH_AMOUNT
local CASH_AMOUNT = 10000 -- Candy Vine costs $5,650, so this comfortably covers it
--=========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")
local servicesFolder = ServerScriptService:FindFirstChild("Services")
if not servicesFolder then
	error("[GiveTestSeeds] ServerScriptService.Services not found — are you running in the SERVER context of a playtest?")
end

local ok, SeedShopService = pcall(require, servicesFolder:WaitForChild("SeedShopService"))
if not ok or typeof(SeedShopService) ~= "table" or typeof(SeedShopService.giveSeed) ~= "function" then
	error("[GiveTestSeeds] Could not load SeedShopService.giveSeed. Make sure the playtest is running and the Command Bar context is set to Server.")
end

-- Optional cash grant. Sets Cash to an exact amount via DataService (giveMoney would apply
-- pet/friend multipliers and overshoot).
local DataService = nil
local MoneyService = nil
if GIVE_CASH then
	local okData, ds = pcall(require, servicesFolder:WaitForChild("DataService"))
	local okMoney, ms = pcall(require, servicesFolder:WaitForChild("MoneyService"))
	DataService = okData and ds or nil
	MoneyService = okMoney and ms or nil
end

-- 1) Grant the seeds ----------------------------------------------------------
local players = Players:GetPlayers()
if #players == 0 then
	warn("[GiveTestSeeds] No players in the game yet — start the playtest first, then re-run.")
else
	for _, player in players do
		for _, seedName in SEEDS do
			SeedShopService.giveSeed(player, seedName, AMOUNT)
		end
		print(("[GiveTestSeeds] Gave %s: %dx each of %d seeds."):format(player.Name, AMOUNT, #SEEDS))

		if GIVE_CASH and DataService then
			local data = DataService.getData(player)
			if data then
				data.Cash = CASH_AMOUNT
				if MoneyService and MoneyService.updateCashCount then
					MoneyService.updateCashCount(player)
				end
				print(("[GiveTestSeeds] Set %s cash to $%d."):format(player.Name, CASH_AMOUNT))
			else
				warn(("[GiveTestSeeds] %s data not loaded — cash not set."):format(player.Name))
			end
		end
	end
end

-- 2) Optional fast growth (session-only) --------------------------------------
if FAST_GROW then
	local seedData = ReplicatedStorage.Modules:FindFirstChild("SeedData")
	if seedData then
		for _, seedName in SEEDS do
			local folder = seedData:FindFirstChild(seedName)
			local growth = folder and folder:FindFirstChild("GrowthTime")
			if growth then
				growth.Value = TEST_GROWTH_SECONDS
				print(("[GiveTestSeeds] %s GrowthTime -> %ds (this session only)."):format(seedName, TEST_GROWTH_SECONDS))
			else
				warn(("[GiveTestSeeds] No SeedData GrowthTime for '%s' — skipped fast-grow."):format(seedName))
			end
		end
	else
		warn("[GiveTestSeeds] ReplicatedStorage.Modules.SeedData not found — skipped fast-grow.")
	end
end

print("[GiveTestSeeds] Done. Open your Backpack, plant the seeds, and watch them ripen.")
