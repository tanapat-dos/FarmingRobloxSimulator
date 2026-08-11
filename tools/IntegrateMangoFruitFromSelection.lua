--[[
	MANGO HANGING-FRUIT REMODEL (from Studio selection)
	Paste into the Studio Command Bar.

	Mango is the game's only multi-harvest/perennial crop: 4 separate hanging fruits
	(ClientModel.fruit_1 .. fruit_4) sit on FIXED anchor points (ServerModel.FruitPrompts[1..4])
	on the tree and individually reappear every re-ripen cycle. The generic
	IntegrateCropFromSelection.lua tool assumes ONE harvest mesh -> ONE HarvestAnchor and would
	destroy this 4-slot mechanic, so this is a dedicated tool that touches ONLY the fruit
	geometry — tree growth stages, FruitPrompts anchors, MultiHarvest/harvestCount/
	harvestInterval are never modified.

	Each fruit_N is repositioned at runtime via Model:SetPrimaryPartCFrame(FruitPrompts[N].CFrame)
	(see src/client/CropReplicator/Main.client.lua harvestableChanged) — so a fruit_N's WORLD
	position here doesn't matter, only its geometry relative to its own PrimaryPart. That is
	what lets 4 differently-shaped/positioned Workspace models become 4 correctly-hanging fruit
	slots without any manual CFrame math.

	USAGE
	  1. Place your new fruit designs in Workspace (any position — it gets recentered).
	  2. Select ALL of them together with the source model that should become the shop preview
	     and the held Tool (see FRUIT_SLOT_MAP / HELD_TOOL_SOURCE_NAME below).
	  3. Fill FRUIT_SLOT_MAP: Workspace model name -> which fruit_N slot (1-4) it replaces.
	  4. Set HELD_TOOL_SOURCE_NAME to whichever selected model should represent the item a
	     player holds after harvesting (must be one of the same selected models).
	  5. Set SEED_PREVIEW_SOURCE_NAME similarly for the shop preview model (optional — leave ""
	     to skip touching the shop preview).
	  6. Run with DRY_RUN = true first, confirm the plan, then DRY_RUN = false.

	Creates / replaces:
	    ReplicatedStorage.Assets.Plants.Mango.ClientModel.fruit_1 .. fruit_4
	    ReplicatedStorage.Assets.Crops.Mango                          held fruit Tool
	    ReplicatedStorage.SeedModels["Mango Seed"]                    shop preview (optional)
	Never touches: FruitPrompts anchors, ServerModel, growth stages, SeedData/EconomyBalance.
--]]

--=============================== CONFIGURE ===============================
-- Workspace model name -> fruit_N slot number (1-4) it replaces.
local FRUIT_SLOT_MAP = {
	["Mango1"] = 1,
	["Mango2"] = 2,
	["Mango3"] = 3,
	["Mango4"] = 4,
}
local HELD_TOOL_SOURCE_NAME = "Mango1" -- which selected model becomes the held Tool
local SEED_PREVIEW_SOURCE_NAME = "Mango_Seed" -- "" to skip the shop preview model
local DRY_RUN = false -- true = report the plan and change nothing
--=========================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local CROP_NAME = "Mango"

local plantFolder = ReplicatedStorage.Assets.Plants:FindFirstChild(CROP_NAME)
if not plantFolder then
	error(("[IntegrateMangoFruit] ReplicatedStorage.Assets.Plants.%s not found."):format(CROP_NAME))
end
local clientModel = plantFolder:FindFirstChild("ClientModel")
if not clientModel then
	error(("[IntegrateMangoFruit] %s.ClientModel not found."):format(CROP_NAME))
end

-- ------------------------------------------------------------------ selection
local selected = Selection:Get()
local modelsByName: { [string]: Model } = {}
for _, inst in selected do
	if inst:IsA("Model") then
		modelsByName[inst.Name] = inst
	end
end

print("=== Mango fruit remodel plan ===")
local plan = {}
for sourceName, slot in FRUIT_SLOT_MAP do
	local model = modelsByName[sourceName]
	if not model then
		error(("[IntegrateMangoFruit] '%s' is mapped to fruit_%d but is not in the current selection."):format(
			sourceName, slot))
	end
	table.insert(plan, { sourceName = sourceName, model = model, slot = slot })
