local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local remotes = ReplicatedStorage.RemoteEvents
local assets = ReplicatedStorage.Assets
local modules = ReplicatedStorage.Modules

local cachedModules = require(script.Parent.Parent.Server.CachedModules)
local seedDataModule = require(modules.SeedData)
local plantKeyUtil = require(modules.PlantKeyUtil)
local FruitHarvestConfig = require(modules:WaitForChild("FruitHarvestConfig"))

local serverFolder = workspace.World.Map.PlantedSeeds.Server

local Service = {}

-- Every path that abandons a harvest must say so. A harvest silently doing nothing was itself a
-- bug: the single-harvest break below went unnoticed because the handler dropped requests without
-- a word. Rejections are expected traffic (exploiters, stale prompts, out-of-range), so these are
-- warns rather than errors, but they are never silent.
local function refuse(reason: string, ...): ()
	warn(("[HarvestService] refused: " .. reason):format(...))
end

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

function Service.isWithinFruitHarvestRange(character: Model, fruitPart: BasePart, prompt: ProximityPrompt): boolean
	local maxDistance = math.max(prompt.MaxActivationDistance, FruitHarvestConfig.MAX_DISTANCE)
	if Service.isWithinHarvestBounds(character, fruitPart, maxDistance) then
		return true
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	local delta = fruitPart.Position - rootPart.Position
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local vertical = math.abs(delta.Y)
	return horizontal <= FruitHarvestConfig.MAX_HORIZONTAL
		and vertical <= FruitHarvestConfig.MAX_VERTICAL
end

function Service.Harvest(ownerPlotData: any, player: Player, foundPlant: Model, fruitNumber: string, multiHarvest: boolean)
	local inventoryService = cachedModules.Cache.InventoryService
	
	-- Service.Harvest() can be used to steal fruits.
	
	local fruitName = plantKeyUtil.resolveCropName(foundPlant.Name)
	local serverConfiguration = foundPlant.ServerConfiguration
	
	if multiHarvest then
		-- Harvest distance (tall tree fruits: stand near trunk, aim with mouse — see FruitAimHarvest)
		-- FindFirstChild rather than direct indexing: a stale fruitNumber from a client whose
		-- replication lagged behind a harvest would otherwise error and kill the remote's thread.
		local fruitPrompts = foundPlant:FindFirstChild("FruitPrompts")
		local fruitPart = fruitPrompts and fruitPrompts:FindFirstChild(fruitNumber)
		if not fruitPart or not fruitPart:IsA("BasePart") then
			refuse("%s fruit %s has no FruitPrompts part", foundPlant.Name, tostring(fruitNumber))
			return
		end

		local prompt = fruitPart:FindFirstChild("HarvestPrompt")
		if not prompt or not prompt:IsA("ProximityPrompt") then
			refuse("%s fruit %s has no HarvestPrompt", foundPlant.Name, tostring(fruitNumber))
			return
		end

		if not Service.isWithinFruitHarvestRange(player.Character, fruitPart, prompt) then
			refuse("%s fruit %s out of range for %s", foundPlant.Name, tostring(fruitNumber), player.Name)
			return
		end
		
		-- Harvest Fruit
		local fruitFolder = serverConfiguration.Fruits:FindFirstChild(fruitNumber)
		if not fruitFolder then
			refuse("%s has no Fruits record %s", foundPlant.Name, tostring(fruitNumber))
			return
		end

		if not fruitFolder.CanHarvest.Value then
			refuse("%s fruit %s already harvested", foundPlant.Name, tostring(fruitNumber))
			return
		end

		if player.UserId ~= foundPlant:GetAttribute("Owner") then
			refuse("%s is not the owner of %s", player.Name, foundPlant.Name)
			return
		end

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

		fruitFolder.SizeScaling.Value = 1
		fruitFolder.Mutations.Value = ""
		fruitFolder.Rarity.Value = "Common"
		fruitFolder.CanHarvest.Value = false
		fruitFolder.LastHarvest.Value = os.time()
	else
		
		if fruitNumber then
			refuse("%s is single-harvest but got fruitNumber %s", foundPlant.Name, tostring(fruitNumber))
			return
		end

		-- Harvest distance
		local harvestHost = foundPlant:FindFirstChild("HarvestAnchor") or foundPlant.PrimaryPart
		if not harvestHost or not harvestHost:IsA("BasePart") then
			refuse("%s has no HarvestAnchor or PrimaryPart", foundPlant.Name)
			return
		end

		local prompt = harvestHost:FindFirstChild("HarvestPrompt")
		if not prompt or not prompt:IsA("ProximityPrompt") then
			refuse("%s has no HarvestPrompt on %s", foundPlant.Name, harvestHost.Name)
			return
		end

		if not Service.isWithinHarvestBounds(player.Character, harvestHost, prompt.MaxActivationDistance) then
			refuse("%s out of range for %s", foundPlant.Name, player.Name)
			return
		end

		-- Harvest Fruit
		local fruitFolder = serverConfiguration.Fruits:FindFirstChild("1")
		if not fruitFolder then
			refuse("%s has no Fruits record 1", foundPlant.Name)
			return
		end

		if not fruitFolder.CanHarvest.Value then
			refuse("%s already harvested", foundPlant.Name)
			return
		end

		if player.UserId ~= foundPlant:GetAttribute("Owner") then
			refuse("%s is not the owner of %s", player.Name, foundPlant.Name)
			return
		end

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

		fruitFolder.CanHarvest.Value = false
		fruitFolder.LastHarvest.Value = os.time()
		
		ownerPlotData[foundPlant.Name] = nil
		foundPlant:Destroy()
	end
	
