--[[
	GENERIC CROP INTEGRATION (from Studio selection)
	Paste into the Studio Command Bar.

	>>> READ tools/CROP_INTEGRATION.md FIRST — it documents the workflow and every gotcha
	    (edit-mode-only, save-before-play, no MeshId dedup, shop-visibility requirements,
	    stale require cache, single Studio window, MCP read lag). <<<

	Replaces the per-crop Integrate<Crop>.lua scripts. Wires ANY new crop from four display
	models laid out in a row in the Workspace.

	USAGE
	  1. Place the four stage models in Workspace, left to right:
	         seed/sprout  ->  growing  ->  mature  ->  harvest
	     They can be named anything; position is what matters.
	  2. Select all four (Ctrl+click each, or drag-select).
	  3. Set CROP_NAME below to the crop's display name (no " Seed" suffix).
	  4. Ensure EconomyBalance.CROPS["<CROP_NAME> Seed"] exists (price/baseValue/growthTime/
	     rarity). Run tools/VerifyEconomyMath.lua first to confirm the numbers are balanced.
	  5. Run this script. It prints the detected left-to-right order — CHECK IT before trusting
	     the result. Set DRY_RUN = true to preview the ordering without changing anything.

	Ordering is resolved by world X position, not click order: Selection:Get() does not
	preserve the order you clicked in.

	Creates / updates (never touches Workspace display models):
	    ReplicatedStorage.Assets.Plants.<Crop>.ClientModel   3 growth stages
	    ReplicatedStorage.Assets.Plants.<Crop>.ServerModel   + HarvestAnchor
	    ReplicatedStorage.Modules.SeedData.<Crop> Seed       value folder
	    ReplicatedStorage.Modules.SeedData  seedOrder patch
	    ReplicatedStorage.Assets.Crops.<Crop>               harvested fruit Tool
	    ReplicatedStorage.SeedModels.<Crop> Seed            shop preview model
	    ServerStorage.CropSeeds.<Crop> Seed                 seed Tool
--]]

--=============================== CONFIGURE ===============================
local CROP_NAME = "Pineapple" -- display name, no " Seed" suffix
local DRY_RUN = true -- true = report the detected stage order and change nothing
--=========================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Selection = game:GetService("Selection")

local SEED_NAME = CROP_NAME .. " Seed"

-- Growth-percentage windows for the three visual stages.
local STAGE_WINDOWS = {
	{ appear = 0, hideAt = 34 },
	{ appear = 34, hideAt = 67 },
	{ appear = 67, hideAt = nil },
}

if CROP_NAME == "REPLACE_ME" or CROP_NAME == "" then
	error("[IntegrateCrop] Set CROP_NAME at the top of the script first.")
end

-- ------------------------------------------------------------------ selection
local selected = Selection:Get()
local models: { Model } = {}
for _, inst in selected do
	if inst:IsA("Model") then
		table.insert(models, inst)
	end
end

