--!strict
--[[
	CollectionService — read-only "discovered so far" log: crops harvested at least once,
	fish caught at least once, pets ever owned, and every mutation ever found (Golden/Rainbow/
	Wet/Shocked). Pure completionist tracking; grants no rewards of its own (achievements
	already cover reward-granting milestones — this is the browsable checklist behind them).

	Storage: data.Collection = {
		Crops = { [cropName] = true },      -- e.g. "Carrot" (no " Seed" suffix, matches CROPS keys minus suffix)
		Fish = { [fishId] = true },         -- FishingConfig.FISH ids, e.g. "tuna"
		Pets = { [petKey] = true },         -- "<eggName>:<petName>", e.g. "Common Egg:Dog"
		Mutations = { [mutationName] = true }, -- "Golden" | "Rainbow" | "Wet" | "Shocked"
	}
	Sets, not counts — this is "have you ever seen one," not "how many."

	Remote protocol (RemoteEvent "Collection"):
	  client -> server: ("request")     pull current state
	  server -> client: ("state", payload)
	    payload = {
	      crops = { { name, rarity, discovered } , ... },     full CROPS list, discovered flag
	      fish = { { id, displayName, rarity, discovered } , ... },  full FISH list
	      pets = { { key, egg, name, discovered } , ... },    full egg/pet roster
	      mutations = { { name, discovered } , ... },         the 4 known mutation names
	      totals = { crops = {have, total}, fish = {...}, pets = {...}, mutations = {...} },
	    }

	Public hooks other services call when something is discovered for the first time:
	  Service.discoverCrop(player, cropName)       -- cropName WITHOUT " Seed" suffix
	  Service.discoverFish(player, fishId)
	  Service.discoverPet(player, eggName, petName)
	  Service.discoverMutation(player, mutationName)
	Each is idempotent (no-ops if already discovered) and only fires the "new discovery" toast
	+ re-pushes state on an actual first-time find, so repeat catches don't spam the player.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyBalance = require(modules.EconomyBalance)
local FishingConfig = require(modules.FishingConfig)
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

local MUTATION_NAMES = { "Golden", "Rainbow", "Wet", "Shocked" }

local function ensureRemote(name: string): RemoteEvent
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r :: RemoteEvent
end

local collectionRemote = ensureRemote("Collection")

-- ------------------------------------------------------------------ helpers

local function ensureCollection(data)
	if not data.Collection then
		data.Collection = { Crops = {}, Fish = {}, Pets = {}, Mutations = {} }
		return
	end
	data.Collection.Crops = data.Collection.Crops or {}
	data.Collection.Fish = data.Collection.Fish or {}
	data.Collection.Pets = data.Collection.Pets or {}
	data.Collection.Mutations = data.Collection.Mutations or {}
end

-- Strips the " Seed" suffix so the collection key matches the plain crop name used elsewhere
-- (e.g. inventory strings, HarvestService's plantKeyUtil.resolveCropName).
local function cropDisplayName(seedName: string): string
	return (seedName:gsub(" Seed$", ""))
end

local function petKey(eggName: string, petName: string): string
	return eggName .. ":" .. petName
end

-- ------------------------------------------------------------------ state build

local function buildCropList(data): { any }
	local list = {}
	for seedName, cfg in EconomyBalance.CROPS do
		local name = cropDisplayName(seedName)
		table.insert(list, {
			name = name,
			rarity = cfg.rarity,
			discovered = data.Collection.Crops[name] == true,
		})
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

local function buildFishList(data): { any }
	local list = {}
	for _, fish in FishingConfig.FISH do
		table.insert(list, {
			id = fish.id,
			displayName = fish.displayName,
			rarity = fish.rarity,
			discovered = data.Collection.Fish[fish.id] == true,
		})
	end
	table.sort(list, function(a, b)
		return a.displayName < b.displayName
	end)
	return list
end

local function buildPetList(data): { any }
	local petService = cachedModules.Cache.PetService
	local list = {}
	if not (petService and petService.EGG_ORDER and petService.EGG_DATA) then
		return list
	end

	local petsAssets = ReplicatedStorage:FindFirstChild("Assets")
	petsAssets = petsAssets and petsAssets:FindFirstChild("Pets")
	if not petsAssets then
		return list
	end

	for _, eggName in petService.EGG_ORDER do
		local folder = petsAssets:FindFirstChild(eggName)
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("Model") then
					local key = petKey(eggName, child.Name)
					table.insert(list, {
						key = key,
						egg = eggName,
						name = child.Name,
						discovered = data.Collection.Pets[key] == true,
					})
				end
			end
		end
	end
	return list
end

local function buildMutationList(data): { any }
	local list = {}
	for _, name in MUTATION_NAMES do
		table.insert(list, {
			name = name,
			discovered = data.Collection.Mutations[name] == true,
		})
	end
	return list
end

local function countDiscovered(list: { any }): { have: number, total: number }
	local have = 0
	for _, entry in list do
		if entry.discovered then
			have += 1
		end
	end
	return { have = have, total = #list }
end

local function buildState(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data then
		return nil
	end
	ensureCollection(data)

	local crops = buildCropList(data)
	local fish = buildFishList(data)
	local pets = buildPetList(data)
	local mutations = buildMutationList(data)

	return {
		crops = crops,
		fish = fish,
		pets = pets,
		mutations = mutations,
		totals = {
			crops = countDiscovered(crops),
			fish = countDiscovered(fish),
			pets = countDiscovered(pets),
			mutations = countDiscovered(mutations),
		},
	}
end

local function pushState(player: Player)
	if not player.Parent then
		return
	end
	local state = buildState(player)
	if state then
		collectionRemote:FireClient(player, "state", state)
	end
end

local function notifyDiscovery(player: Player, message: string)
	local notifyRemote = remotes:FindFirstChild("Notify")
	if notifyRemote then
		notifyRemote:FireClient(player, message, "success")
	end
end

-- ------------------------------------------------------------------ public hooks

function Service.discoverCrop(player: Player, cropName: string)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data or typeof(cropName) ~= "string" then
		return
	end
	ensureCollection(data)
	if data.Collection.Crops[cropName] then
		return
	end
	data.Collection.Crops[cropName] = true
	notifyDiscovery(player, ("📖 New crop discovered: %s!"):format(cropName))
	pushState(player)
end

function Service.discoverFish(player: Player, fishId: string)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data or typeof(fishId) ~= "string" then
		return
	end
	ensureCollection(data)
	if data.Collection.Fish[fishId] then
		return
	end
	data.Collection.Fish[fishId] = true
	local fish = FishingConfig.getFishById(fishId)
	notifyDiscovery(player, ("📖 New fish discovered: %s!"):format(fish and fish.displayName or fishId))
	pushState(player)
end

function Service.discoverPet(player: Player, eggName: string, petName: string)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data or typeof(eggName) ~= "string" or typeof(petName) ~= "string" then
		return
	end
	ensureCollection(data)
	local key = petKey(eggName, petName)
	if data.Collection.Pets[key] then
		return
	end
	data.Collection.Pets[key] = true
	notifyDiscovery(player, ("📖 New pet discovered: %s!"):format(petName))
	pushState(player)
end

function Service.discoverMutation(player: Player, mutationName: string)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if not data or typeof(mutationName) ~= "string" then
		return
	end
	ensureCollection(data)
	if data.Collection.Mutations[mutationName] then
		return
	end
	data.Collection.Mutations[mutationName] = true
	notifyDiscovery(player, ("📖 New mutation discovered: %s!"):format(mutationName))
	pushState(player)
end

function Service.dataLoaded(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	if data then
		ensureCollection(data)
	end
	task.delay(1.5, function()
		if player.Parent then
			pushState(player)
		end
	end)
end

-- --------------------------------------------------------------------- init
function Service.init()
	collectionRemote.OnServerEvent:Connect(function(player, action)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if action == "request" then
			pushState(player)
		end
	end)
end

return Service
