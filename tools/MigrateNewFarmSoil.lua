--[[
	NEW_FARM SOIL MIGRATION
	Paste into the Studio Command Bar.

	Regroups workspace.new_farm's 7 bed-group Models into the structure PlotService.getSoilBeds
	expects: a "Soil" container whose DIRECT CHILDREN are the bed surface BaseParts themselves.

	new_farm currently has each bed as its own self-contained Model (frame mesh + corner-post
	meshes + flower decor + a "Meshes/farm_soil.001" MeshPart bundled together) — nothing named
	"Soil" exists yet. This script finds all 7 bed-groups, sorts them by distance from TPPart
	(the exact same reference PlotService.getSoilBeds uses to order beds), takes the nearest 6
	as the real plantable beds, and MOVES (not clones) each one's soil MeshPart into a fresh
	Soil model — leaving the frame/decor meshes right where they are, since PlotService never
	touches them.

	The farthest (7th) bed-group is deliberately left untouched — reserved for a future feature,
	per explicit instruction. It is never modified by this script.

	Moving a part's Parent does not change its CFrame, so the bed keeps rendering in the exact
	same spot — only its place in the hierarchy changes. PlotService.locationIsWithinPlot
	raycasts against beds via an explicit Include filter list, and setupBeds tags beds with
	attributes (not by name), so neither cares what the bed's Parent chain looks like.

	USAGE
	  1. Edit mode. No selection required — this operates on FARM_NAME directly.
	  2. Run with DRY_RUN = true first. Read the printed distance-sorted list and confirm the
	     "KEEP UNTOUCHED (stray/future)" line is the bed-group you expect to skip.
	  3. Set DRY_RUN = false and run again.
	  4. Confirm via the [SelfCheck] print, then Ctrl+S.

	This script does NOT swap new_farm into workspace.Plots — that's a separate, higher-risk
	step (it reassigns where live players spawn/plant) and should be done deliberately once the
	structure here is confirmed correct.
--]]

--=============================== CONFIGURE ===============================
local FARM_NAME = "new_farm"
local BED_COUNT = 6 -- nearest N bed-groups (by distance from TPPart) become real beds
local DRY_RUN = true -- true = report the plan and change nothing
--=========================================================================

local farm = workspace:FindFirstChild(FARM_NAME)
if not farm then
	error(("[MigrateFarmSoil] workspace.%s not found."):format(FARM_NAME))
end

local tpPart = farm:FindFirstChild("TPPart")
if not tpPart or not tpPart:IsA("BasePart") then
	error(("[MigrateFarmSoil] %s.TPPart missing or not a BasePart — required as the sort reference (matches PlotService.getSoilBeds)."):format(FARM_NAME))
end

-- ------------------------------------------------------------------ find bed-group candidates
-- Identified by containing a "Meshes/farm_soil.001" MeshPart descendant, NOT by generic "Model"
-- naming — new_farm has other unrelated "Model" siblings (decor) that don't represent beds.
local SOIL_MESH_NAME = "Meshes/farm_soil.001"

local candidates: { { group: Model, soilMesh: MeshPart, distance: number } } = {}
for _, child in farm:GetChildren() do
	if child:IsA("Model") then
		local soilMesh = child:FindFirstChild(SOIL_MESH_NAME, true)
		if soilMesh and soilMesh:IsA("MeshPart") then
			table.insert(candidates, {
				group = child,
				soilMesh = soilMesh,
				distance = (soilMesh.Position - tpPart.Position).Magnitude,
			})
		end
	end
end

if #candidates == 0 then
	error(("[MigrateFarmSoil] No bed-group Models found under %s containing a '%s' MeshPart."):format(
		FARM_NAME, SOIL_MESH_NAME))
end

table.sort(candidates, function(a, b)
	return a.distance < b.distance
end)

print(("=== %s bed-groups, sorted by distance from TPPart ==="):format(FARM_NAME))
for index, entry in candidates do
	local role = if index <= BED_COUNT then "BED " .. index else "KEEP UNTOUCHED (stray/future)"
	print(("  %d. %-30s dist=%.1f  -> %s"):format(index, entry.group.Name, entry.distance, role))
end

if #candidates <= BED_COUNT then
	warn(("[MigrateFarmSoil] Only %d bed-group(s) found but BED_COUNT=%d — nothing will be left as stray."):format(
		#candidates, BED_COUNT))
end

if DRY_RUN then
	print("[MigrateFarmSoil] DRY_RUN — nothing changed. Set DRY_RUN = false to apply.")
	return
end

-- ------------------------------------------------------------------ build Soil container
-- Matches the existing plots' structure: workspace.Plots["N"].Soil is a Model whose direct
-- children are the bed BaseParts.
local soil = farm:FindFirstChild("Soil")
if not soil then
	soil = Instance.new("Model")
	soil.Name = "Soil"
	soil.Parent = farm
end

for index = 1, math.min(BED_COUNT, #candidates) do
	local entry = candidates[index]
	local mesh = entry.soilMesh
	mesh.Name = "Bed" .. index -- was the generic "Meshes/farm_soil.001"; distinct names read
	-- better once 6 of them sit side-by-side under Soil. Renaming is safe: PlotService reads
	-- beds by iteration + Attribute (BedIndex, OriginalColor), never by Name.
	mesh.Parent = soil
end

print(("[MigrateFarmSoil] Moved %d soil mesh(es) into %s.Soil."):format(math.min(BED_COUNT, #candidates), FARM_NAME))

-- ------------------------------------------------------------------ self-check
task.delay(1, function()
	local soilCheck = farm:FindFirstChild("Soil")
	local bedCount = 0
	if soilCheck then
		for _, part in soilCheck:GetChildren() do
			if part:IsA("BasePart") then
				bedCount += 1
			end
		end
	end

	local strayEntry = candidates[#candidates] -- farthest one, only meaningful if BED_COUNT < #candidates
	local strayIntact = strayEntry and strayEntry.soilMesh.Parent == strayEntry.group

	print(("[SelfCheck +1s] %s.Soil exists=%s bedCount=%d (expected %d)"):format(
		FARM_NAME, tostring(soilCheck ~= nil), bedCount, math.min(BED_COUNT, #candidates)))
	if strayEntry then
		print(("  stray group '%s' untouched=%s"):format(strayEntry.group.Name, tostring(strayIntact)))
	end
end)

print("[MigrateFarmSoil] Done. Remember: this does NOT swap new_farm into workspace.Plots.")
print("  Next step (separate, do deliberately): decide which Plots[\"N\"] slot new_farm replaces, then Ctrl+S -> Play to verify beds are plantable.")
