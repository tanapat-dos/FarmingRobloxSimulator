--[[
	Quick fix: copy Crystal Blooms + Mango grow times from EconomyBalance into SeedData.
	Paste in Command Bar (Edit mode). Save place after.

	Use full RebalanceEconomy.lua to update all crops.
]]
local RS = game:GetService("ReplicatedStorage")
local seedDataRoot = RS.Modules.SeedData

local function requireFresh(moduleScript: ModuleScript)
	local clone = moduleScript:Clone()
	clone.Name = moduleScript.Name .. "_Fresh"
	clone.Parent = moduleScript.Parent
	local result = require(clone)
	clone:Destroy()
	return result
end

local EconomyBalance = requireFresh(RS.Modules.EconomyBalance)

local TEST_SEEDS = { "Crystal Blooms Seed", "Mango Seed" }

local function setInt(folder: Instance, name: string, value: number)
	local child = folder:FindFirstChild(name)
	if not child then
		child = Instance.new("IntValue")
		child.Name = name
		child.Parent = folder
	end
	child.Value = value
end

for _, seedName in TEST_SEEDS do
	local cfg = EconomyBalance.CROPS[seedName]
	local folder = seedDataRoot:FindFirstChild(seedName)
	if not cfg or not folder then
		warn("[SyncTestCropTimes] Missing", seedName, cfg, folder)
		continue
	end
	setInt(folder, "GrowthTime", cfg.growthTime)
	if cfg.harvestInterval then
		setInt(folder, "HarvestInterval", cfg.harvestInterval)
	end
	print(string.format("[SyncTestCropTimes] %s GrowthTime=%ds", seedName, cfg.growthTime))
end

print("[SyncTestCropTimes] Done — save place. New plants use 10s; replant old crops.")