end

function Service.init()
	local dataService = cachedModules.Cache.DataService
	local plotService = cachedModules.Cache.PlotService

	task.defer(function()
		for _, plant in serverFolder:GetChildren() do
			if plant:IsA("Model") and plotService and plotService.patchFruitHarvestPromptsOnPlant then
				plotService.patchFruitHarvestPromptsOnPlant(plant)
			end
		end
	end)

	remotes.Harvest.OnServerEvent:Connect(function(player: Player, plantKey: string, fruitNumber: string?)
		-- Reject non-string args: FindFirstChild errors on tables/Instances,
		-- which would kill this event's thread with exploiter-controlled input.
		--
		-- fruitNumber is optional and MUST stay optional: single-harvest crops (18 of the 19 in
		-- SeedData) are harvested via ProximityPrompts, which fires plantKey only. Requiring it to
		-- be a string here rejected every single-harvest request on this line — silently, because
		-- the old guard returned without a warn.
		if typeof(plantKey) ~= "string" then
			refuse("plantKey from %s was %s, expected string", player.Name, typeof(plantKey))
			return
		end
		if fruitNumber ~= nil and typeof(fruitNumber) ~= "string" then
			refuse("fruitNumber from %s was %s, expected string or nil", player.Name, typeof(fruitNumber))
			return
		end

		local foundPlant = serverFolder:FindFirstChild(plantKey)
		if not foundPlant then
			refuse("no planted crop named %s", plantKey)
			return
		end

		local seedData = seedDataModule.getData(plantKeyUtil.getSeedName(plantKey))
		if not seedData then
			refuse("no SeedData for %s", plantKey)
			return
		end

		local owner = foundPlant:GetAttribute("Owner")
		local ownerPlayer = players:GetPlayerByUserId(owner)
		if not ownerPlayer then
			refuse("owner %s of %s is not in game", tostring(owner), plantKey)
			return
		end

		local ownerData = dataService.getData(ownerPlayer)
		if not ownerData then
			refuse("no profile data for owner %s of %s", ownerPlayer.Name, plantKey)
			return
		end

		if not ownerData.PlotData[plantKey] then
			refuse("no PlotData entry for %s", plantKey)
			return
		end

		local serverConfiguration = foundPlant:FindFirstChild("ServerConfiguration")
		if not serverConfiguration then
			refuse("%s has no ServerConfiguration", plantKey)
			return
		end

		if serverConfiguration.GrowthPercentage.Value < 100 then
			refuse("%s is only %.1f%% grown", plantKey, serverConfiguration.GrowthPercentage.Value)
			return
		end

		if seedData.MultiHarvest.Value then
			if not fruitNumber then
				refuse("%s is multi-harvest but no fruitNumber was sent", plantKey)
				return
			end
			Service.Harvest(ownerData.PlotData, player, foundPlant, fruitNumber, true)
			return
		end

		-- Single harvest: fruitNumber must be absent, Service.Harvest enforces that.
		Service.Harvest(ownerData.PlotData, player, foundPlant, nil, false)
	end)
end


return Service