if #models ~= 4 then
	error(("[IntegrateCrop] Select exactly 4 Models (seed, growing, mature, harvest). Found %d Model(s) in a selection of %d."):format(
		#models, #selected))
end

-- Left-to-right by world X. Uses the bounding box centre so oddly-pivoted models still sort
-- correctly (a Model's WorldPivot can sit far from its visible geometry).
local function centreX(model: Model): number
	local ok, cf = pcall(function()
		return (model:GetBoundingBox())
	end)
	if ok and cf then
		return cf.Position.X
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part then part.Position.X else 0
end

table.sort(models, function(a, b)
	return centreX(a) < centreX(b)
end)

local STAGE_LABELS = { "seed/sprout", "growing", "mature", "harvest" }
print("=== Detected left-to-right order ===")
for index, model in models do
	local _, size = model:GetBoundingBox()
	print(("  %d. %-10s %-28s x=%.1f  meshes=%d  height=%.1f"):format(
		index,
		STAGE_LABELS[index],
		model.Name,
		centreX(model),
		(function()
			local n = 0
			for _, d in model:GetDescendants() do
				if d:IsA("MeshPart") then
					n += 1
				end
			end
			return n
		end)(),
		size.Y))
end

local sproutModel, growingModel, matureModel, harvestModel = models[1], models[2], models[3], models[4]

-- Every stage must contain MeshParts: PlantStageIntegrate clones MeshPart descendants only,
-- so Parts / unions / MeshParts-inside-Unions produce an empty plant.
for index, model in models do
	local hasMesh = false
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			hasMesh = true
			break
		end
	end
	if not hasMesh then
		error(("[IntegrateCrop] '%s' (stage %d, %s) contains no MeshPart. Only MeshParts are cloned — convert Parts/Unions to MeshParts first."):format(
			model.Name, index, STAGE_LABELS[index]))
	end
end

if DRY_RUN then
	print("[IntegrateCrop] DRY_RUN — nothing changed. Set DRY_RUN = false to wire this crop.")
	return
end

-- ------------------------------------------------------------------ prerequisites
--[[
	Studio caches required ModuleScripts for the whole Edit session, keyed by instance. If
	anything already required EconomyBalance earlier (e.g. MigrateSeedDataEconomy.lua), a plain
	require() here returns that STALE table and a freshly Rojo-synced crop looks missing.

	Requiring a throwaway clone sidesteps the cache: different instance, fresh evaluation.
]]
local function requireFresh(module: ModuleScript)
	local clone = module:Clone()
	clone.Parent = module.Parent
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if not ok then
		error("[IntegrateCrop] Failed to load " .. module.Name .. ": " .. tostring(result))
	end
	return result
end

local EconomyBalance = requireFresh(ReplicatedStorage.Modules.EconomyBalance)
local cropCfg = EconomyBalance.CROPS[SEED_NAME]
if not cropCfg then
	local available = {}
	for seedName in EconomyBalance.CROPS do
		table.insert(available, seedName)
	end
	table.sort(available)
	error(("[IntegrateCrop] Missing EconomyBalance.CROPS[\"%s\"].\n  Loaded %d crops: %s\n  If yours is absent, sync Rojo. If it IS listed, this is a stale-cache bug — report it."):format(
		SEED_NAME, #available, table.concat(available, ", ")))
end

local modStageIntegrate = ReplicatedStorage.Modules:FindFirstChild("PlantStageIntegrate")
if not (modStageIntegrate and modStageIntegrate:IsA("ModuleScript")) then
	error("[IntegrateCrop] ReplicatedStorage.Modules.PlantStageIntegrate missing — sync Rojo.")
end
-- requireFresh (not plain require): if PlantStageIntegrate was Rojo-synced mid-session,
-- a plain require() returns Studio's STALE cached table (missing addStageMeshesFull -> nil call).
local PlantStageIntegrate = requireFresh(modStageIntegrate)

local plantsFolder = ReplicatedStorage.Assets.Plants
local cropsFolder = ReplicatedStorage.Assets.Crops
local seedDataModule = ReplicatedStorage.Modules.SeedData
local cropSeeds = ServerStorage:WaitForChild("CropSeeds")
local seedModels = ReplicatedStorage:WaitForChild("SeedModels")

-- A stable mesh-tag prefix, e.g. "Crystal Blooms" -> "SM_CrystalBlooms"
local tagBase = "SM_" .. (CROP_NAME:gsub("%s+", ""))
local STAGES = {
	{ meshTag = tagBase .. "_Seed", appear = STAGE_WINDOWS[1].appear, hideAt = STAGE_WINDOWS[1].hideAt },
	{ meshTag = tagBase .. "_Stage1", appear = STAGE_WINDOWS[2].appear, hideAt = STAGE_WINDOWS[2].hideAt },
	{ meshTag = tagBase, appear = STAGE_WINDOWS[3].appear, hideAt = STAGE_WINDOWS[3].hideAt },
}

-- ------------------------------------------------------------------ helpers
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
			child = if math.floor(value) == value then Instance.new("IntValue") else Instance.new("NumberValue")
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

-- ------------------------------------------------------------------ SeedData
local function createSeedData()
	local folder = seedDataModule:FindFirstChild(SEED_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = SEED_NAME
		folder.Parent = seedDataModule
	end

	local layoutOrder = 1
	for _, child in seedDataModule:GetChildren() do
		if child:IsA("Folder") then
			layoutOrder += 1
		end
	end

	setValue(folder, "DisplayName", CROP_NAME)
	setValue(folder, "Name", CROP_NAME)
	setValue(folder, "Rarity", cropCfg.rarity)
	setValue(folder, "SeedPrefix", CROP_NAME)
	setValue(folder, "Price", cropCfg.price)
	setValue(folder, "GrowthTime", cropCfg.growthTime)
	setValue(folder, "BaseValue", cropCfg.baseValue)
	-- Mesh-bound: single-harvest unless the model genuinely has multiple fruit anchors.
	setValue(folder, "HarvestCount", cropCfg.harvestCount or 1)
	setValue(folder, "MultiHarvest", cropCfg.multiHarvest == true)
	setValue(folder, "HarvestInterval", cropCfg.harvestInterval or 0)
	setValue(folder, "DevProduct", 0)
	setValue(folder, "LayoutOrder", layoutOrder)
end

local function appendSeedOrder()
	if not seedDataModule:IsA("ModuleScript") then
		warn("[IntegrateCrop] SeedData is not a ModuleScript — add \"" .. SEED_NAME .. "\" to seedOrder manually.")
		return
	end
	local src = seedDataModule.Source
	if string.find(src, SEED_NAME, 1, true) then
		print("[IntegrateCrop] Already present in SeedData.seedOrder")
		return
	end

	-- Locate the seedOrder list explicitly, then insert before ITS closing brace. Patching the
	-- first "\n}" in the file would corrupt whichever table happened to come first.
	local listStart = string.find(src, "seedOrder", 1, true)
	if not listStart then
		warn("[IntegrateCrop] No seedOrder found — add \"" .. SEED_NAME .. "\" manually.")
		return
	end
	local openBrace = string.find(src, "{", listStart, true)
	if not openBrace then
		warn("[IntegrateCrop] Malformed seedOrder — add \"" .. SEED_NAME .. "\" manually.")
		return
	end

	-- Walk to the matching close brace so nested tables can't end the scan early.
	local depth, closeBrace = 0, nil
	for index = openBrace, #src do
		local char = string.sub(src, index, index)
		if char == "{" then
			depth += 1
		elseif char == "}" then
			depth -= 1
			if depth == 0 then
				closeBrace = index
				break
			end
		end
	end
	if not closeBrace then
		warn("[IntegrateCrop] Unbalanced seedOrder braces — add \"" .. SEED_NAME .. "\" manually.")
		return
	end

	local before = string.sub(src, 1, closeBrace - 1)
	local after = string.sub(src, closeBrace)
	-- Keep a trailing comma on the previous entry so the list stays valid Luau.
	if not string.match(before, "[,{]%s*$") then
		before = string.gsub(before, "(%s*)$", ",%1", 1)
	end
	seedDataModule.Source = before .. ('\t"%s",\n'):format(SEED_NAME) .. after
	print("[IntegrateCrop] Added to SeedData.seedOrder")
end

-- ------------------------------------------------------------------ tools / previews
local function createSeedTool()
	if cropSeeds:FindFirstChild(SEED_NAME) then
		return
	end
	local template = cropSeeds:FindFirstChildWhichIsA("Tool")
	if not template then
		warn("[IntegrateCrop] No seed Tool template in ServerStorage.CropSeeds")
		return
	end
	local tool = template:Clone()
	tool.Name = SEED_NAME
	tool.Parent = cropSeeds
end

--[[
	Handle used to just be meshes[1] — an arbitrary mesh from the harvest model (could be the
	bulb, could be a leaf). Every visible mesh welded to it, and Grip/GripPos math was based on
	that arbitrary mesh's size, so the held pose was a guess that got worse the more irregular
	the crop's shape was.

	Now Handle is an INVISIBLE anchor part with no visible geometry of its own. Every visible
	mesh welds to it instead, so "what the hand holds" is decoupled from "what's visible" —
	consistent regardless of crop shape. Positioned at the lower third of the model's height
	(a natural hold point, like gripping a carrot near its base) and centered on X/Z.
]]
local GRIP_HEIGHT_FRACTION = 0.33 -- 0 = bottom of model, 1 = top; lower third reads naturally

--[[
	Instance:Clone() is a deep copy. If a source MeshPart has a nested Model/MeshPart child
	(seen on some pack assets — e.g. an Icosphere.003 mesh with a child Model grouping extra
	Circle.022 copies, likely leftover grouping from the original asset), cloning that mesh
	ALSO clones the nested junk at its ORIGINAL, uncorrected world position — while the same
	nested meshes get independently found by GetDescendants() and cloned+recentered correctly
	as their own top-level siblings anyway. Net result: duplicate geometry, with one copy sitting
	hundreds of studs away from the model.

	This is invisible on a held Tool (nothing frames a camera around it), but SeedModels
	previews are auto-framed by GetBoundingBox() in the shop's ViewportFrame (see
	ShopScript.lua setupViewportModel) — the far-away junk balloons the box, so the camera
	zooms out until the real, correctly-sized model becomes an invisible speck. This is
	exactly what happened to Carrot's shop preview. Strip any nested Model/MeshPart out of
	every clone so only the flat, individually-recentered top-level copies remain.
]]
local function stripNestedGeometry(clone: MeshPart)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Model") or descendant:IsA("MeshPart") then
			descendant:Destroy()
		end
	end
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
		warn("[IntegrateCrop] No meshes on harvest model")
		return
	end

	local temp = Instance.new("Model")
	for _, mesh in meshes do
		local clone = mesh:Clone()
		stripNestedGeometry(clone)
		clone.Parent = temp
	end
	local boundsCFrame, boundsSize = temp:GetBoundingBox()
	local center = boundsCFrame.Position
	temp:Destroy()

	-- Anchor's position in the same "subtract center" space every mesh below gets re-centered
	-- into: X/Z at the model's center, Y at the lower-third grip height.
	local groundY = center.Y - boundsSize.Y / 2
	local anchorLocalY = (groundY + boundsSize.Y * GRIP_HEIGHT_FRACTION) - center.Y

	local tool = Instance.new("Tool")
	tool.Name = CROP_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Transparency = 1
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new(0, anchorLocalY, 0)
	handle.Parent = tool
	-- PrimaryPart is required so Model:ScaleTo (used when the held tool is resized per fruit
	-- weight in InventoryService) scales everything around the grip anchor instead of an
	-- arbitrary pivot. Without this the held fruit balloons in size and drifts sideways.
	tool.PrimaryPart = handle

	for _, mesh in meshes do
		local clone = mesh:Clone()
		stripNestedGeometry(clone)
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

	-- Grip offset is based on the model's actual height, not the (now tiny) anchor size.
	tool.Grip = CFrame.new(0, -boundsSize.Y * 0.15, 0) * CFrame.Angles(math.rad(90), 0, 0)
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

	local groundOffset = PlantStageIntegrate.getModelGroundOffset(sourceModel)
	for _, mesh in sourceModel:GetDescendants() do
		if mesh:IsA("MeshPart") then
			local clone = mesh:Clone()
			stripNestedGeometry(clone)
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

-- ------------------------------------------------------------------ build
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

--[[
	Each growth stage renders its OWN model's full geometry and swaps cleanly at the window
	boundary. We do NOT dedup meshes by MeshId or exclude harvest meshes: a growing plant
	reuses the same mesh assets stage to stage, so deduping collapsed distinct stages into one
	(the "seed / growing / mature all use the same mesh" bug). The harvested fruit is a
	separate Tool built from harvestModel, so nothing needs excluding here.
]]
local seedCount = PlantStageIntegrate.addStageMeshesFull(clientModel, sproutModel, STAGES[1])
local growingCount = PlantStageIntegrate.addStageMeshesFull(clientModel, growingModel, STAGES[2])
local matureCount = PlantStageIntegrate.addStageMeshesFull(clientModel, matureModel, STAGES[3])

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

-- ------------------------------------------------------------------ report
print(("=== %s wired ==="):format(CROP_NAME))
print(("  tier %s | seed $%s | grow %ss | base $%s"):format(
	tostring(cropCfg.rarity), tostring(cropCfg.price), tostring(cropCfg.growthTime), tostring(cropCfg.baseValue)))
print(("  stage meshes: seed(0-34%%) = %d, growing(34-67%%) = %d, mature(67-100%%) = %d"):format(
	seedCount, growingCount, matureCount))

-- The mature stage persists to 100%, so it must have geometry or the plant vanishes when ripe.
if matureCount == 0 then
	warn("  BROKEN: the mature model has no MeshParts — the plant will be invisible when ripe.")
	warn("  Check the 3rd (mature) model actually contains meshes.")
end
if seedCount == 0 or growingCount == 0 then
	warn("  An early stage has no meshes — the models were probably ordered wrong.")
	warn("  Re-check the left-to-right report above, or run with DRY_RUN = true.")
end

-- Self-verify from INSIDE Studio: re-read the tree we just wrote. This is the authoritative
-- check — trust it over an immediate external/MCP query, which can lag on freshly created
-- folders (see CROP_INTEGRATION.md gotcha #8). If it reports ClientModel present here but the
-- Explorer later shows it missing, the write was reverted afterward (playtest stop without
-- saving, undo, or a second Studio window) rather than failing during the run.
task.delay(2, function()
	local pf = plantsFolder:FindFirstChild(CROP_NAME)
	local cm = pf and pf:FindFirstChild("ClientModel")
	local sm = pf and pf:FindFirstChild("ServerModel")
	local cropTool = cropsFolder:FindFirstChild(CROP_NAME)
	print(("[SelfCheck +2s] %s: folder=%s ClientModel=%s (%d children) ServerModel=%s fruitTool=%s"):format(
		CROP_NAME,
		tostring(pf ~= nil),
		tostring(cm ~= nil),
		cm and #cm:GetChildren() or -1,
		tostring(sm ~= nil),
		tostring(cropTool ~= nil)))
end)

print("  Remember: add the crop to CropTierConfig.SEED_TIER, then Stop -> Play -> Ctrl+S.")
