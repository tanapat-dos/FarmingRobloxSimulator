--[[
	CROP INTEGRATION SCRIPT
	Paste into Studio's Command Bar (View → Command Bar) and press Enter.

	What it does:
	  - Sets up all 15 FarmCrops pack plants under ReplicatedStorage/Assets/Plants
	  - ClientModel: 6 stage MeshParts with growth attributes
	  - ServerModel: invisible PrimaryPart + HarvestAnchor at crop height
	  - Creates SeedData for crops that don't have it yet
	  - Removes legacy lego crops (Blueberry, Cacao)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local plantsFolder = ReplicatedStorage.Assets.Plants
local seedDataModule = ReplicatedStorage.Modules.SeedData
local cropSeeds = ServerStorage:FindFirstChild("CropSeeds")
local seedModels = ReplicatedStorage:FindFirstChild("SeedModels")
local farmCropsSource = ServerStorage:FindFirstChild("FarmCropsSource")

local function findPackMesh(meshName: string): MeshPart?
	if farmCropsSource then
		local stored = farmCropsSource:FindFirstChild(meshName)
		if stored and stored:IsA("MeshPart") then
			return stored
		end
	end
	local inWorkspace = workspace:FindFirstChild(meshName)
	if inWorkspace and inWorkspace:IsA("MeshPart") then
		return inWorkspace
	end
	return nil
end

local function hideWorkspaceCropMeshes()
	if not farmCropsSource then
		farmCropsSource = Instance.new("Folder")
		farmCropsSource.Name = "FarmCropsSource"
		farmCropsSource.Parent = ServerStorage
	end
	local moved = 0
	for _, child in workspace:GetChildren() do
		if child:IsA("MeshPart") and child.Name:match("^SM_") then
			child.Anchored = true
			child.CanCollide = false
			child.Parent = farmCropsSource
			moved += 1
		end
	end
	if moved > 0 then
		print("[CropIntegrator] Moved", moved, "pack meshes to ServerStorage.FarmCropsSource")
	end
end

local CROPS = {
	"Wheat", "Tomato", "Beetroot", "Eggplant", "Potato",
	"Radish", "Corn", "Garlic", "Lettuce", "Pepper",
	"Pumpkin", "Carrot", "Grape", "Pineapple", "Strawberry",
}

local LEGACY_CROPS = { "Blueberry", "Cacao", "Bamboo", "Coconut", "Beanstalk" }

local STAGE_MAP = {
	{ suffix = "_Seed", appear = 0, hideAt = 20 },
	{ suffix = "_Stage1", appear = 20, hideAt = 40 },
	{ suffix = "_Stage2", appear = 40, hideAt = 60 },
	{ suffix = "_Stage3", appear = 60, hideAt = 80 },
	{ suffix = "_Stage4", appear = 80, hideAt = 100 },
	{ suffix = "", appear = 100, hideAt = nil },
}

local NEW_SEED_DATA = {
	Wheat = { price = 15, growthTime = 240, baseValue = 25, rarity = "Common" },
	Beetroot = { price = 20, growthTime = 300, baseValue = 35, rarity = "Common" },
	Potato = { price = 20, growthTime = 300, baseValue = 35, rarity = "Common" },
	Radish = { price = 15, growthTime = 200, baseValue = 28, rarity = "Common" },
	Corn = { price = 30, growthTime = 420, baseValue = 55, rarity = "Uncommon" },
	Garlic = { price = 25, growthTime = 360, baseValue = 45, rarity = "Uncommon" },
	Lettuce = { price = 20, growthTime = 280, baseValue = 38, rarity = "Common" },
	Pepper = { price = 35, growthTime = 480, baseValue = 65, rarity = "Uncommon" },
	Pumpkin = { price = 50, growthTime = 600, baseValue = 90, rarity = "Rare" },
	Grape = { price = 60, growthTime = 720, baseValue = 110, rarity = "Rare" },
	Pineapple = { price = 80, growthTime = 900, baseValue = 150, rarity = "Epic" },
}

local function addVal(parent, cls, name, val)
	local v = Instance.new(cls)
	v.Name = name
	v.Value = val
	v.Parent = parent
end

local function makePrimaryPart(parent)
	local p = Instance.new("Part")
	p.Name = "PrimaryPart"
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.CFrame = CFrame.new(0, 0, 0)
	p.Parent = parent
	return p
end

local function createHarvestAnchor(serverModel: Model, clientModel: Model, cropName: string)
	local old = serverModel:FindFirstChild("HarvestAnchor")
	if old then
		old:Destroy()
	end

	local anchor = Instance.new("Part")
	anchor.Name = "HarvestAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1

	local finalMesh = clientModel:FindFirstChild("SM_" .. cropName)
	if finalMesh and finalMesh:IsA("BasePart") then
		local anchorY = finalMesh.Position.Y + finalMesh.Size.Y * 0.35
		anchor.CFrame = CFrame.new(0, anchorY, 0)
	else
		local cf, size = clientModel:GetBoundingBox()
		anchor.CFrame = serverModel:GetPivot():ToObjectSpace(
			CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.35, 0))
		)
	end

	anchor.Parent = serverModel
