local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local remotes = ReplicatedStorage.RemoteEvents
local assets = ReplicatedStorage.Assets
local modules = ReplicatedStorage.Modules

local cachedModules = require(script.Parent.Parent.Server.CachedModules)
local seedDataModule = require(modules.SeedData)
local plantKeyUtil = require(modules.PlantKeyUtil)

local serverFolder = workspace.World.Map.PlantedSeeds.Server

local Service = {}

function Service.isWithinHarvestBounds(character: Model, part: Instance, magnitudeThresold: number)
	if character and part and magnitudeThresold then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local distance = (rootPart.Position - part.Position).Magnitude
			if distance <= magnitudeThresold then
				return true
			end
		end
	end
	return false
end

function Service.Harvest(ownerPlotData: any, player: Player, foundPlant: Model, fruitNumber: string, multiHarvest: boolean)
	local inventoryService = cachedModules.Cache.InventoryService
	
	-- Service.Harvest() can be used to steal fruits.
	
	local fruitName = plantKeyUtil.resolveCropName(foundPlant.Name)
	local serverConfiguration = foundPlant.ServerConfiguration
	
	if multiHarvest then
	
		
		-- Harvest distance
		local prompt: ProximityPrompt = foundPlant.FruitPrompts[fruitNumber].HarvestPrompt
		if not Service.isWithinHarvestBounds(player.Character, foundPlant.FruitPrompts[fruitNumber],prompt.MaxActivationDistance) then
			return
		end
		
		-- Harvest Fruit
		local fruitFolder: Folder = serverConfiguration.Fruits:FindFirstChild(fruitNumber)
		if fruitFolder then
			if not fruitFolder.CanHarvest.Value then return end
			
			if player.UserId == foundPlant:GetAttribute("Owner") then
				
				inventoryService.giveFruit(
					player,
					fruitName,
					{
						Mutations = fruitFolder.Mutations.Value,
						FruitSize = fruitFolder.SizeScaling.Value,
						OverallPlantSize = serverConfiguration.PlantSize.Value,
						Rarity = fruitFolder.Rarity.Value,
					}
				)
			else
				return
			end
			
			fruitFolder.SizeScaling.Value = 1
			fruitFolder.Mutations.Value = ""
			fruitFolder.Rarity.Value = "Common"
			fruitFolder.CanHarvest.Value = false
			fruitFolder.LastHarvest.Value = os.time()
			
		end
		
	else
		
		if fruitNumber then return end
		-- Harvest distance
		local harvestHost = foundPlant:FindFirstChild("HarvestAnchor") or foundPlant.PrimaryPart
		local prompt: ProximityPrompt = harvestHost.HarvestPrompt
		if not Service.isWithinHarvestBounds(player.Character, harvestHost, prompt.MaxActivationDistance) then
			return
		end

		-- Harvest Fruit
		local fruitFolder = serverConfiguration.Fruits["1"]
		
		if player.UserId == foundPlant:GetAttribute("Owner") then

			inventoryService.giveFruit(
				player,
				fruitName,
				{
					Mutations = fruitFolder.Mutations.Value,
					FruitSize = fruitFolder.SizeScaling.Value,
					OverallPlantSize = serverConfiguration.PlantSize.Value,
					Rarity = fruitFolder.Rarity.Value,
				}
			)
		else
			return
		end
		
		fruitFolder.CanHarvest.Value = false
		fruitFolder.LastHarvest.Value = os.time()
		
		ownerPlotData[foundPlant.Name] = nil
		foundPlant:Destroy()
	end
	
end

function Service.init()
	local dataService = cachedModules.Cache.DataService
	
	remotes.Harvest.OnServerEvent:Connect(function(player: Player, plantKey: string, fruitNumber: string)
		local foundPlant = serverFolder:FindFirstChild(plantKey)
		local seedData = seedDataModule.getData(plantKeyUtil.getSeedName(plantKey))
		
		if foundPlant and seedData then
			local owner = foundPlant:GetAttribute("Owner")
			local ownerPlayer = players:GetPlayerByUserId(owner)
			
			if ownerPlayer then
				local ownerData = dataService.getData(ownerPlayer)
				
				if ownerData then
					local foundPlantData = ownerData.PlotData[plantKey]
					local serverConfiguration = foundPlant:FindFirstChild("ServerConfiguration")
					
					if foundPlantData and serverConfiguration then
						if serverConfiguration.GrowthPercentage.Value < 100 then return end
						
						if seedData.MultiHarvest.Value and fruitNumber and foundPlant.FruitPrompts:FindFirstChild(fruitNumber) then
							Service.Harvest(ownerData.PlotData,player,foundPlant,fruitNumber,seedData.MultiHarvest.Value)
							return
						end
						
						if not seedData.MultiHarvest.Value then -- Single Harvest
			Service.Harvest(ownerData.PlotData, player, foundPlant, nil, seedData.MultiHarvest.Value)
		end
						
					end
				end
			end	
		end
	end)
end


return Service
