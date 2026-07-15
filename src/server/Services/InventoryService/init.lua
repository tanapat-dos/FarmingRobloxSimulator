local players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local modules = ReplicatedStorage:WaitForChild("Modules")
local seedStorage = ServerStorage:WaitForChild("CropSeeds")
local toolStorage = ServerStorage:WaitForChild("Tools")

local seedDataModule = require(modules.SeedData)
local EconomyBalance = require(modules.EconomyBalance)
local fruitNameParser = require(modules.FruitNameParse)
local fruitDisplayName = require(modules.FruitDisplayName)
local fruitInventoryFormat = require(modules.FruitInventoryFormat)
local ToolData = require(modules.ToolData)
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {
	mutationsEffectCache = {},
}

local FRUIT_TOOL_SCALE = 0.65

for _, v in modules.Mutations:GetChildren() do
	if v:IsA("ModuleScript") then
		Service.mutationsEffectCache[v.Name] = require(v)
	end
end

local function roundToHundredth(num)
	return math.floor(num * 100 + 0.5) / 100
end

local function findFruitToolByKey(player: Player, fruitKey: string): Tool?
	for _, container in { player.Character, player.Backpack } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("fruitID") == fruitKey then
					return child
				end
			end
		end
	end
	return nil
end

function Service.generateFruitKey(fruitName: string)
	return fruitName .. ":" .. string.sub((HttpService:GenerateGUID(false)), 1, 8)
end

function Service.giveFruit(target:Player, fruitName: string, fruitAttributes: any)
	local dataService = cachedModules.Cache.DataService
	local seedData = seedDataModule.getData(fruitName.. " Seed")

	if target and fruitName and fruitAttributes and seedData then
		local targetData = dataService.getData(target)
		if not targetData then return end

		local playerInventory = targetData.Inventory

		local mutations = fruitAttributes.Mutations
		local fruitSize = fruitAttributes.FruitSize
		local overallSize = fruitAttributes.OverallPlantSize
		local rarity = fruitAttributes.Rarity or "Common"

		local sizeToSave = 1
		if seedData.MultiHarvest.Value then
			sizeToSave = roundToHundredth(fruitSize)
		else
			sizeToSave = roundToHundredth(overallSize)
		end

		local stringToSave = fruitInventoryFormat.build(fruitName, sizeToSave, mutations, rarity)

		print(target,"Add Fruit To Inventory",stringToSave)

		local fruitKey = Service.generateFruitKey(fruitName)

		playerInventory[fruitKey] = stringToSave
		
		print(target,fruitKey)
		
		Service.inventoryUpdated(target,fruitKey)

	end
end

function Service.removeItem(player:Player, itemName: string, count:number)
	if player and itemName and count then
		local dataService = cachedModules.Cache.DataService
		local playerData = dataService.getData(player)
		
		if playerData then
			local inventory = playerData.Inventory
			local foundItem = inventory[itemName]

			if foundItem then
				local removeItem = false

				if foundItem.Count then
					foundItem.Count = math.clamp(foundItem.Count - count, 0, math.huge)
					if foundItem.Count <= 0 then
						removeItem = true
					else
						Service.inventoryUpdated(player,itemName)
					end
				else
					removeItem = true
				end

				if removeItem then
					
					-- Remove
					inventory[itemName] = nil
					
					-- Seeds
					local backpack = player.Backpack
					local isSeed = seedStorage:FindFirstChild(itemName)

					if isSeed then
						for _,v in backpack:GetChildren() do
							if v:GetAttribute("isSeed") == true and v:GetAttribute("Name") == itemName then
								v:Destroy()
								break
							end
						end
					else -- Gears for LATER, etc.
						for _,v in backpack:GetChildren() do
							if v.Name == itemName or v:GetAttribute("fruitID") == itemName or v:GetAttribute("Name") == itemName then
								v:Destroy()
							end
						end
					end

					local tool = player.Character:FindFirstChildWhichIsA("Tool")
					
					if tool then
						if isSeed and tool:GetAttribute("isSeed") == true and tool:GetAttribute("Name") == itemName then
							tool:Destroy()
						else -- Add later
							if tool.Name == itemName or tool:GetAttribute("fruitID") == itemName or tool:GetAttribute("Name") == itemName then tool:Destroy() end
						end
					end


				end

			end

		end

	end
