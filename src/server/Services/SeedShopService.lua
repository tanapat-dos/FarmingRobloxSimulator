local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()
local studioStock = nil -- in-memory stock for Studio mode

local SeedData = require(ReplicatedStorage:WaitForChild("Modules").SeedData)
local ShopStock = require(ReplicatedStorage:WaitForChild("Modules").ShopStock)
local EconomyBalance = require(ReplicatedStorage:WaitForChild("Modules").EconomyBalance)

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local stockMemoryKey = "GLOBAL_SHOP_STOCK"
local timeMemoryKey = "GLOBAL_RESTOCK_TIME"
local restockInterval = 300 -- 300

local Service = {
	RestockInterval = restockInterval,
	LastRestockTime = os.time()
}

function Service.getRandomPlantSize(name: string, extraData: any)
	-- Was uniform 1-3: plots read as chaos with random giants everywhere.
	-- Keep gentle variety; fruit size (below) carries the "giant crop" fantasy.
	return Random.new():NextNumber(1, 1.75)
end

function Service.getRandomFruitSize(name: string, extraData: any)
	if name == "Carrot Seed" then
		return 1
	end
	-- Bias low so giant fruits (~2.5x+) are rare and exciting instead of
	-- constant. This also feeds sell value (weight^2), so the squared curve
	-- keeps big harvests a jackpot rather than the average case.
	local r = Random.new():NextNumber(0, 1)
	return 1 + (r ^ 2.2) * 2
end

function Service.generateKey(prefix:string)
	return prefix..":"..string.sub(HttpService:GenerateGUID(false),1,5)
end

function Service.isCloseToPlant(referencePoint:Part, plotData: any, locationToPlant:CFrame, magnitudeThreshold: number)
	if plotData and locationToPlant and magnitudeThreshold and referencePoint then
		for plantKey: string, data: any in plotData do
			-- Converting Saved Location to World Location
			local location = CFrame.new(table.unpack(data.Location))
			location = referencePoint.CFrame:ToWorldSpace(location)

			local distance = (location.Position - locationToPlant.Position).Magnitude
			if distance <= magnitudeThreshold then
				return true
			end
		end
	end
	return false
end

function Service.plantSeed(player: Player, seedName: string, location: CFrame, plantScaling: number)
	local character = player.Character
	if player and seedName and location and character then

		local dataService = cachedModules.Cache.DataService
		local inventoryService = cachedModules.Cache.InventoryService
		local plotService = cachedModules.Cache.PlotService
		local mutationService = cachedModules.Cache.MutationService

		local playerData = dataService.getData(player)
		local seedData = SeedData.getData(seedName)

		if playerData and seedData then

			local currentTool = character:FindFirstChildWhichIsA("Tool")
			if currentTool and currentTool:GetAttribute("isSeed") == true and currentTool:GetAttribute("Name") == seedName then

				-- Checking for Seed in Inv
				local inventory = playerData.Inventory
				local foundSeed = inventory[seedName]

				if foundSeed then
					if player:FindFirstChild("PlantDebounce") then
						return
					end	

					local debounce = Instance.new("Folder")
					debounce.Name = "PlantDebounce"
					debounce.Parent = player
					Debris:AddItem(debounce, 0.5)

					local plotData = playerData.PlotData

					-- Plot capacity: owned beds x cropsPerPlot
					local plotService = cachedModules.Cache.PlotService
					local plantCount = 0
					for _ in plotData do
						plantCount += 1
					end
					local capacity = plotService.getOwnedBedCount(player) * EconomyBalance.PLOTS.cropsPerPlot
					if plantCount >= capacity then
						local notifyRemote = RemoteEvents:FindFirstChild("Notify")
						if notifyRemote then
							notifyRemote:FireClient(player,
								("Your plots are full (%d/%d)! Harvest crops or buy another plot."):format(plantCount, capacity),
								"error")
						end
						return
					end

					-- Check if Seed too close too plant
					local isTooClose = Service.isCloseToPlant(
						plotService.getPlot(player).ReferencePoint,
						plotData,
						location,
						2.5
					)

					if isTooClose then
						return
					end

					-- Reduce seeds
					inventoryService.removeItem(player,seedName,1)
					--

					-- Change Location to Relative
					local locationToSave = plotService.getPlot(player).ReferencePoint.CFrame:ToObjectSpace(location)

					-- Generate PlantKey
					local key = Service.generateKey(seedData.SeedPrefix.Value)

					local fruitsArray = {}
					local harvestCount = math.max(1, seedData.HarvestCount.Value)
					for i = 1, harvestCount do
						local growthMutation = mutationService.getRandomGrowthMutation(nil, i)
						fruitsArray[i] = {
							CanHarvest = false,
							LastHarvest = os.time(),
							Mutations = growthMutation,
							SizeScaling = Service.getRandomFruitSize(seedName,{}),
							Rarity = "Common",
						}
					end

					plotData[key] = {
						GrowthPercentage = 0,
						LastGrowthIncrement = os.time(),
						DatePlanted = os.time(),
						Location = { locationToSave:GetComponents()},
						Fruits = fruitsArray,
						["PlantSize"] = plantScaling or 1
					}

					-- Plant Effect
					task.spawn(function()
						local rightPlot = plotService.getPlot(player):FindFirstChild("Soil")
						if rightPlot then
							local params = RaycastParams.new()
							params.FilterType = Enum.RaycastFilterType.Include
							params.FilterDescendantsInstances = {rightPlot}
							local result = workspace:Raycast(location.Position+Vector3.new(0,5,0), Vector3.new(0,-999999,0), params)

							if result then
								RemoteEvents.ClientEffects:FireAllClients("PlantEffect",{Location = CFrame.new(result.Position)})
							end
						end
					end)

					plotService.updatePlot(player, "seedPlanted", {itemKey = key})

					-- Track achievement stat
					local achieveService = cachedModules.Cache.AchievementService
					if achieveService and achieveService.addCropsPlanted then
						achieveService.addCropsPlanted(player, 1)
					end

				end

			end
		end

	end
