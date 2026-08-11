--[[
	PET MODEL INTEGRATION (from Studio selection)
	Paste into the Studio Command Bar.

	Wires new pet display models into ReplicatedStorage.Assets.Pets.<EggName>, matching the
	structure PetService/PetClient already expect: a Model with a PrimaryPart named "Head"
	(anything else the client just falls back to FindFirstChildWhichIsA("BasePart")), containing
	only visible geometry parts (PetClient walks descendants and anchors/no-collides every
	BasePart, so extra junk like Scripts, ParticleEmitters, or nested nameplate Parts just gets
	dragged along and welded in place — better to strip it here than ship it into the live egg
	folder).

	Two geometry shapes are supported, because source assets mix both:
	  - MeshPart (the modern format — what all current egg pets use)
	  - Part with a SpecialMesh child (the old "package" mesh format — e.g. this run's Browndog,
	    which is really a Part named "Animal ez1" with a SpecialMesh, not a MeshPart at all)
	Anything else (Scripts, ParticleEmitters, Attachments, Welds, plain non-meshed Parts) is
	left behind on purpose.

	USAGE
	  1. Select the source Models in Workspace (any number, any order — order doesn't matter
	     here, unlike the crop tool).
	  2. Fill PET_NAME_MAP below: selected model's CURRENT Workspace name -> desired pet name
	     in the egg. Every selected model must have an entry or the script errors (fail loud,
	     not silently skip one).
	  3. Set EGG_NAME to the egg folder to write into.
	  4. If REPLACE_EXISTING = true, every pet CURRENTLY in that egg folder that is NOT one of
	     this run's target names gets deleted first (full swap, not merge). Set false to only
	     add/overwrite the named pets and leave the rest alone.
	  5. Run with DRY_RUN = true first — it prints exactly what would be created/replaced/
	     deleted. Only flip to false once that list looks right.
	  6. After a live run, update EconomyBalance.PET_BOOSTS[EGG_NAME] (and PET_GROWTH_REDUCTION
	     if applicable) yourself — this tool only touches the ReplicatedStorage models, never
	     the economy tables in src/.

	Creates / replaces:
	    ReplicatedStorage.Assets.Pets.<EggName>.<PetName>   Model (Head PrimaryPart, MeshParts)
	Never touches the Workspace source models — they are cloned from, not moved.
]]

--=============================== CONFIGURE ===============================
local EGG_NAME = "Uncommon Egg"
local REPLACE_EXISTING = false -- false = only add/overwrite the named pets, keep everything else
local DRY_RUN = false -- true = report what would happen and change nothing

-- Workspace model name -> pet name to create in the egg folder.
local PET_NAME_MAP = {
	["MewWat"] = "MewWat",
	["Fireclouds"] = "Fireclouds",
}
--=========================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

if EGG_NAME == "" then
	error("[IntegratePets] Set EGG_NAME at the top of the script first.")
end

-- ------------------------------------------------------------------ selection
local selected = Selection:Get()
local models: { Model } = {}
for _, inst in selected do
	if inst:IsA("Model") then
		table.insert(models, inst)
	end
end

if #models == 0 then
	error("[IntegratePets] Select at least one Model in Workspace first.")
end

local missingMap = {}
for _, model in models do
	if not PET_NAME_MAP[model.Name] then
		table.insert(missingMap, model.Name)
	end
end
if #missingMap > 0 then
	error(("[IntegratePets] No PET_NAME_MAP entry for: %s. Add each selected model's name to the map."):format(
		table.concat(missingMap, ", ")))
end

-- A "geometry part" is either a MeshPart, or a Part with a SpecialMesh child (the older
-- package-mesh format). Everything else (Scripts, ParticleEmitters, Attachments, Welds, plain
-- Parts with no mesh) is not geometry and gets left behind.
local function collectGeometryParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(parts, d)
		elseif d:IsA("Part") and d:FindFirstChildWhichIsA("SpecialMesh") then
			table.insert(parts, d)
		end
	end
	return parts
end