end

function Service.createNewTool(player: Player, toolName: string)
	local dataService = cachedModules.Cache.DataService
	local playerData = dataService.getData(player)
	local itemData = playerData and playerData.Inventory[toolName]
	if not itemData then return end

	-- ✅ Procedural gear (Fertilizer etc.) — tool built entirely in code
	local proceduralGear = EconomyBalance.GEAR and EconomyBalance.GEAR[toolName]
	if proceduralGear then
		local tool = Instance.new("Tool")
		tool.Name = toolName .. " (X" .. tostring(itemData.Count) .. ")"
		tool.ToolTip = proceduralGear.description or toolName
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		tool:SetAttribute("Name", toolName)
		tool:SetAttribute("Count", itemData.Count)
		tool:SetAttribute("isGear", true)

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.9, 1.1, 0.9)
		handle.Material = Enum.Material.SmoothPlastic
		handle.Color = proceduralGear.color or Color3.fromRGB(124, 92, 60)
		handle.CanCollide = false
		handle.Massless = true
		handle.Parent = tool

		local activator = script.GearUseActivator:Clone()
		activator.Parent = tool
		require(activator)

		tool.Parent = player.Backpack
		return
	end

	local gearInfo = ToolData.getData(toolName)

	local isGear = toolStorage:FindFirstChild(toolName)
	local isSeed = seedStorage:FindFirstChild(toolName)

	-- ✅ Gear Tool
	if gearInfo and isGear then
		local toolClone = isGear:Clone()
		toolClone.Name = toolName .. " (X" .. tostring(itemData.Count) .. ")"
		toolClone:SetAttribute("Name", toolName)
		toolClone:SetAttribute("Count", itemData.Count)
		toolClone:SetAttribute("isGear", true)

		toolClone.Parent = player.Backpack
		
		local gearActivator = script.GearActivator:Clone()
		gearActivator.Parent = toolClone
		require(gearActivator)

		return
	end

	-- ✅ Seed Tool
	if isSeed then
		local toolClone = isSeed:Clone()
		toolClone.Name = toolName .. " (X" .. tostring(itemData.Count) .. ")"
		toolClone:SetAttribute("Name", toolName)
		toolClone:SetAttribute("Count", itemData.Count)
		toolClone:SetAttribute("isSeed", true)

		toolClone.Parent = player.Backpack
		
		local activator = script.SeedActivator:Clone()
		activator.Parent = toolClone
		require(activator)

		return
	end

	if not isSeed and not isGear then
	-- ✅ Fruit (mutated)
		local rarity, mutations, weight, fruitName = fruitNameParser(itemData)
		if weight > 0 and fruitName then
			-- valid fruit
			local foundTool = ReplicatedStorage.Assets.Crops:FindFirstChild(fruitName)
			if foundTool then
				local toolClone: Tool = foundTool:Clone()
				local displayScale = weight * FRUIT_TOOL_SCALE
				toolClone.Name = fruitDisplayName.getHotbarName(itemData)
				toolClone.ToolTip = fruitDisplayName.getToolTip(itemData)
				toolClone:SetAttribute("DisplayName", itemData)
				toolClone:SetAttribute("HarvestRarity", rarity)
				toolClone:SetAttribute("fruitID", toolName)
				toolClone:SetAttribute("isFruit", true)

				for _, part in toolClone:GetDescendants() do
					if part:IsA("BasePart") then
						part.Size *= displayScale
						local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
						if mesh then
							mesh.Scale *= displayScale
						end
					end
				end

				local function scaleCFrame(cf, scaleFactor)
					local pos, rot = cf.Position, cf - cf.Position
					return CFrame.new(pos * scaleFactor) * rot
				end

				for _, weld in toolClone:GetDescendants() do
					if weld:IsA("Weld") or weld:IsA("Motor6D") then
						weld.C0 = scaleCFrame(weld.C0, displayScale)
						weld.C1 = scaleCFrame(weld.C1, displayScale)
					end
				end

				local handle = toolClone:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					local plantFolder = ReplicatedStorage.Assets.Plants:FindFirstChild(fruitName)
					local clientModel = plantFolder and plantFolder:FindFirstChild("ClientModel")
					if clientModel then
						local _, size = clientModel:GetBoundingBox()
						local longestAxis = math.max(size.X, size.Y, size.Z)
						toolClone.GripPos = Vector3.new(0, 0, longestAxis * 0.125 * displayScale)
					end
				end

				-- Giving Mutations

				task.spawn(function()
					for _, mutation: string in mutations do
						local effectModule = Service.mutationsEffectCache[mutation]
						if effectModule then
							effectModule.applyToolEffect(toolClone)
						end
					end

					local harvestRarityEffects = require(modules.HarvestRarityEffects)
					harvestRarityEffects.applyToTool(toolClone, rarity)
				end)


				---

				toolClone.Parent = player.Backpack

			end
		end
	end
	