end

local function createSeedDataFolder(cropName, cfg)
	local seedName = cropName .. " Seed"
	if seedDataModule:FindFirstChild(seedName) then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = seedName

	addVal(folder, "StringValue", "DisplayName", cropName)
	addVal(folder, "StringValue", "Name", cropName)
	addVal(folder, "StringValue", "Rarity", cfg.rarity)
	addVal(folder, "StringValue", "SeedPrefix", cropName)
	addVal(folder, "NumberValue", "Price", cfg.price)
	addVal(folder, "NumberValue", "GrowthTime", cfg.growthTime)
	addVal(folder, "NumberValue", "BaseValue", cfg.baseValue)
	addVal(folder, "IntValue", "HarvestCount", 1)
	addVal(folder, "BoolValue", "MultiHarvest", false)
	addVal(folder, "IntValue", "HarvestInterval", 0)
	addVal(folder, "NumberValue", "DevProduct", 0)
	addVal(folder, "NumberValue", "LayoutOrder", 0)

	folder.Parent = seedDataModule
	print("[CropIntegrator] Created SeedData: " .. seedName)
end

local function normalizeSeedData(cropName)
	local seedFolder = seedDataModule:FindFirstChild(cropName .. " Seed")
	if not seedFolder then
		return
	end

	local multi = seedFolder:FindFirstChild("MultiHarvest")
	if multi then
		multi.Value = false
	end

	local harvestCount = seedFolder:FindFirstChild("HarvestCount")
	if harvestCount then
		harvestCount.Value = math.max(1, harvestCount.Value)
	end

	local growthTime = seedFolder:FindFirstChild("GrowthTime")
	if growthTime then
		growthTime.Value = math.max(1, growthTime.Value)
	end

	local seedPrefix = seedFolder:FindFirstChild("SeedPrefix")
	if seedPrefix then
		seedPrefix.Value = cropName
	end
end

local function setupCrop(cropName)
	local plantFolder = plantsFolder:FindFirstChild(cropName)
	if not plantFolder then
		plantFolder = Instance.new("Folder")
		plantFolder.Name = cropName
		plantFolder.Parent = plantsFolder
	end

	local oldClient = plantFolder:FindFirstChild("ClientModel")
	if oldClient then
		oldClient:Destroy()
	end

	local clientModel = Instance.new("Model")
	clientModel.Name = "ClientModel"
	clientModel.PrimaryPart = makePrimaryPart(clientModel)

	for _, stage in ipairs(STAGE_MAP) do
		local meshName = "SM_" .. cropName .. stage.suffix
		local src = findPackMesh(meshName)

		if src then
			local part = src:Clone()
			part.CFrame = CFrame.new(0, part.Size.Y / 2, 0)
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = false
			part:SetAttribute("AppearPercentage", stage.appear)
			if stage.hideAt ~= nil then
				part:SetAttribute("HideAtPercentage", stage.hideAt)
			end
			part.Parent = clientModel
		else
			warn("[CropIntegrator] Missing mesh in Workspace: " .. meshName)
		end
	end

	clientModel.Parent = plantFolder

	local oldServer = plantFolder:FindFirstChild("ServerModel")
	if oldServer then
		oldServer:Destroy()
	end

	local serverModel = Instance.new("Model")
	serverModel.Name = "ServerModel"
	serverModel.PrimaryPart = makePrimaryPart(serverModel)
	createHarvestAnchor(serverModel, clientModel, cropName)
	serverModel.Parent = plantFolder

	normalizeSeedData(cropName)
	print("[CropIntegrator] Set up plant: " .. cropName)
end

local function removeLegacyCrop(cropName)
	local plantFolder = plantsFolder:FindFirstChild(cropName)
	if plantFolder then
		plantFolder:Destroy()
		print("[CropIntegrator] Removed legacy plant: " .. cropName)
	end

	local seedName = cropName .. " Seed"
	local seedFolder = seedDataModule:FindFirstChild(seedName)
	if seedFolder then
		seedFolder:Destroy()
		print("[CropIntegrator] Removed legacy SeedData: " .. seedName)
	end

	if cropSeeds then
		local tool = cropSeeds:FindFirstChild(seedName)
		if tool then
			tool:Destroy()
		end
	end

	if seedModels then
		local preview = seedModels:FindFirstChild(seedName) or seedModels:FindFirstChild(cropName)
		if preview then
			preview:Destroy()
		end
	end
end

for _, cropName in ipairs(LEGACY_CROPS) do
	removeLegacyCrop(cropName)
end

local ok = 0
for _, cropName in ipairs(CROPS) do
	local success, err = pcall(setupCrop, cropName)
	if success then
		ok += 1
	else
		warn("[CropIntegrator] Failed " .. cropName .. ": " .. tostring(err))
	end

	if NEW_SEED_DATA[cropName] then
		pcall(createSeedDataFolder, cropName, NEW_SEED_DATA[cropName])
	end
end

hideWorkspaceCropMeshes()

print(string.format("[CropIntegrator] Done — %d/%d pack crops integrated. Legacy crops removed.", ok, #CROPS))
