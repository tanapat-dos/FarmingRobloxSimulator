--[[
	INSTALL SEED BAG VISUAL
	Paste into Studio Command Bar and press Enter.

	Replaces the legacy yellow lego Part on every ServerStorage.CropSeeds tool
	with the seed bag mesh (asset 16449117646).
]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage:WaitForChild("Modules")
local SeedToolVisual = require(modules:WaitForChild("SeedToolVisual"))

local cropSeeds = ServerStorage:WaitForChild("CropSeeds")
local updated = 0

for _, tool in cropSeeds:GetChildren() do
	if tool:IsA("Tool") then
		if SeedToolVisual.apply(tool) then
			updated += 1
			print("[InstallSeedBagVisual] Updated:", tool.Name)
		else
			warn("[InstallSeedBagVisual] Failed:", tool.Name)
		end
	end
end

print(string.format("[InstallSeedBagVisual] Done — %d seed tools updated.", updated))
