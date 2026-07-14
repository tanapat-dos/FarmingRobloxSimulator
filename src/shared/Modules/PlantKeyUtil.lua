local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlantKeyUtil = {}

local plantsFolder: Folder? = nil
local seedDataFolder: Folder? = nil

local function getPlantsFolder(): Folder
	if not plantsFolder then
		plantsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Plants") :: Folder
	end
	return plantsFolder
end

local function getSeedDataFolder(): Folder
	if not seedDataFolder then
		seedDataFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SeedData") :: Folder
	end
	return seedDataFolder
end

function PlantKeyUtil.getPrefix(plantKey: string): string
	return plantKey:split(":")[1]
end

function PlantKeyUtil.resolveCropName(plantKeyOrPrefix: string): string
	local prefix = PlantKeyUtil.getPrefix(plantKeyOrPrefix)
	if prefix:match(" Seed$") then
		prefix = prefix:gsub(" Seed$", "")
	end

	local plants = getPlantsFolder()

	local direct = plants:FindFirstChild(prefix)
	if direct then
		return direct.Name
	end

	for _, crop in plants:GetChildren() do
		if crop:IsA("Folder") and crop.Name:lower() == prefix:lower() then
			return crop.Name
		end
	end

	for _, seedFolder in getSeedDataFolder():GetChildren() do
		if seedFolder:IsA("Folder") then
			local seedPrefix = seedFolder:FindFirstChild("SeedPrefix")
			if seedPrefix and seedPrefix:IsA("StringValue") and seedPrefix.Value:lower() == prefix:lower() then
				return seedFolder.Name:gsub(" Seed$", "")
			end
		end
	end

	return prefix
end

function PlantKeyUtil.resolvePlantFolder(plantKeyOrPrefix: string): Folder?
	local cropName = PlantKeyUtil.resolveCropName(plantKeyOrPrefix)
	return getPlantsFolder():FindFirstChild(cropName)
end

function PlantKeyUtil.getSeedName(plantKeyOrPrefix: string): string
	return PlantKeyUtil.resolveCropName(plantKeyOrPrefix) .. " Seed"
end

return PlantKeyUtil
