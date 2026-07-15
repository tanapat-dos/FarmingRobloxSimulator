--[[
	GearUseActivator — cloned into procedural gear tools (Fertilizer,
	Mutation Spray). On activation, affects the player's NEAREST own
	crop within range, then consumes one charge.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local cachedModules = require(game.ServerScriptService.Server.CachedModules)
local modules = ReplicatedStorage:WaitForChild("Modules")
local seedDataModule = require(modules.SeedData)
local plantKeyUtil = require(modules.PlantKeyUtil)

local USE_RANGE = 22

local Activator = {}

local Tool: Tool = script.Parent
local random = Random.new()

local function notify(player: Player, message: string, kind: string?)
	local remote = ReplicatedStorage.RemoteEvents:FindFirstChild("Notify")
	if remote then
		remote:FireClient(player, message, kind or "info")
	end
end

local function nearestOwnPlant(player: Player): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local best, bestDistance = nil, USE_RANGE
	for _, plant in workspace.World.Map.PlantedSeeds.Server:GetChildren() do
		if plant:GetAttribute("Owner") == player.UserId then
			local distance = (plant:GetPivot().Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = plant, distance
			end
		end
	end
	return best
end

local function useFertilizer(player: Player, plant: Model): boolean
	local serverConfig = plant:FindFirstChild("ServerConfiguration")
	if not serverConfig then
		return false
	end

	local seedData = seedDataModule.getData(plantKeyUtil.getSeedName(plant.Name))
	local growth = serverConfig:FindFirstChild("GrowthPercentage")

	if growth and growth.Value < 100 then
		growth.Value = 100
		notify(player, "🌱 Fertilizer used — crop fully grown!", "success")
		return true
	end

	-- Already grown: on multi-harvest plants, ripen all fruits instantly
	if seedData and seedData.MultiHarvest.Value then
		local interval = seedData.HarvestInterval.Value
		local ripened = false
		for _, fruit in serverConfig.Fruits:GetChildren() do
			local canHarvest = fruit:FindFirstChild("CanHarvest")
			local lastHarvest = fruit:FindFirstChild("LastHarvest")
			if canHarvest and lastHarvest and not canHarvest.Value then
				lastHarvest.Value = os.time() - interval
				ripened = true
			end
		end
		if ripened then
			notify(player, "🌱 Fertilizer used — fruits ripened!", "success")
			return true
		end
	end

	notify(player, "That crop is already fully grown!", "error")
	return false
end

local function useMutationSpray(player: Player, plant: Model): boolean
	local mutationService = cachedModules.Cache.MutationService
	local serverConfig = plant:FindFirstChild("ServerConfiguration")
	if not serverConfig or not mutationService then
		return false
	end

	-- Pick a fruit that doesn't already have a growth mutation
	local candidates = {}
	for _, fruit in serverConfig.Fruits:GetChildren() do
		local mutations = fruit:FindFirstChild("Mutations")
		if mutations and not string.find(mutations.Value, "Golden") and not string.find(mutations.Value, "Rainbow") then
			table.insert(candidates, fruit)
		end
	end

	if #candidates == 0 then
		notify(player, "Every fruit on that crop is already mutated!", "error")
		return false
	end

	local fruit = candidates[random:NextInteger(1, #candidates)]
	local mutationName = random:NextNumber(0, 1) <= 0.25 and "Rainbow" or "Golden"
	mutationService.giveMutation(plant, fruit.Name, mutationName)
	notify(player, ("✨ Mutation Spray: this fruit is now <b>%s</b>!"):format(mutationName), "success")
	return true
end

Tool.Activated:Connect(function()
	local player = Players:GetPlayerFromCharacter(Tool.Parent)
	if not player then
		return
	end
	if player:FindFirstChild("GearUseDebounce") then
		return
	end
	local db = Instance.new("Folder")
	db.Name = "GearUseDebounce"
	db.Parent = player
	Debris:AddItem(db, 0.6)

	local gearName = Tool:GetAttribute("Name")
	local plant = nearestOwnPlant(player)
	if not plant then
		notify(player, "Stand next to one of your crops to use this.", "error")
		return
	end

	local used = false
	if gearName == "Fertilizer" then
		used = useFertilizer(player, plant)
	elseif gearName == "Mutation Spray" then
		used = useMutationSpray(player, plant)
	end

	if used then
		local inventoryService = cachedModules.Cache.InventoryService
		inventoryService.removeItem(player, gearName, 1)
	end
end)

return Activator
