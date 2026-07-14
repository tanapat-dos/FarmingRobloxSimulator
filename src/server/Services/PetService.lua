local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local petsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local activatorTemplate = script.Parent.InventoryService.PetToolActivator
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local EGG_DATA = {
	["Common Egg"]   = { cost = 100,   boost = 1.05, rarity = "Common"    },
	["Uncommon Egg"] = { cost = 500,   boost = 1.15, rarity = "Uncommon"  },
	["Godly Egg"]    = { cost = 2000,  boost = 1.30, rarity = "Rare"      },
	["Galactic Egg"] = { cost = 7500,  boost = 1.55, rarity = "Epic"      },
	["Divine Egg"]   = { cost = 25000, boost = 2.00, rarity = "Legendary" },
}

local Service = {}
Service.EGG_DATA = EGG_DATA

local function ensureRemote(name: string): RemoteEvent
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local petFollowUpdate = ensureRemote("PetFollowUpdate")
local petUse = ensureRemote("PetUse")
local updatePetBoost = ensureRemote("UpdatePetBoost")

local function generatePetId(): string
	return string.sub(HttpService:GenerateGUID(false), 1, 8)
end

local function ensurePetIds(data)
	if not data.OwnedPets then
		data.OwnedPets = {}
		return
	end
	for _, pet in ipairs(data.OwnedPets) do
		if not pet.id then
			pet.id = generatePetId()
		end
	end
end

local function resolvePetBoost(pet): number
	if not pet then
		return 1
	end
	if typeof(pet.boost) == "number" and pet.boost > 1 then
		return pet.boost
	end
	local eggName = pet.egg
	if typeof(eggName) == "string" and EGG_DATA[eggName] then
		local boost = EGG_DATA[eggName].boost
		pet.boost = boost
		return boost
	end
	return 1
end

local function findOwnedPet(data, petId: string)
	for _, pet in ipairs(data.OwnedPets or {}) do
		if pet.id == petId then
			return pet
		end
	end
	return nil
end

local function findPetBoostFromTool(player: Player, petId: string): number?
	for _, container in ipairs({ player.Backpack, player.Character }) do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("petId") == petId then
					local boost = child:GetAttribute("petBoost")
					if typeof(boost) == "number" and boost > 1 then
						return boost
					end
					local eggName = child:GetAttribute("eggName")
					if typeof(eggName) == "string" and EGG_DATA[eggName] then
						return EGG_DATA[eggName].boost
					end
				end
			end
		end
	end
	return nil
end

local function applyPetBoost(player: Player, boost: number)
	player:SetAttribute("PetBoost", boost)
	local pct = math.max(0, math.floor((boost - 1) * 100))
	updatePetBoost:FireClient(player, pct)
end

local function playerHasPetTool(player: Player, petId: string): boolean
	for _, container in ipairs({ player.Backpack, player.Character }) do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("petId") == petId then
					return true
				end
			end
		end
	end
	return false
end

function Service.createPetTool(player: Player, pet)
	if not pet or not pet.id then
		return
	end
	if playerHasPetTool(player, pet.id) then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = pet.name
	local boost = resolvePetBoost(pet)
	local boostPct = math.floor((boost - 1) * 100)
	tool.ToolTip = string.format("%s pet • +%d%% cash (click to equip)", pet.rarity or "Pet", boostPct)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool:SetAttribute("isPet", true)
	tool:SetAttribute("petId", pet.id)
	tool:SetAttribute("petName", pet.name)
	tool:SetAttribute("eggName", pet.egg)
	tool:SetAttribute("petBoost", boost)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Anchored = false
	handle.CastShadow = false
	handle.Parent = tool

	local activator = activatorTemplate:Clone()
	activator.Parent = tool
	require(activator)

	tool.Parent = player.Backpack
end

function Service.syncPetTools(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data then
		return
	end

	ensurePetIds(data)
	for _, pet in ipairs(data.OwnedPets) do
		Service.createPetTool(player, pet)
	end
end

function Service.equipPet(player: Player, petId: string)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data or not petId then
		return
	end

	local pet = findOwnedPet(data, petId)
	if not pet then
		local toolBoost = findPetBoostFromTool(player, petId)
		if not toolBoost then
			return
		end
		pet = { id = petId, boost = toolBoost }
	end

	local boost = resolvePetBoost(pet)

	data.EquippedPet = {
		id = pet.id,
		name = pet.name,
		egg = pet.egg,
		boost = boost,
	}
	applyPetBoost(player, boost)

	petFollowUpdate:FireClient(player, {
		equipped = true,
		egg = pet.egg,
		name = pet.name,
	})
end

function Service.unequipPet(player: Player, petId: string?)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data or not data.EquippedPet then
		return
	end
	if petId and data.EquippedPet.id ~= petId then
		return
	end

	data.EquippedPet = nil
	applyPetBoost(player, 1)
	petFollowUpdate:FireClient(player, { equipped = false })
end

local function sendEquippedFollowVisual(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data or not data.EquippedPet then
		return
	end

	local boost = resolvePetBoost(data.EquippedPet)
	data.EquippedPet.boost = boost
	applyPetBoost(player, boost)
	petFollowUpdate:FireClient(player, {
		equipped = true,
		egg = data.EquippedPet.egg,
		name = data.EquippedPet.name,
	})
end

local function getRandomPet(eggName)
	local folder = petsAssets:FindFirstChild(eggName)
	if not folder then
		return nil
	end
	local pets = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(pets, child.Name)
		end
	end
	if #pets == 0 then
		return nil
	end
	return pets[math.random(1, #pets)]
end

function Service.init()
	local moneyService = cachedModules.Cache.MoneyService
	local dataService = cachedModules.Cache.DataService

	local function onPlayerReady(player: Player)
		Service.syncPetTools(player)
		sendEquippedFollowVisual(player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local timeout = 30
			while timeout > 0 and not player:GetAttribute("DataLoaded") do
				task.wait(0.5)
				timeout -= 0.5
			end
			if player:GetAttribute("DataLoaded") then
				onPlayerReady(player)
			end
		end)

		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			Service.syncPetTools(player)
			sendEquippedFollowVisual(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("DataLoaded") then
			task.spawn(onPlayerReady, player)
		end
	end

	petUse.OnServerEvent:Connect(function(player, action, petId)
		if action == "equip" then
			Service.equipPet(player, petId)
		elseif action == "unequip" then
			Service.unequipPet(player, petId)
		end
	end)

	remotes.PetRoll.OnServerEvent:Connect(function(player, eggName)
		local egg = EGG_DATA[eggName]
		if not egg then
			return
		end
		if not moneyService.hasEnoughCash(player, egg.cost) then
			remotes.PetRollResult:FireClient(player, { success = false, msg = "Not enough cash!" })
			return
		end
		local petName = getRandomPet(eggName)
		if not petName then
			remotes.PetRollResult:FireClient(player, { success = false, msg = "No pets in this egg!" })
			return
		end

		moneyService.removeCash(player, egg.cost)

		local data = dataService.getData(player)
		local petRecord = {
			id = generatePetId(),
			name = petName,
			egg = eggName,
			boost = egg.boost,
			rarity = egg.rarity,
		}

		if data then
			if not data.OwnedPets then
				data.OwnedPets = {}
			end
			table.insert(data.OwnedPets, petRecord)
		end

		Service.createPetTool(player, petRecord)
		Service.equipPet(player, petRecord.id)

		remotes.PetRollResult:FireClient(player, {
			success = true,
			petName = petName,
			eggName = eggName,
			boost = egg.boost,
			rarity = egg.rarity,
		})
	end)
end

return Service
