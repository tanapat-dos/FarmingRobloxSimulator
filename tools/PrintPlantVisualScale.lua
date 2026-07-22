--[[
	Command bar: print mature mesh height + normalize factor per crop (tuning PLANT_DISPLAY).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ReplicatedStorage:WaitForChild("Modules")
local PlantVisualScale = require(modules.PlantVisualScale)
local EconomyBalance = require(modules.EconomyBalance)

PlantVisualScale.clearCache()

local target = EconomyBalance.PLANT_DISPLAY and EconomyBalance.PLANT_DISPLAY.targetMatureHeightStuds or 5.5
print("[PrintPlantVisualScale] targetMatureHeightStuds =", target)

local plants = ReplicatedStorage.Assets.Plants
for _, folder in plants:GetChildren() do
	if folder:IsA("Folder") then
		local factor = PlantVisualScale.getHeightNormalizeFactor(folder.Name)
		local world = PlantVisualScale.getWorldScale(folder.Name, 1)
		print(string.format("  %s  factor=%.3f  worldScale@1=%.3f", folder.Name, factor, world))
	end
end

print("[PrintPlantVisualScale] Done. Adjust EconomyBalance.PLANT_DISPLAY.targetMatureHeightStuds in Rojo.")
