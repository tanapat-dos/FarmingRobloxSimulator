--[[
	BUBBLE RASH CROP INTEGRATION
	Paste into Studio Command Bar and press Enter.

	Requires these Workspace display models (from RestoreBubbleRashDisplay.lua):
	  Bubble Rash Sprout       → middle growth stage (34–67%)
	  Bubble Rash Early Growth → fully grown plant (67–100%)
	  Bubble Rash Harvest      → harvested fruit tool / shop preview

	Initial planted sprout uses mesh rbxassetid://109082262496036.

	Creates/updates:
	  ReplicatedStorage.Assets.Plants["Bubble Rash"]
	  ReplicatedStorage.Assets.Crops["Bubble Rash"]
	  ReplicatedStorage.Modules.SeedData["Bubble Rash Seed"]
	  ServerStorage.CropSeeds["Bubble Rash Seed"]
	  ReplicatedStorage.SeedModels["Bubble Rash Seed"]
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CROP_NAME = "Bubble Rash"
local SEED_NAME = CROP_NAME .. " Seed"
local SPROUT_MESH_ID = "rbxassetid://109082262496036"

local DISPLAY = {
	middle = "Bubble Rash Sprout",
	mature = "Bubble Rash Early Growth",
	harvest = "Bubble Rash Harvest",
}

local STAGES = {
	{ meshTag = "SM_BubbleRash_Seed", appear = 0, hideAt = 34 },
	{ meshTag = "SM_BubbleRash_Stage1", appear = 34, hideAt = 67 },
	{ meshTag = "SM_BubbleRash", appear = 67, hideAt = nil },
}

local plantsFolder = ReplicatedStorage.Assets.Plants
local cropsFolder = ReplicatedStorage.Assets.Crops
local seedDataModule = ReplicatedStorage.Modules.SeedData
local cropSeeds = ServerStorage:WaitForChild("CropSeeds")
local seedModels = ReplicatedStorage:WaitForChild("SeedModels")

local EconomyBalance = require(ReplicatedStorage.Modules.EconomyBalance)
local cropCfg = EconomyBalance.CROPS[SEED_NAME]
if not cropCfg then
	error("[BubbleRash] Missing EconomyBalance.CROPS entry: " .. SEED_NAME)
end

local function requireDisplayModel(name: string): Model
	local model = workspace:FindFirstChild(name)
	if not model or not model:IsA("Model") then
		error("[BubbleRash] Missing Workspace model: " .. name)
	end
	return model
end

local function findSproutReference(): MeshPart?
	local ref = workspace:FindFirstChild("Meshes/bubble_Cube.013")
	if ref and ref:IsA("MeshPart") and ref.MeshId == SPROUT_MESH_ID then
		return ref
	end

	for _, inst in workspace:GetDescendants() do
		if inst:IsA("MeshPart") and inst.MeshId == SPROUT_MESH_ID then
			return inst
		end
	end

	return nil
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

local function addInitialSprout(clientModel: Model, stage)
	local ref = findSproutReference()
	if not ref then
		error("[BubbleRash] Missing sprout reference mesh: " .. SPROUT_MESH_ID)
	end

	local mesh = ref:Clone()
	mesh.Name = stage.meshTag
	local bottomY = ref.Position.Y - ref.Size.Y / 2
	mesh.CFrame = ref.CFrame - Vector3.new(ref.Position.X, bottomY, ref.Position.Z)
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CastShadow = false
	mesh:SetAttribute("AppearPercentage", stage.appear)
	mesh:SetAttribute("HideAtPercentage", stage.hideAt)
	mesh.Parent = clientModel
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
			-- Bottom of the source model sits at Y=0 in plant-local space.
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

	local cf, size = clientModel:GetBoundingBox()
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
	setValue(folder, "LayoutOrder", 16)
end

local function createSeedTool()
	if cropSeeds:FindFirstChild(SEED_NAME) then
		return
	end
	local template = cropSeeds:FindFirstChild("Pineapple Seed") or cropSeeds:FindFirstChild("Carrot Seed")
	if not template then
		warn("[BubbleRash] No seed tool template found")
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
		warn("[BubbleRash] No meshes on harvest model for fruit tool")
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
	print("[BubbleRash] Created harvest fruit tool from", sourceModel.Name)
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

local middleModel = requireDisplayModel(DISPLAY.middle)
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

addInitialSprout(clientModel, STAGES[1])
addStageMeshes(clientModel, middleModel, STAGES[2])
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
createSeedTool()
createFruitToolFromModel(harvestModel)
createSeedPreview(harvestModel)

print("[BubbleRash] Wired stages:")
print("  0–34%  sprout mesh", SPROUT_MESH_ID)
print("  34–67% ", DISPLAY.middle)
print("  67–100%", DISPLAY.mature)
print("  harvest ", DISPLAY.harvest)
