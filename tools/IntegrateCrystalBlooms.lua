--[[
	CRYSTAL BLOOMS CROP INTEGRATION (same flow as Bubble Rash)
	Paste into Studio Command Bar.

	Requires Workspace display models (run PrepareCrystalBloomsDisplay.lua first):
	  Crystal Blooms Sprout   → 0–34%
	  Crystal Blooms Growing  → 34–67%
	  Crystal Blooms Mature   → 67–100%
	  Crystal Blooms Harvest  → bag / sell tool

	Creates/updates ReplicatedStorage + ServerStorage crop assets only.
	Does not modify or delete Workspace display models.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CROP_NAME = "Crystal Blooms"
local SEED_NAME = CROP_NAME .. " Seed"

local DISPLAY = {
	sprout = "Crystal Blooms Sprout",
	growing = "Crystal Blooms Growing",
	mature = "Crystal Blooms Mature",
	harvest = "Crystal Blooms Harvest",
}

local STAGES = {
	{ meshTag = "SM_CrystalBlooms_Seed", appear = 0, hideAt = 34 },
	{ meshTag = "SM_CrystalBlooms_Stage1", appear = 34, hideAt = 67 },
	{ meshTag = "SM_CrystalBlooms", appear = 67, hideAt = nil },
}

local plantsFolder = ReplicatedStorage.Assets.Plants
local cropsFolder = ReplicatedStorage.Assets.Crops
local seedDataModule = ReplicatedStorage.Modules.SeedData
local cropSeeds = ServerStorage:WaitForChild("CropSeeds")
local seedModels = ReplicatedStorage:WaitForChild("SeedModels")

local EconomyBalance = require(ReplicatedStorage.Modules.EconomyBalance)
local cropCfg = EconomyBalance.CROPS[SEED_NAME]
if not cropCfg then
	error("[CrystalBlooms] Missing EconomyBalance.CROPS entry: " .. SEED_NAME .. " (sync Rojo first)")
end

local function requireDisplayModel(name: string): Model
	local model = workspace:FindFirstChild(name)
	if not model or not model:IsA("Model") then
		error("[CrystalBlooms] Missing Workspace model: " .. name .. " — run PrepareCrystalBloomsDisplay.lua")
	end
	return model
end

local function makePrimaryPart(parent: Model): Part
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

local function getModelGroundOffset(sourceModel: Model): Vector3
	local bbCF, bbSize = sourceModel:GetBoundingBox()
	local groundY = bbCF.Position.Y - bbSize.Y / 2
	return Vector3.new(bbCF.Position.X, groundY, bbCF.Position.Z)
end

local function addStageMeshes(clientModel: Model, sourceModel: Model, stage)
	local groundOffset = getModelGroundOffset(sourceModel)

	for _, mesh in sourceModel:GetDescendants() do
		if mesh:IsA("MeshPart") then
			local clone = mesh:Clone()
			clone.Name = stage.meshTag .. "_" .. mesh.Name
			clone.CFrame = mesh.CFrame - groundOffset
			clone.Anchored = true
			clone.CanCollide = false
			clone.CastShadow = false
			clone:SetAttribute("AppearPercentage", stage.appear)
			if stage.hideAt ~= nil then
				clone:SetAttribute("HideAtPercentage", stage.hideAt)
			end
			clone.Parent = clientModel
		end
	end
end

local function createHarvestAnchor(serverModel: Model, clientModel: Model)
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

	local _, size = clientModel:GetBoundingBox()
	anchor.CFrame = CFrame.new(0, size.Y * 0.35, 0)
	anchor.Parent = serverModel
end

local function setValue(folder: Instance, name: string, value: any)
	local child = folder:FindFirstChild(name)
	if not child then
		if typeof(value) == "number" then
			child = if math.floor(value) == value
				then Instance.new("IntValue")
				else Instance.new("NumberValue")
		elseif typeof(value) == "string" then
			child = Instance.new("StringValue")
		elseif typeof(value) == "boolean" then
			child = Instance.new("BoolValue")
		else
			return
		end
		child.Name = name
		child.Parent = folder
	end
	child.Value = value
end

local function createSeedData()
	local folder = seedDataModule:FindFirstChild(SEED_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = SEED_NAME
		folder.Parent = seedDataModule
	end

	setValue(folder, "DisplayName", CROP_NAME)
	setValue(folder, "Name", CROP_NAME)
	setValue(folder, "Rarity", cropCfg.rarity)
	setValue(folder, "SeedPrefix", CROP_NAME)
	setValue(folder, "Price", cropCfg.price)
	setValue(folder, "GrowthTime", cropCfg.growthTime)
	setValue(folder, "BaseValue", cropCfg.baseValue)
	setValue(folder, "HarvestCount", 1)
	setValue(folder, "MultiHarvest", false)
	setValue(folder, "HarvestInterval", 0)
	setValue(folder, "DevProduct", 0)
	setValue(folder, "LayoutOrder", 17)
end

local function appendSeedOrder()
	local seedDataScript = seedDataModule
	if not seedDataScript:IsA("ModuleScript") then
		return
	end
	local src = seedDataScript.Source
	if string.find(src, "Crystal Blooms Seed", 1, true) then
		return
	end
	local patched = src:gsub(
		'("Bubble Rash Seed",%s*\n%s*})',
		'("Bubble Rash Seed",\n\t\t"Crystal Blooms Seed",\n\t}'
	)
	if patched == src then
		warn("[CrystalBlooms] Add \"Crystal Blooms Seed\" to SeedData.seedOrder manually")
	else
		seedDataScript.Source = patched
		print("[CrystalBlooms] Added to SeedData.seedOrder")
	end
end

local function createSeedTool()
	if cropSeeds:FindFirstChild(SEED_NAME) then
		return
	end
	local template = cropSeeds:FindFirstChild("Bubble Rash Seed") or cropSeeds:FindFirstChild("Pineapple Seed")
	if not template then
		warn("[CrystalBlooms] No seed tool template")
		return
	end
	local tool = template:Clone()
	tool.Name = SEED_NAME
	tool.Parent = cropSeeds
end

local function createFruitToolFromModel(sourceModel: Model)
	local existing = cropsFolder:FindFirstChild(CROP_NAME)
	if existing then
		existing:Destroy()
	end

	local meshes: { MeshPart } = {}
	for _, inst in sourceModel:GetDescendants() do
		if inst:IsA("MeshPart") then
			table.insert(meshes, inst)
		end
	end
	if #meshes == 0 then
		warn("[CrystalBlooms] No meshes on harvest model")
		return
	end

	local temp = Instance.new("Model")
	for _, mesh in meshes do
		mesh:Clone().Parent = temp
	end
	local center = temp:GetBoundingBox().Position
	temp:Destroy()

	local tool = Instance.new("Tool")
	tool.Name = CROP_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = true

	local handle = meshes[1]:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = handle.CFrame - center
	handle.Parent = tool

	for index = 2, #meshes do
		local clone = meshes[index]:Clone()
		clone.Anchored = false
		clone.CanCollide = false
		clone.Massless = true
		clone.CFrame = clone.CFrame - center
		clone.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = clone
		weld.Parent = handle
	end

	tool.Grip = CFrame.new(0, -handle.Size.Y * 0.15, 0) * CFrame.Angles(math.rad(90), 0, 0)
	tool.Parent = cropsFolder
end

local function createSeedPreview(sourceModel: Model)
	local existing = seedModels:FindFirstChild(SEED_NAME)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = SEED_NAME
	model.PrimaryPart = makePrimaryPart(model)

	local groundOffset = getModelGroundOffset(sourceModel)

	for _, mesh in sourceModel:GetDescendants() do
		if mesh:IsA("MeshPart") then
			local clone = mesh:Clone()
			clone.Anchored = true
			clone.CanCollide = false
			clone.CFrame = mesh.CFrame - groundOffset
			clone.Parent = model
		end
	end

	if #model:GetChildren() <= 1 then
		model:Destroy()
		return
	end

	model.Parent = seedModels
end

local sproutModel = requireDisplayModel(DISPLAY.sprout)
local growingModel = requireDisplayModel(DISPLAY.growing)
local matureModel = requireDisplayModel(DISPLAY.mature)
local harvestModel = requireDisplayModel(DISPLAY.harvest)

local plantFolder = plantsFolder:FindFirstChild(CROP_NAME)
if not plantFolder then
	plantFolder = Instance.new("Folder")
	plantFolder.Name = CROP_NAME
	plantFolder.Parent = plantsFolder
end

local oldClient = plantFolder:FindFirstChild("ClientModel")
if oldClient then
	oldClient:Destroy()
end

local clientModel = Instance.new("Model")
clientModel.Name = "ClientModel"
clientModel.PrimaryPart = makePrimaryPart(clientModel)

addStageMeshes(clientModel, sproutModel, STAGES[1])
addStageMeshes(clientModel, growingModel, STAGES[2])
addStageMeshes(clientModel, matureModel, STAGES[3])
clientModel.Parent = plantFolder

local oldServer = plantFolder:FindFirstChild("ServerModel")
if oldServer then
	oldServer:Destroy()
end

local serverModel = Instance.new("Model")
serverModel.Name = "ServerModel"
serverModel.PrimaryPart = makePrimaryPart(serverModel)
createHarvestAnchor(serverModel, clientModel)
serverModel.Parent = plantFolder

createSeedData()
appendSeedOrder()
createSeedTool()
createFruitToolFromModel(harvestModel)
createSeedPreview(harvestModel)

print("[CrystalBlooms] Single-harvest crop wired (Bubble Rash style):")
print("  0–34%  ", DISPLAY.sprout)
print("  34–67% ", DISPLAY.growing)
print("  67–100%", DISPLAY.mature)
print("  harvest ", DISPLAY.harvest)
print("  Seed $", cropCfg.price, "grow", cropCfg.growthTime, "s base $", cropCfg.baseValue)
print("[CrystalBlooms] Stop → Play → Ctrl+S. Sync EconomyBalance via Rojo if needed.")
