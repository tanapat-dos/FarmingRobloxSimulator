-- Keeps harvested fruit hotbar labels readable (two-line name + tooltip).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage:WaitForChild("Modules")
local fruitDisplayName = require(modules.FruitDisplayName)
local harvestRarityEffects = require(modules.HarvestRarityEffects)
local fruitNameParser = require(modules.FruitNameParse)

local player = Players.LocalPlayer

local function applyFruitLabels(tool: Tool)
	if not tool:IsA("Tool") or tool:GetAttribute("isFruit") ~= true then
		return
	end

	local displayString = tool:GetAttribute("DisplayName")
	if typeof(displayString) ~= "string" or displayString == "" then
		return
	end

	tool.Name = fruitDisplayName.getHotbarName(displayString)
	tool.ToolTip = fruitDisplayName.getToolTip(displayString)

	local rarity = tool:GetAttribute("HarvestRarity")
	if typeof(rarity) ~= "string" or rarity == "" then
		rarity = select(1, fruitNameParser(displayString))
	end
	harvestRarityEffects.applyToTool(tool, rarity)
end

local function watchContainer(container: Instance)
	for _, child in container:GetChildren() do
		applyFruitLabels(child)
	end
	container.ChildAdded:Connect(applyFruitLabels)
end

local function onCharacter(character: Model)
	watchContainer(character)
	character.ChildAdded:Connect(function(child)
		applyFruitLabels(child)
	end)
end

player:WaitForChild("Backpack")
watchContainer(player.Backpack)

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
