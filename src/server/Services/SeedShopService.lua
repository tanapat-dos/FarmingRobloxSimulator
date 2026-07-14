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
local ToolData = require(ReplicatedStorage:WaitForChild("Modules").ToolData)

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
	return Random.new():NextNumber(1,3)
end

function Service.getRandomFruitSize(name: string, extraData: any)
	if name == "Carrot Seed" then
		return 1
	end
	return Random.new():NextNumber(1,3)
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

local function GenerateStock()
	local SETTINGS = {
		STOCK_RANGE = {
			Common = { Min = 15, Max = 25 },
			Uncommon = { Min = 10, Max = 20 },
			Rare = { Min = 5, Max = 15 },
			Legendary = { Min = 1, Max = 3 },
			Mythical = { Min = 1, Max = 2 },
			Divine = { Min = 1, Max = 1 },
			Prismatic = { Min = 1, Max = 1 },
		},
		CHANCE_BASED_RARITIES = {
			Legendary = 5,
			Mythical = 2,
			Divine = 0.5,
			Prismatic = 0.1,
		}
	}

	local seedStock, gearStock = {}, {}

	for _, seedName in ipairs(SeedData.getSeedOrder()) do
		local seed = SeedData.getData(seedName)
		if seed and isShopSeed(seedName) then
			local rarity = seed:FindFirstChild("Rarity") and seed.Rarity.Value or "Common"
			local range = SETTINGS.STOCK_RANGE[rarity] or { Min = 5, Max = 10 }
			local guaranteed = not SETTINGS.CHANCE_BASED_RARITIES[rarity]
			local available = guaranteed or (math.random() * 100 <= SETTINGS.CHANCE_BASED_RARITIES[rarity])

			seedStock[seedName] = {
				Name = seed:FindFirstChild("Name") and seed.Name.Value or seedName,
				Price = seed:FindFirstChild("Price") and seed.Price.Value or 10,
				Rarity = rarity,
				StockAmount = available and math.random(range.Min, range.Max) or 0,
				IsInStock = available,
				LayoutOrder = seed:FindFirstChild("LayoutOrder") and seed.LayoutOrder.Value or 0,
				DevProduct = seed:FindFirstChild("DevProduct") and seed.DevProduct.Value or 0
			}
		end
	end

	for _, gearName in ipairs(ToolData.getToolOrder()) do
		local gear = ToolData.getData(gearName)
		if gear then
			local rarity = gear:FindFirstChild("Rarity") and gear.Rarity.Value or "Common"
			local range = SETTINGS.STOCK_RANGE[rarity] or { Min = 2, Max = 4 }
			local guaranteed = not SETTINGS.CHANCE_BASED_RARITIES[rarity]
			local available = guaranteed or (math.random() * 100 <= SETTINGS.CHANCE_BASED_RARITIES[rarity])

			gearStock[gearName] = {
				Name = gear:FindFirstChild("Name") and gear.Name.Value or gearName,
				Price = gear:FindFirstChild("Price") and gear.Price.Value or 10,
				Rarity = rarity,
				StockAmount = available and math.random(range.Min, range.Max) or 0,
				IsInStock = available,
				LayoutOrder = gear:FindFirstChild("LayoutOrder") and gear.LayoutOrder.Value or 0,
				DevProduct = gear:FindFirstChild("DevProduct") and gear.DevProduct.Value or 0
			}
		end
	end

	return { Seeds = seedStock, Gears = gearStock }
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
		local decoded = HttpService:JSONDecode(raw)
		return decoded
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

	RemoteEvents.ResetSeedShop:FireAllClients(stock.Seeds)
	RemoteEvents.ResetGearShop:FireAllClients(stock.Gears)
end

local function OnRestockMessage()
	local stock = Service:GetCurrentStock()
	if stock then
		RemoteEvents.ResetSeedShop:FireAllClients(stock.Seeds)
		RemoteEvents.ResetGearShop:FireAllClients(stock.Gears)
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
				RemoteEvents.GearShopTimer:FireAllClients(FormatTime(remaining))
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
					RemoteEvents.ResetSeedShop:FireClient(player, stock.Seeds)
					RemoteEvents.ResetGearShop:FireClient(player, stock.Gears)
					return
				end
				task.wait(1)
			end
		end)
	end)

	RemoteEvents.BuyCrop.OnServerEvent:Connect(function(player, cropName, price)
		if player:GetAttribute("DataLoaded") ~= true then return end
		if not moneyService.hasEnoughCash(player, price) then return end
		local stock = Service:GetCurrentStock()
		if not stock then return end
		local crop = stock.Seeds[cropName]
		if not crop or crop.StockAmount <= 0 then return end
		moneyService.removeCash(player, price)
		crop.StockAmount -= 1
		if IS_STUDIO then
			studioStock = stock
		else
			Service:SaveStockToMemoryStore(stock)
		end
		Service.giveSeed(player, cropName, 1)
	end)

	RemoteEvents.BuyGear.OnServerEvent:Connect(function(player, gearName, price)
		if player:GetAttribute("DataLoaded") ~= true then return end
		if not moneyService.hasEnoughCash(player, price) then return end
		local stock = Service:GetCurrentStock()
		if not stock then return end
		local gear = stock.Gears[gearName]
		if not gear or gear.StockAmount <= 0 then return end
		moneyService.removeCash(player, price)
		Service.giveSeed(player, gearName, 1)
	end)
end

return Service
