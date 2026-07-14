--[[
	Validate all pack crops are plantable.
	Paste into Studio Command Bar and press Enter.

	Prints SeedPrefix, plant assets, mesh stage count, and issues per crop.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SeedData = require(ReplicatedStorage.Modules.SeedData)
local plantsFolder = ReplicatedStorage.Assets.Plants
local cropSeeds = ServerStorage:FindFirstChild("CropSeeds")

local STAGES = { "_Seed", "_Stage1", "_Stage2", "_Stage3", "_Stage4", "" }

local function countStageMeshes(clientModel: Model, cropName: string): number
	local count = 0
	for _, suffix in ipairs(STAGES) do
		if clientModel:FindFirstChild("SM_" .. cropName .. suffix) then
			count += 1
		end
	end
	return count
end

local ok, bad = 0, 0

for _, seedName in ipairs(SeedData.getSeedOrder()) do
	local cropName = seedName:gsub(" Seed$", "")
	local seedFolder = SeedData.getData(seedName)
	local seedPrefix = seedFolder and seedFolder:FindFirstChild("SeedPrefix")
	local prefixValue = seedPrefix and seedPrefix.Value or "MISSING"

	local plantFolder = plantsFolder:FindFirstChild(cropName)
	local clientModel = plantFolder and plantFolder:FindFirstChild("ClientModel")
	local serverModel = plantFolder and plantFolder:FindFirstChild("ServerModel")
	local tool = cropSeeds and cropSeeds:FindFirstChild(seedName)

	local issues = {}
	if prefixValue ~= cropName then
		table.insert(issues, "SeedPrefix mismatch (" .. tostring(prefixValue) .. ")")
	end
	if not plantFolder then
		table.insert(issues, "missing Plants folder")
	end
	if not clientModel then
		table.insert(issues, "missing ClientModel")
	elseif countStageMeshes(clientModel, cropName) < 6 then
		table.insert(issues, "missing growth meshes (" .. countStageMeshes(clientModel, cropName) .. "/6)")
	end
	if not serverModel then
		table.insert(issues, "missing ServerModel")
	elseif not serverModel:FindFirstChild("HarvestAnchor") then
		table.insert(issues, "missing HarvestAnchor")
	end
	if not tool then
		table.insert(issues, "missing CropSeeds tool")
	end

	if #issues == 0 then
		ok += 1
		print("[ValidateCrops] OK", cropName, "prefix=" .. prefixValue)
	else
		bad += 1
		warn("[ValidateCrops] FAIL", cropName, table.concat(issues, "; "))
	end
end

print(string.format("[ValidateCrops] Done — %d ok, %d failed", ok, bad))