end

function Service.giveSeed(player:Player, seedName:string, amount:number)
	local dataService = cachedModules.Cache.DataService
	local inventoryService = cachedModules.Cache.InventoryService

	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn("❌ giveSeed received non-player argument:", player)
		return
	end

	if player:GetAttribute("DataLoaded") ~= true then return end
	local playerData = dataService.getData(player)
	if not playerData then return end

	local inventory = playerData.Inventory
	local foundSeed = inventory[seedName]

	if foundSeed then
		foundSeed.Count += amount
	else
		inventory[seedName] = {Count = amount}
	end

	-- ✅ Just pass the base name
	inventoryService.inventoryUpdated(player, seedName)
end

local function FormatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

local seedStorage = ServerStorage:WaitForChild("CropSeeds")

local function isShopSeed(seedName: string): boolean
	if not SeedData.isPlayable(seedName) then
		return false
	end
	return seedStorage:FindFirstChild(seedName) ~= nil
end

local GUARANTEED_SEEDS = {
	["Carrot Seed"] = true,
	["Wheat Seed"] = true,
}

local function GenerateStock()
	local candidates = {}

	for _, seedName in ipairs(SeedData.getSeedOrder()) do
		local seed = SeedData.getData(seedName)
		if seed and isShopSeed(seedName) then
			local rarity = seed:FindFirstChild("Rarity") and seed.Rarity.Value or "Common"
			local price = seed:FindFirstChild("Price") and seed.Price.Value or 10
			local baseValue = seed:FindFirstChild("BaseValue") and seed.BaseValue.Value or price
			local available = GUARANTEED_SEEDS[seedName] or ShopStock.rollAppearance(rarity)

			if available then
				local range = ShopStock.getStockRange(rarity, ShopStock.SEED_STOCK_RANGE)
				table.insert(candidates, {
					Key = seedName,
					Name = seed:FindFirstChild("Name") and seed.Name.Value or seedName,
					Price = price,
					Rarity = rarity,
					PriceRatio = ShopStock.computePriceRatio(baseValue, price),
					StockAmount = math.random(range.Min, range.Max),
					IsInStock = true,
					DevProduct = seed:FindFirstChild("DevProduct") and seed.DevProduct.Value or 0,
				})
			end
		end
	end

	ShopStock.assignLayoutOrder(candidates)
	return ShopStock.entriesToMap(candidates)
end

local function normalizeStock(stock: any)
	if type(stock) == "table" and stock.Seeds then
		return stock.Seeds
	end
	return stock
end