end

function Service.inventoryUpdated(player : Player, ...)
	local dataService = cachedModules.Cache.DataService
	local playerData = dataService.getData(player)

	if playerData then
		local inventory = playerData.Inventory
		local arguments = {...}
		for _, itemUpdated in arguments do
			local foundItemInInventory = inventory[itemUpdated]
			if foundItemInInventory then
				
				-- IS A SEED/GEAR/OR OTHER
				local seedToolName = itemUpdated
				local isSeed = seedStorage:FindFirstChild(seedToolName)
				local isGear = toolStorage:FindFirstChild(itemUpdated)
					or (EconomyBalance.GEAR and EconomyBalance.GEAR[itemUpdated])
				if isSeed then
					local foundItem = nil
					for _,v in player.Backpack:GetChildren() do
						if v:IsA("Tool") and v:GetAttribute("Name") == seedToolName then
							foundItem = v
						end
					end

					local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
					if tool and tool:GetAttribute("Name") == seedToolName then
						foundItem = tool
					end

					if foundItem then
						foundItem.Name = seedToolName.." (X"..tostring(foundItemInInventory.Count)..")"
						foundItem:SetAttribute("Count", foundItemInInventory.Count)
					else
						Service.createNewTool(player, itemUpdated)  -- ✅ pass base name
					end
				elseif isGear then
					local foundItem = nil
					for _,v in player.Backpack:GetChildren() do
						if v:IsA("Tool") and v:GetAttribute("Name") == seedToolName then
							foundItem = v
						end
					end

					local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
					if tool and tool:GetAttribute("Name") == seedToolName then
						foundItem = tool
					end

					if foundItem then
						foundItem.Name = seedToolName.." (X"..tostring(foundItemInInventory.Count)..")"
						foundItem:SetAttribute("Count", foundItemInInventory.Count)
					else
						Service.createNewTool(player, itemUpdated)  -- ✅ pass base name
					end
				else
					-- Handle fruits or non-seeds
					if not findFruitToolByKey(player, itemUpdated) then
						Service.createNewTool(player, itemUpdated)
					end
					
				end
				
			end
			
		end
	end
end

function Service.characterAdded(character: Model)
	if typeof(character) ~= "Instance" or not character:IsA("Model") then return end
	local player = players:GetPlayerFromCharacter(character)
	if not player then return end

	local dataService = cachedModules.Cache.DataService
	local playerData = dataService.getData(player)
	if not playerData then return end

	for itemName, _ in pairs(playerData.Inventory) do
		Service.createNewTool(player, itemName)
	end
end

function Service.init() end

return Service
