--!strict
--[[
	AchievementService — tracks player stats and grants achievement rewards.

	Stats tracked (all server-side, saved in data.AchievementStats):
	  CropsPlanted  — incremented by SeedShopService.plantSeed hook
	  TotalEarned   — incremented by MoneyService.giveMoney hook (pre-boost)
	  PetsOwned     — set to #OwnedPets on equip/roll

	When a stat update crosses an achievement's goal, the server grants the
	reward and records the claim. The client panel reads the state via remote.

	Remote protocol (RemoteEvent "Achievements"):
	  server -> client: ("state", payload)    full state for the panel
	  client -> server: ("request")           pull current state
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementConfig = require(ReplicatedStorage:WaitForChild("Modules").AchievementConfig)
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

local function ensureRemote(name: string): RemoteEvent
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r :: RemoteEvent
end

local achieveRemote = ensureRemote("Achievements")

-- ------------------------------------------------------------------ helpers
local function ensureStats(data)
	if not data.AchievementStats then
		data.AchievementStats = {
			CropsPlanted = 0,
			TotalEarned = 0,
			PetsOwned = 0,
			FruitsHarvested = 0,
			MutationsFound = 0,
			OrdersDelivered = 0,
			Rebirths = 0,
		}
	end
	-- Backfill fields for profiles saved before these stats existed.
	local stats = data.AchievementStats
	stats.CropsPlanted = stats.CropsPlanted or 0
	stats.TotalEarned = stats.TotalEarned or 0
	stats.PetsOwned = stats.PetsOwned or 0
	stats.FruitsHarvested = stats.FruitsHarvested or 0
	stats.MutationsFound = stats.MutationsFound or 0
	stats.OrdersDelivered = stats.OrdersDelivered or 0
	stats.Rebirths = stats.Rebirths or 0

	if not data.AchievementsClaimed then
		data.AchievementsClaimed = {}
	end
end

local function buildState(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data then
		return nil
	end
	ensureStats(data)

	local achievements = {}
	for _, a in AchievementConfig.LIST do
		local stat = data.AchievementStats[a.stat] or 0
		local claimed = data.AchievementsClaimed[a.id] == true
		table.insert(achievements, {
			id = a.id,
			title = a.title,
			desc = a.desc,
			icon = a.icon,
			category = a.category,
			goal = a.goal,
			stat = a.stat,
			progress = math.min(stat, a.goal),
			completed = stat >= a.goal,
			claimed = claimed,
			cashReward = a.cashReward,
			diamondReward = a.diamondReward,
		})
	end
	return { achievements = achievements, stats = data.AchievementStats }
end

local function pushState(player: Player)
	if not player.Parent then
		return
	end
	local state = buildState(player)
	if state then
		achieveRemote:FireClient(player, "state", state)
	end
end

-- ------------------------------------------------------------------ unlock check
-- Call after any stat change to see if new achievements unlocked.
local function checkAchievements(player: Player)
	local dataService = cachedModules.Cache.DataService
	local moneyService = cachedModules.Cache.MoneyService
	local notifyRemote = remotes:FindFirstChild("Notify")

	local data = dataService.getData(player)
	if not data then
		return
	end
	ensureStats(data)

	local anyNew = false
	for _, a in AchievementConfig.LIST do
		if data.AchievementsClaimed[a.id] then
			continue
		end
		local stat = data.AchievementStats[a.stat] or 0
		if stat >= a.goal then
			-- Grant reward
			data.AchievementsClaimed[a.id] = true
			anyNew = true

			if a.cashReward and a.cashReward > 0 then
				moneyService.giveMoney(player, a.cashReward)
			end
			if a.diamondReward and a.diamondReward > 0 then
				moneyService.giveDiamonds(player, a.diamondReward)
			end

			-- Toast notification
			if notifyRemote then
				local msg
				if a.diamondReward and a.diamondReward > 0 then
					msg = ("🏆 %s! +$%d  💎 +%d"):format(a.title, a.cashReward, a.diamondReward)
				else
					msg = ("🏆 Achievement: %s! +$%d"):format(a.title, a.cashReward)
				end
				notifyRemote:FireClient(player, msg, "success")
			end
		end
	end

	if anyNew then
		pushState(player)
	end
end

-- ------------------------------------------------------------------ public stat updaters
function Service.addCropsPlanted(player: Player, amount: number)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data then
		return
	end
	ensureStats(data)
	data.AchievementStats.CropsPlanted = (data.AchievementStats.CropsPlanted or 0) + (amount or 1)
	checkAchievements(player)
end

function Service.addEarned(player: Player, amount: number)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data then
		return
	end
	ensureStats(data)
	data.AchievementStats.TotalEarned = (data.AchievementStats.TotalEarned or 0) + (amount or 0)
	checkAchievements(player)
end

function Service.syncPetsOwned(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data then
		return
	end
	ensureStats(data)
	data.AchievementStats.PetsOwned = data.OwnedPets and #data.OwnedPets or 0
	checkAchievements(player)
end

function Service.addFruitsHarvested(player: Player, amount: number)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data then
		return
	end
	ensureStats(data)
	data.AchievementStats.FruitsHarvested = (data.AchievementStats.FruitsHarvested or 0) + (amount or 1)
	checkAchievements(player)
end

-- Call when a harvested fruit carries a Golden or Rainbow mutation.
function Service.addMutationFound(player: Player, amount: number)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data then
		return
	end
	ensureStats(data)
	data.AchievementStats.MutationsFound = (data.AchievementStats.MutationsFound or 0) + (amount or 1)
	checkAchievements(player)
end

function Service.addOrderDelivered(player: Player, amount: number)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data then
		return
	end
	ensureStats(data)
	data.AchievementStats.OrdersDelivered = (data.AchievementStats.OrdersDelivered or 0) + (amount or 1)
	checkAchievements(player)
end

-- Rebirths are tracked on data.Rebirths already (RebirthService); sync it in.
function Service.syncRebirths(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data then
		return
	end
	ensureStats(data)
	data.AchievementStats.Rebirths = data.Rebirths or 0
	checkAchievements(player)
end

function Service.dataLoaded(player: Player)
	-- Sync stats that are tracked elsewhere in the profile (rebirths, pets)
	-- so achievements already met before this system existed get credited.
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if data then
		ensureStats(data)
		data.AchievementStats.Rebirths = data.Rebirths or 0
		data.AchievementStats.PetsOwned = data.OwnedPets and #data.OwnedPets or 0
	end

	-- Push initial state after a short delay so the client UI is ready.
	task.delay(1.5, function()
		if player.Parent then
			checkAchievements(player)
			pushState(player)
		end
	end)
end

-- --------------------------------------------------------------------- init
function Service.init()
	achieveRemote.OnServerEvent:Connect(function(player, action)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if action == "request" then
			pushState(player)
		end
	end)
end

return Service