function Service:GetCurrentStock()
	if IS_STUDIO then
		return normalizeStock(studioStock)
	end
	local memoryStore = MemoryStoreService:GetSortedMap("GLOBAL_SHOP")
	local success, raw = pcall(function()
		return memoryStore:GetAsync(stockMemoryKey)
	end)
	if success and raw then
		local decoded = HttpService:JSONDecode(raw)
		return normalizeStock(decoded)
	end
	return nil
end

function Service:GetTimeUntilRestock()
	local memoryStore = MemoryStoreService:GetSortedMap("GLOBAL_SHOP")
	local success, timestamp = pcall(function()
		return memoryStore:GetAsync(timeMemoryKey)
	end)
	if success and timestamp then
		self.LastRestockTime = timestamp
	end
	local elapsed = os.time() - self.LastRestockTime
	return math.max(0, restockInterval - elapsed)
end

function Service:SaveStockToMemoryStore(stockData)
	if IS_STUDIO then return end
	local memoryStore = MemoryStoreService:GetSortedMap("GLOBAL_SHOP")
	local jsonData = HttpService:JSONEncode(stockData)
	pcall(function()
		memoryStore:SetAsync(stockMemoryKey, jsonData, restockInterval + 60)
	end)
end

function Service:SaveRestockTime()
	if IS_STUDIO then return end
	local memoryStore = MemoryStoreService:GetSortedMap("GLOBAL_SHOP")
	pcall(function()
		memoryStore:SetAsync(timeMemoryKey, os.time(), restockInterval + 60)
	end)
end

function Service:BroadcastRestock()
	local stock = GenerateStock()
	if IS_STUDIO then
		studioStock = stock
	else
		self:SaveStockToMemoryStore(stock)
		self:SaveRestockTime()
		pcall(function()
			MessagingService:PublishAsync("GlobalShopRestock", true)
		end)
	end

	RemoteEvents.ResetSeedShop:FireAllClients(stock)

	local petService = cachedModules.Cache.PetService
	if petService and petService.BroadcastRestock then
		petService:BroadcastRestock()
	end
end

local function OnRestockMessage()
	local stock = Service:GetCurrentStock()
	if stock then
		RemoteEvents.ResetSeedShop:FireAllClients(stock)
	end
end

function Service.init()
	local dataService = cachedModules.Cache.DataService
	local inventoryService = cachedModules.Cache.InventoryService
	local moneyService = cachedModules.Cache.MoneyService

	if IS_STUDIO then
		-- Generate stock immediately so players joining don't wait 5 minutes
		task.defer(function()
			Service:BroadcastRestock()
		end)
	else
		MessagingService:SubscribeAsync("GlobalShopRestock", OnRestockMessage)
		-- Live servers: seed MemoryStore on first boot, otherwise shop stays empty until restock timer.
		task.defer(function()
			if Service:GetCurrentStock() then
				return
			end
			Service:BroadcastRestock()
		end)
	end

	task.spawn(function()
		while true do
			local remaining = IS_STUDIO and restockInterval or Service:GetTimeUntilRestock()
			while remaining > 0 do
				RemoteEvents.SeedShopTimer:FireAllClients(FormatTime(remaining))
				task.wait(1)
				remaining -= 1
			end
			Service:BroadcastRestock()
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local tries = IS_STUDIO and 30 or 10
			for _ = 1, tries do
				local stock = Service:GetCurrentStock()
				if stock then
					RemoteEvents.ResetSeedShop:FireClient(player, stock)
					return
				end
				task.wait(1)
			end
		end)
	end)

	RemoteEvents.BuyCrop.OnServerEvent:Connect(function(player, cropName)
		if player:GetAttribute("DataLoaded") ~= true then return end
		local stock = Service:GetCurrentStock()
		if not stock then return end
		local crop = stock[cropName]
		if not crop or crop.StockAmount <= 0 then return end
		-- Server-authoritative price: never trust a client-sent value
		local price = crop.Price
		if typeof(price) ~= "number" or price <= 0 then return end
		if not moneyService.hasEnoughCash(player, price) then return end
		moneyService.removeCash(player, price)
		crop.StockAmount -= 1
		if IS_STUDIO then
			studioStock = stock
		else
			Service:SaveStockToMemoryStore(stock)
		end
		Service.giveSeed(player, cropName, 1)
	end)
end

return Service