end
table.sort(plan, function(a, b)
	return a.slot < b.slot
end)

local function countMeshes(model: Model): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			n += 1
		end
	end
	return n
end

for _, entry in plan do
	print(("  %-14s -> fruit_%d   meshes=%d"):format(entry.sourceName, entry.slot, countMeshes(entry.model)))
	if countMeshes(entry.model) == 0 then
		warn(("    WARNING: '%s' has no MeshParts — this fruit slot will be invisible."):format(entry.sourceName))
	end
end

local heldToolModel = modelsByName[HELD_TOOL_SOURCE_NAME]
if not heldToolModel then
	error(("[IntegrateMangoFruit] HELD_TOOL_SOURCE_NAME '%s' is not in the current selection."):format(
		HELD_TOOL_SOURCE_NAME))
end
print(("  Held Tool source: %s (meshes=%d)"):format(HELD_TOOL_SOURCE_NAME, countMeshes(heldToolModel)))

local seedPreviewModel: Model? = nil
if SEED_PREVIEW_SOURCE_NAME ~= "" then
	seedPreviewModel = modelsByName[SEED_PREVIEW_SOURCE_NAME]
	if not seedPreviewModel then
		error(("[IntegrateMangoFruit] SEED_PREVIEW_SOURCE_NAME '%s' is not in the current selection."):format(
			SEED_PREVIEW_SOURCE_NAME))
	end
	print(("  Seed preview source: %s (meshes=%d)"):format(SEED_PREVIEW_SOURCE_NAME, countMeshes(seedPreviewModel)))
else
	print("  Seed preview: skipped (SEED_PREVIEW_SOURCE_NAME is empty)")
end

if DRY_RUN then
	print("[IntegrateMangoFruit] DRY_RUN — nothing changed. Set DRY_RUN = false to apply.")
	return
end

-- ------------------------------------------------------------------ helpers
-- Same nested-geometry guard as IntegrateCropFromSelection.lua: some source models nest a
-- child Model/MeshPart at a stale world position, which Clone() would carry along verbatim
-- and balloon the recentered bounding box (breaks shop preview auto-framing).
local function stripNestedGeometry(clone: MeshPart)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Model") or descendant:IsA("MeshPart") then
			descendant:Destroy()
		end
	end
end

