--[[
	MANGO — perennial crop (tree + 4 harvestable fruits)
	Paste the ENTIRE file into Studio Command Bar after PrepareMangoDisplay.lua.
	Stop Play mode first (Shift+F5). If economy errors persist, run tools/VerifyEconomyMango.lua.

	Workspace display (unchanged by this script):
	  Mango Sprout / Mango Growing / Mango Mature / Mango Harvest

	Mango Mature must contain 1 tree + 4 fruit child Models.

	Updates ReplicatedStorage + ServerStorage only (safe for Workspace art).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local CROP_NAME = "Mango"
local SEED_NAME = CROP_NAME .. " Seed"

local DISPLAY = {
	sprout = "Mango Sprout",
	growing = "Mango Growing",
	mature = "Mango Mature",
	harvest = "Mango Harvest",
}

local STAGES = {
	{ meshTag = "SM_Mango_Seed", appear = 0, hideAt = 34 },
	{ meshTag = "SM_Mango_Stage1", appear = 34, hideAt = 67 },
	{ meshTag = "SM_Mango", appear = 67, hideAt = nil },
}

local plantsFolder = ReplicatedStorage.Assets.Plants
local cropsFolder = ReplicatedStorage.Assets.Crops
local seedDataModule = ReplicatedStorage.Modules.SeedData
local cropSeeds = ServerStorage:WaitForChild("CropSeeds")
local seedModels = ReplicatedStorage:WaitForChild("SeedModels")

if RunService:IsRunning() then
	error("[Mango] Stop Play mode first (Shift+F5). Integrate must run in Edit mode with the current EconomyBalance.")
end

-- Studio caches require() on the ModuleScript instance; after editing EconomyBalance, the cache can lag.
local function requireEconomyBalanceFresh()
	local moduleScript = ReplicatedStorage.Modules.EconomyBalance
	local cached = require(moduleScript)
	if cached.CROPS and cached.CROPS[SEED_NAME] then
		return cached
	end
	local clone = moduleScript:Clone()
	clone.Name = "EconomyBalance_IntegrateFresh"
	clone.Parent = moduleScript.Parent
	local ok, fresh = pcall(require, clone)
	clone:Destroy()
	if ok and fresh.CROPS and fresh.CROPS[SEED_NAME] then
		return fresh
	end
	local lastCrop = "?"
	for seedName in cached.CROPS or {} do
		lastCrop = seedName
	end
	error(
		"[Mango] Missing EconomyBalance.CROPS["
			.. SEED_NAME
			.. "]. Open ReplicatedStorage.Modules.EconomyBalance — confirm Mango Seed exists, sync Rojo, save place. Cached module last crop: "
			.. lastCrop
	)
end

local EconomyBalance = requireEconomyBalanceFresh()
local cropCfg = EconomyBalance.CROPS[SEED_NAME]

local maxFruits = cropCfg.harvestCount or 4

type FruitEntry = {
	index: number,
	cframe: CFrame,
	fruitModel: Model?,
}

local function requireDisplayModel(name: string): Model
	local model = workspace:FindFirstChild(name)
	if not model or not model:IsA("Model") then
		error("[Mango] Missing Workspace model: " .. name .. " — run PrepareMangoDisplay.lua")
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

-- Mature display: tree only in the growth stage. Fruits come from fruit_1..N when harvestable (no duplicate).
local function shouldExcludeMatureStageMesh(
	mesh: MeshPart,
	fruitEntries: { FruitEntry },
	harvestIds: { [string]: boolean }
): boolean
	for _, entry in fruitEntries do
		if entry.fruitModel and mesh:IsDescendantOf(entry.fruitModel) then
			return true
		end
	end
	if harvestIds[mesh.MeshId] then
		return true
	end
	return false
end

local function addMatureTreeStageMeshes(
	clientModel: Model,
	matureModel: Model,
	stage,
	fruitEntries: { FruitEntry },
	harvestModel: Model
)
	local groundOffset = getModelGroundOffset(matureModel)
	local harvestIds = harvestMeshIdSet(harvestModel)
	for _, mesh in matureModel:GetDescendants() do
		if mesh:IsA("MeshPart") and not shouldExcludeMatureStageMesh(mesh, fruitEntries, harvestIds) then
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
			clone:SetAttribute("MangoTreeStage", true)
			clone.Parent = clientModel
		end
	end
end

local function harvestMeshIdSet(harvestModel: Model): { [string]: boolean }
	local set = {}
	for _, inst in harvestModel:GetDescendants() do
		if inst:IsA("MeshPart") and inst.MeshId ~= "" then
			set[inst.MeshId] = true
		end
	end
	return set
end

local function modelLooksLikeFruit(model: Model, harvestIds: { [string]: boolean }): boolean
	for _, desc in model:GetDescendants() do
		if desc:IsA("MeshPart") and harvestIds[desc.MeshId] then
			return true
		end
	end
	return false
end

local function boundingSize(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Magnitude
end

local function findFruitSubmodels(matureRoot: Model, harvestModel: Model): { Model }
	local childModels: { Model } = {}
	for _, child in matureRoot:GetChildren() do
		if child:IsA("Model") then
			table.insert(childModels, child)
		end
	end
	if #childModels == 0 then
		return {}
	end

	local harvestIds = harvestMeshIdSet(harvestModel)
	local fruits: { Model } = {}
	local trees: { Model } = {}

	for _, m in childModels do
		if modelLooksLikeFruit(m, harvestIds) then
			table.insert(fruits, m)
		else
			table.insert(trees, m)
		end
	end

	if #fruits >= 1 then
		table.sort(fruits, function(a, b)
			return a:GetPivot().Position.Y < b:GetPivot().Position.Y
		end)
		return fruits
	end

	-- 5 children: largest = tree, other four = mangoes
	if #childModels >= 5 then
		table.sort(childModels, function(a, b)
			return boundingSize(a) > boundingSize(b)
		end)
		local out = {}
		for i = 2, math.min(5, #childModels) do
			table.insert(out, childModels[i])
		end
		table.sort(out, function(a, b)
			return a:GetPivot().Position.Y < b:GetPivot().Position.Y
		end)
		return out
	end

	-- Exactly 4 child models (no separate tree model — tree meshes on root)
	if #childModels == 4 then
		table.sort(childModels, function(a, b)
			return a:GetPivot().Position.X < b:GetPivot().Position.X
		end)
		return childModels
	end

	return {}
end

local function collectFruitEntries(matureModel: Model, groundOffset: Vector3, harvestModel: Model): { FruitEntry }
	local fruitModels = findFruitSubmodels(matureModel, harvestModel)
	local entries: { FruitEntry } = {}

	for i, fruitModel in fruitModels do
		if i > maxFruits then
			break
		end
		table.insert(entries, {
			index = i,
			cframe = fruitModel:GetPivot() - groundOffset,
			fruitModel = fruitModel,
		})
	end

	if #entries == 0 then
		warn("[Mango] No fruit child Models on Mango Mature — using default prompt heights")
		for i = 1, maxFruits do
			table.insert(entries, {
				index = i,
				cframe = CFrame.new(0, 2 + i * 0.4, 0),
				fruitModel = nil,
			})
		end
	else
		print("[Mango] Using", #entries, "fruit sub-Models on", matureModel.Name)
	end

	for i, e in entries do
		e.index = i
	end
	return entries
end

local function buildFruitTemplate(index: number, harvestModel: Model, fruitSubmodel: Model?): Model
	local fruitModel = Instance.new("Model")
	fruitModel.Name = "fruit_" .. tostring(index)

	local meshes: { MeshPart } = {}
	if fruitSubmodel then
		for _, inst in fruitSubmodel:GetDescendants() do
			if inst:IsA("MeshPart") then
				table.insert(meshes, inst)
			end
		end
	end
	if #meshes == 0 then
		for _, inst in harvestModel:GetDescendants() do
			if inst:IsA("MeshPart") then
				table.insert(meshes, inst)
			end
		end
	end
	if #meshes == 0 then
		error("[Mango] No meshes for fruit_" .. index)
	end

	local temp = Instance.new("Model")
	for _, m in meshes do
		m:Clone().Parent = temp
	end
	local center = temp:GetBoundingBox().Position
	temp:Destroy()

	local primary = meshes[1]:Clone()
	primary.Name = "PrimaryPart"
	primary.Anchored = true
	primary.CanCollide = false
	primary.CFrame = CFrame.new(primary.CFrame.Position - center)
	primary.Parent = fruitModel
	fruitModel.PrimaryPart = primary

	for i = 2, #meshes do
		local clone = meshes[i]:Clone()
		clone.Anchored = true
		clone.CanCollide = false
		clone.CFrame = CFrame.new(clone.CFrame.Position - center)
		clone.Parent = fruitModel
	end

	return fruitModel
end

local function createFruitPrompts(serverModel: Model, entries: { FruitEntry })
	local old = serverModel:FindFirstChild("FruitPrompts")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "FruitPrompts"
	folder.Parent = serverModel
	for _, entry in entries do
		local part = Instance.new("Part")
		part.Name = tostring(entry.index)
		part.Size = Vector3.new(0.6, 0.6, 0.6)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.CFrame = entry.cframe
		part.Parent = folder
	end
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
	setValue(folder, "HarvestCount", maxFruits)
	setValue(folder, "MultiHarvest", true)
	setValue(folder, "HarvestInterval", cropCfg.harvestInterval or 600)
	setValue(folder, "DevProduct", 0)
	setValue(folder, "LayoutOrder", 18)
end

local function appendSeedOrder()
	if not seedDataModule:IsA("ModuleScript") then
		return
	end
	local src = seedDataModule.Source
	if string.find(src, "Mango Seed", 1, true) then
		return
	end
	local patched = src:gsub(
		'("Crystal Blooms Seed",%s*\n%s*})',
		'("Crystal Blooms Seed",\n\t\t"Mango Seed",\n\t}'
	)
	if patched ~= src then
		seedDataModule.Source = patched
		print("[Mango] Added Mango Seed to seedOrder")
	else
		warn("[Mango] Add Mango Seed to SeedData.seedOrder manually")
	end
end

local function createSeedTool()
	if cropSeeds:FindFirstChild(SEED_NAME) then
		return
	end
	local template = cropSeeds:FindFirstChild("Crystal Blooms Seed") or cropSeeds:FindFirstChild("Bubble Rash Seed")
	if not template then
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
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Parent = tool

	for index = 2, #meshes do
		local clone = meshes[index]:Clone()
		clone.Anchored = false
		clone.CanCollide = false
		clone.Massless = true
		clone.CFrame = CFrame.new((meshes[index].CFrame.Position - center))
		clone.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = clone
		weld.Parent = handle
	end

	-- InventoryService overrides GripPos for MultiHarvest; keep a neutral base grip.
	tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0)
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
	if #model:GetChildren() > 1 then
		model.Parent = seedModels
	end
end

local sproutModel = requireDisplayModel(DISPLAY.sprout)
local growingModel = requireDisplayModel(DISPLAY.growing)
local matureModel = requireDisplayModel(DISPLAY.mature)
local harvestModel = requireDisplayModel(DISPLAY.harvest)

local matureGround = getModelGroundOffset(matureModel)
local fruitEntries = collectFruitEntries(matureModel, matureGround, harvestModel)

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
addMatureTreeStageMeshes(clientModel, matureModel, STAGES[3], fruitEntries, harvestModel)

for _, entry in fruitEntries do
	buildFruitTemplate(entry.index, harvestModel, entry.fruitModel).Parent = clientModel
end
clientModel.Parent = plantFolder

local oldServer = plantFolder:FindFirstChild("ServerModel")
if oldServer then
	oldServer:Destroy()
end

local serverModel = Instance.new("Model")
serverModel.Name = "ServerModel"
serverModel.PrimaryPart = makePrimaryPart(serverModel)
createFruitPrompts(serverModel, fruitEntries)
serverModel.Parent = plantFolder

createSeedData()
appendSeedOrder()
createSeedTool()
createFruitToolFromModel(harvestModel)
createSeedPreview(harvestModel)

print("[Mango] Perennial wired — tree stays, harvest", maxFruits, "fruits, regrow", cropCfg.harvestInterval or 600, "s")
print("[Mango] Stop → Play → Ctrl+S")