-- ------------------------------------------------------------------ report + dedupe check
print(("=== Pet integration plan: %s ==="):format(EGG_NAME))
local seenTargetNames = {}
for _, model in models do
	local petName = PET_NAME_MAP[model.Name]
	if seenTargetNames[petName] then
		error(("[IntegratePets] Two selected models map to the same pet name '%s' (%s and %s)."):format(
			petName, seenTargetNames[petName], model.Name))
	end
	seenTargetNames[petName] = model.Name

	local geometryParts = collectGeometryParts(model)
	print(("  %-16s -> %-14s geometryParts=%d"):format(model.Name, petName, #geometryParts))
	if #geometryParts == 0 then
		warn(("    WARNING: '%s' has no MeshPart/SpecialMesh geometry — the resulting pet will be invisible."):format(model.Name))
	end
end

local petsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local eggFolder = petsAssets:FindFirstChild(EGG_NAME)
if not eggFolder then
	print(("  (egg folder '%s' does not exist yet — will be created)"):format(EGG_NAME))
elseif REPLACE_EXISTING then
	local toDelete = {}
	for _, child in eggFolder:GetChildren() do
		if not seenTargetNames[child.Name] then
			table.insert(toDelete, child.Name)
		end
	end
	if #toDelete > 0 then
		print(("  Will DELETE existing pets not in this run: %s"):format(table.concat(toDelete, ", ")))
	end
end

if DRY_RUN then
	print("[IntegratePets] DRY_RUN — nothing changed. Set DRY_RUN = false to apply.")
	return
end

-- ------------------------------------------------------------------ build
if not eggFolder then
	eggFolder = Instance.new("Folder")
	eggFolder.Name = EGG_NAME
	eggFolder.Parent = petsAssets
end

if REPLACE_EXISTING then
	for _, child in eggFolder:GetChildren() do
		if not seenTargetNames[child.Name] then
			child:Destroy()
		end
	end
end

--[[
	Same nested-geometry problem as the crop tool: some source models here carry a rig Script,
	ParticleEmitters, Attachments, and (in one case) a whole nested "statue" sub-model with its
	own duplicate parts. Only geometry parts (MeshPart, or Part+SpecialMesh) are useful for a
	follower pet, so we clone those only and flatten them onto a fresh Model — everything else
	(scripts, particles, welds, nameplate Parts) is deliberately left behind, not carried into
	the live egg folder.
]]
local function buildPetModel(sourceModel: Model, petName: string): Model
	local geometryParts = collectGeometryParts(sourceModel)

	local pet = Instance.new("Model")
	pet.Name = petName

	local headPart: BasePart? = nil
	for _, part in geometryParts do
		local clone = part:Clone()
		-- Strip any nested Model/MeshPart carried along on a clone (mirrors the crop tool's
		-- stripNestedGeometry fix — some packs nest duplicate meshes inside a mesh's own tree
		-- at stale positions). SpecialMesh/Weld/Attachment children are harmless and left
		-- alone; a Part's own SpecialMesh IS its visible shape, unlike MeshPart's baked mesh.
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("Model") or descendant:IsA("MeshPart") then
				descendant:Destroy()
			end
		end
		clone.Anchored = true
		clone.CanCollide = false
		clone.CastShadow = false
		clone.Parent = pet

		-- Prefer a source part literally named "Head" (matches existing pet convention); else
		-- fall back to the first geometry part so PrimaryPart is a sensible anchor either way.
		if part.Name == "Head" then
			headPart = clone
		elseif not headPart then
			headPart = clone
		end
	end

	if #geometryParts == 0 then
		warn(("[IntegratePets] '%s' had no MeshPart/SpecialMesh geometry — created an empty pet model."):format(sourceModel.Name))
	end

	if headPart then
		headPart.Name = "Head"
		pet.PrimaryPart = headPart
	end

	return pet
end

for _, model in models do
	local petName = PET_NAME_MAP[model.Name]
	local existing = eggFolder:FindFirstChild(petName)
	if existing then
		existing:Destroy()
	end
	local pet = buildPetModel(model, petName)
	pet.Parent = eggFolder
end

-- ------------------------------------------------------------------ self-check
task.delay(1, function()
	print(("[SelfCheck +1s] %s pets present:"):format(EGG_NAME))
	for _, child in eggFolder:GetChildren() do
		local geometryCount = #collectGeometryParts(child)
		print(("  %-14s geometryParts=%d primaryPart=%s"):format(
			child.Name, geometryCount, tostring(child.PrimaryPart ~= nil)))
	end
end)

print("[IntegratePets] Done. Remember to update EconomyBalance.PET_BOOSTS[\"" .. EGG_NAME .. "\"] " ..
	"(and PET_GROWTH_REDUCTION if this tier grants one) to match the new pet names, then Ctrl+S -> Play.")