local function collectMeshes(model: Model): { MeshPart }
	local meshes: { MeshPart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(meshes, d)
		end
	end
	return meshes
end

-- ------------------------------------------------------------------ fruit_N rebuild
-- fruit_N is repositioned entirely via SetPrimaryPartCFrame at runtime, so only geometry
-- RELATIVE TO PrimaryPart matters. Recenter every mesh onto the source model's bounding-box
-- center and use the first mesh as PrimaryPart — same anchor convention the existing
-- fruit_1..4 already use (a visible mesh as PrimaryPart, not an invisible grip anchor; that
-- distinction only matters for held Tools, where GripPos math needs a stable, shape-agnostic
-- anchor).
local function buildFruitSlot(sourceModel: Model, slotNumber: number)
	local existing = clientModel:FindFirstChild("fruit_" .. slotNumber)
	if existing then
		existing:Destroy()
	end

	local meshes = collectMeshes(sourceModel)
	if #meshes == 0 then
		warn(("[IntegrateMangoFruit] fruit_%d has no meshes — skipped."):format(slotNumber))
		return
	end

	local boundsCFrame = select(1, sourceModel:GetBoundingBox())
	local center = boundsCFrame.Position

	local fruit = Instance.new("Model")
	fruit.Name = "fruit_" .. slotNumber

	local primaryPart: MeshPart? = nil
	for _, mesh in meshes do
		local clone = mesh:Clone()
		stripNestedGeometry(clone)
		clone.Anchored = true
		clone.CanCollide = false
		clone.CastShadow = false
		clone.CFrame = clone.CFrame - center
		clone.Parent = fruit
		if not primaryPart then
			primaryPart = clone
		end
	end

	fruit.PrimaryPart = primaryPart
	fruit.Parent = clientModel
end

for _, entry in plan do
	buildFruitSlot(entry.model, entry.slot)
end

-- ------------------------------------------------------------------ held Tool rebuild
-- Identical grip convention to IntegrateCropFromSelection.lua's createFruitToolFromModel:
-- Handle is an INVISIBLE anchor (not an arbitrary visible mesh) so the held pose doesn't
-- depend on which mesh happened to be first, and PrimaryPart is set so InventoryService's
-- per-fruit-weight Model:ScaleTo scales around the grip point instead of a random pivot.
local GRIP_HEIGHT_FRACTION = 0.33

local function rebuildHeldTool(sourceModel: Model)
	local cropsFolder = ReplicatedStorage.Assets.Crops
	local existing = cropsFolder:FindFirstChild(CROP_NAME)
	if existing then
		existing:Destroy()
	end

	local meshes = collectMeshes(sourceModel)
	if #meshes == 0 then
		warn("[IntegrateMangoFruit] Held tool source has no meshes — tool not rebuilt.")
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

	tool.Grip = CFrame.new(0, -boundsSize.Y * 0.15, 0) * CFrame.Angles(math.rad(90), 0, 0)
	tool.Parent = cropsFolder
end

rebuildHeldTool(heldToolModel)

-- ------------------------------------------------------------------ shop preview rebuild
local function rebuildSeedPreview(sourceModel: Model)
	local seedModels = ReplicatedStorage:WaitForChild("SeedModels")
	local seedName = CROP_NAME .. " Seed"
	local existing = seedModels:FindFirstChild(seedName)
	if existing then
		existing:Destroy()
	end

	local meshes = collectMeshes(sourceModel)
	if #meshes == 0 then
		warn("[IntegrateMangoFruit] Seed preview source has no meshes — preview not rebuilt.")
		return
	end

	local boundsCFrame, boundsSize = sourceModel:GetBoundingBox()
	local center = boundsCFrame.Position
	local groundOffset = Vector3.new(center.X, center.Y - boundsSize.Y / 2, center.Z)

	local model = Instance.new("Model")
	model.Name = seedName

	local primary = Instance.new("Part")
	primary.Name = "PrimaryPart"
	primary.Size = Vector3.new(0.1, 0.1, 0.1)
	primary.Anchored = true
	primary.CanCollide = false
	primary.Transparency = 1
	primary.CFrame = CFrame.new(0, 0, 0)
	primary.Parent = model
	model.PrimaryPart = primary

	for _, mesh in meshes do
		local clone = mesh:Clone()
		stripNestedGeometry(clone)
		clone.Anchored = true
		clone.CanCollide = false
		clone.CFrame = mesh.CFrame - groundOffset
		clone.Parent = model
	end

	model.Parent = seedModels
end

if seedPreviewModel then
	rebuildSeedPreview(seedPreviewModel)
end

-- ------------------------------------------------------------------ self-check
task.delay(1, function()
	print("[SelfCheck +1s]")
	for slot = 1, 4 do
		local fruit = clientModel:FindFirstChild("fruit_" .. slot)
		local meshCount = fruit and countMeshes(fruit) or -1
		print(("  fruit_%d exists=%s meshes=%d primaryPart=%s"):format(
			slot, tostring(fruit ~= nil), meshCount, tostring(fruit and fruit.PrimaryPart ~= nil)))
	end
	local toolCheck = ReplicatedStorage.Assets.Crops:FindFirstChild(CROP_NAME)
	print(("  held Tool exists=%s"):format(tostring(toolCheck ~= nil)))
	if seedPreviewModel then
		local previewCheck = ReplicatedStorage.SeedModels:FindFirstChild(CROP_NAME .. " Seed")
		print(("  seed preview exists=%s"):format(tostring(previewCheck ~= nil)))
	end
end)

print("[IntegrateMangoFruit] Done. FruitPrompts anchors / growth stages / MultiHarvest config untouched.")
print("  Ctrl+S -> Play, then harvest a mango slot in-game to check the new look and grip pose.")
