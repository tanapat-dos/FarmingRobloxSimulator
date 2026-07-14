local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local petsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local ShopStock = require(ReplicatedStorage:WaitForChild("Modules").ShopStock)
local EconomyBalance = require(ReplicatedStorage:WaitForChild("Modules").EconomyBalance)
local activatorTemplate = script.Parent.InventoryService.PetToolActivator
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local IS_STUDIO = RunService:IsStudio()
local studioStock: any = nil
local stockMemoryKey = "GLOBAL_PET_STOCK"

local EGG_ORDER = EconomyBalance.getEggOrder()
local EGG_DATA = EconomyBalance.getEggData()

local GUARANTEED_EGGS = {
	["Common Egg"] = true,
}

local Service = {}
Service.EGG_DATA = EGG_DATA
Service.EGG_ORDER = EGG_ORDER

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
local resetPetShop = ensureRemote("ResetPetShop")

local function generateEggStock()
	local candidates = {}

	for _, eggName in ipairs(EGG_ORDER) do
		local egg = EGG_DATA[eggName]
		if egg then
			local available = GUARANTEED_EGGS[eggName] or ShopStock.rollAppearance(egg.rarity)
			if available then
				local range = ShopStock.getStockRange(egg.rarity, ShopStock.EGG_STOCK_RANGE)
				local boostRange = EconomyBalance.getEggBoostRange(eggName)
				local avgBoostPct = EconomyBalance.getEggBoostMidPct(eggName)
				local priceRatio = ShopStock.computePriceRatio(avgBoostPct, egg.cost)
				table.insert(candidates, {
					Key = eggName,
					Name = eggName,
					Price = egg.cost,
					Rarity = egg.rarity,
					BoostMin = boostRange and boostRange.min,
					BoostMax = boostRange and boostRange.max,
					Boost = EconomyBalance.pctToMultiplier(avgBoostPct),
					PriceRatio = priceRatio,
					StockAmount = math.random(range.Min, range.Max),
					IsInStock = true,
				})
			end
		end
	end

	ShopStock.assignLayoutOrder(candidates)
	return ShopStock.entriesToMap(candidates)
end

function Service:GetCurrentStock()
	if IS_STUDIO then
		return studioStock
	end
	local memoryStore = MemoryStoreService:GetSortedMap("GLOBAL_SHOP")
	local success, raw = pcall(function()
		return memoryStore:GetAsync(stockMemoryKey)
	end)
	if success and raw then
		return HttpService:JSONDecode(raw)
	end
	return nil
end

function Service:SaveStockToMemoryStore(stockData)
	if IS_STUDIO then
		return
	end
	local memoryStore = MemoryStoreService:GetSortedMap("GLOBAL_SHOP")
	local jsonData = HttpService:JSONEncode(stockData)
	pcall(function()
		memoryStore:SetAsync(stockMemoryKey, jsonData, 360)
	end)
end

function Service:BroadcastRestock()
	local stock = generateEggStock()
	if IS_STUDIO then
		studioStock = stock
	else
		self:SaveStockToMemoryStore(stock)
	end
	resetPetShop:FireAllClients(stock)
end

local function onGlobalRestock()
	local stock = Service:GetCurrentStock()
	if stock then
		resetPetShop:FireAllClients(stock)
	end
end

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
	local eggName = pet.egg
	local petName = pet.name
	if typeof(eggName) == "string" and typeof(petName) == "string" then
		local boost = EconomyBalance.getPetBoostMultiplier(eggName, petName)
		if boost > 1 then
			pet.boost = boost
			return boost
		end
	end
	if typeof(pet.boost) == "number" and pet.boost > 1 then
		return pet.boost
	end
	return 1
end

local function resolvePetGrowthReduction(pet): number
	if not pet then
		return 0
	end
	local eggName = pet.egg
	local petName = pet.name
	if typeof(eggName) == "string" and typeof(petName) == "string" then
		local reduction = EconomyBalance.getPetGrowthReductionPct(eggName, petName)
		pet.growthReduction = reduction
		return reduction
	end
	if typeof(pet.growthReduction) == "number" then
		return math.max(0, pet.growthReduction)
	end
	return 0
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
					local petName = child:GetAttribute("petName")
					if typeof(eggName) == "string" and typeof(petName) == "string" then
						return EconomyBalance.getPetBoostMultiplier(eggName, petName)
					end
				end
			end
		end
	end
	return nil
end

local function applyPetBonuses(player: Player, pet)
	local boost = resolvePetBoost(pet)
	local growthReduction = resolvePetGrowthReduction(pet)
	player:SetAttribute("PetBoost", boost)
	player:SetAttribute("PetGrowthReduction", growthReduction)
	local cashPct = math.max(0, math.floor((boost - 1) * 100))
	updatePetBoost:FireClient(player, cashPct, growthReduction)
end

local function clearPetBonuses(player: Player)
	player:SetAttribute("PetBoost", 1)
	player:SetAttribute("PetGrowthReduction", 0)
	updatePetBoost:FireClient(player, 0, 0)
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
	local growthReduction = resolvePetGrowthReduction(pet)
	local tooltip = string.format("%s pet • +%d%% cash", pet.rarity or "Pet", boostPct)
	if growthReduction > 0 then
		tooltip ..= string.format(", -%d%% grow time", growthReduction)
	end
	tooltip ..= " (click to equip)"
	tool.ToolTip = tooltip
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool:SetAttribute("isPet", true)
	tool:SetAttribute("petId", pet.id)
	tool:SetAttribute("petName", pet.name)
	tool:SetAttribute("eggName", pet.egg)
	tool:SetAttribute("petBoost", boost)
	tool:SetAttribute("petGrowthReduction", growthReduction)

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
	local growthReduction = resolvePetGrowthReduction(pet)

	data.EquippedPet = {
		id = pet.id,
		name = pet.name,
		egg = pet.egg,
		boost = boost,
		growthReduction = growthReduction,
	}
	applyPetBonuses(player, pet)

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
	clearPetBonuses(player)
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
	data.EquippedPet.growthReduction = resolvePetGrowthReduction(data.EquippedPet)
	applyPetBonuses(player, data.EquippedPet)
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

	if not IS_STUDIO then
		MessagingService:SubscribeAsync("GlobalShopRestock", onGlobalRestock)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local tries = IS_STUDIO and 30 or 10
			for _ = 1, tries do
				local stock = Service:GetCurrentStock()
				if stock then
					resetPetShop:FireClient(player, stock)
					return
				end
				task.wait(1)
			end
		end)
	end)

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

		local stock = Service:GetCurrentStock()
		local eggStock = stock and stock[eggName]
		if not eggStock or eggStock.StockAmount <= 0 or not eggStock.IsInStock then
			remotes.PetRollResult:FireClient(player, { success = false, msg = "This egg is out of stock!" })
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
		eggStock.StockAmount -= 1
		if IS_STUDIO then
			studioStock = stock
		else
			Service:SaveStockToMemoryStore(stock)
		end

		local data = dataService.getData(player)
		local petBoost = EconomyBalance.getPetBoostMultiplier(eggName, petName)
		local growthReduction = EconomyBalance.getPetGrowthReductionPct(eggName, petName)
		local petRecord = {
			id = generatePetId(),
			name = petName,
			egg = eggName,
			boost = petBoost,
			growthReduction = growthReduction,
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
			boost = petBoost,
			growthReduction = growthReduction,
			rarity = egg.rarity,
		})
	end)
end

return Service
