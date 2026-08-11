--[[
	CLONE the already-swapped new_farm plot into the remaining plot slots.
	Paste into the Studio Command Bar.

	We only have ONE new_farm model, and it's already installed at workspace.Plots["1"]
	(via SwapPlotToNewFarm.lua) and confirmed working. This script clones THAT working model
	into slots 2-6, repositioning each clone to sit where the OLD plot at that slot used to be
	— so the map keeps its 6 distinct garden locations instead of every clone landing on top
	of plot 1's spot (new_farm kept its own original Workspace placement when it was swapped
	into slot 1, it was never moved to plot 1's old position).

	Old models at the target slots are moved into workspace.PlotsBackup (same as plot 1's swap
	— kept, not deleted), keyed by their own name so they don't collide with plot 1's backup.

	USAGE
	  1. Edit mode only.
	  2. Run with DRY_RUN = true first. Confirms Plots["1"] exists and is a real new_farm-based
	     model (has Soil/TPPart/etc.), and reports the pivot each target slot's clone will move
	     to.
	  3. Set DRY_RUN = false and run again.
	  4. Confirm via [SelfCheck], then Ctrl+S -> Play. Test: check all 6 gardens are reachable,
	     visually placed apart, each with working beds.
--]]

--=============================== CONFIGURE ===============================
local SOURCE_SLOT = "1" -- the already-working new_farm-based plot to clone from
local TARGET_SLOTS = { "2", "3", "4", "5", "6" }
local BACKUP_FOLDER_NAME = "PlotsBackup"
local DRY_RUN = false -- true = report the plan and change nothing
--=========================================================================

local plotsFolder = workspace:FindFirstChild("Plots")
if not plotsFolder then
	error("[CloneFarm] workspace.Plots not found.")
end

local sourcePlot = plotsFolder:FindFirstChild(SOURCE_SLOT)
if not sourcePlot then
	error(("[CloneFarm] workspace.Plots[\"%s\"] not found — swap it to new_farm first."):format(SOURCE_SLOT))
end

-- ------------------------------------------------------------------ structural check on source
local function requireChild(model: Instance, path: { string }): Instance?
	local current = model
	for _, name in path do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local checks = {
	{ "Soil", { "Soil" } },
	{ "TPPart", { "TPPart" } },
	{ "ReferencePoint", { "ReferencePoint" } },
	{ "Owner_Tag", { "Owner_Tag" } },
	{ "PlayerSign.Main.SurfaceGui.TextLabel", { "PlayerSign", "Main", "SurfaceGui", "TextLabel" } },
	{ "PlayerSign.Main.SurfaceGui.ImageLabel", { "PlayerSign", "Main", "SurfaceGui", "ImageLabel" } },
}

print(("=== Source Plots[\"%s\"] structural check ==="):format(SOURCE_SLOT))
local allOk = true
for _, check in checks do
	local label, path = check[1], check[2]
	local found = requireChild(sourcePlot, path) ~= nil
	print(("  %-40s %s"):format(label, found and "OK" or "MISSING"))
	if not found then
		allOk = false
	end
end
if not allOk then
	error(("[CloneFarm] Plots[\"%s\"] is missing required structure — fix before cloning from it."):format(SOURCE_SLOT))
end

-- ------------------------------------------------------------------ plan
print("=== Plan ===")
local plan = {}
for _, slot in TARGET_SLOTS do
	local oldModel = plotsFolder:FindFirstChild(slot)
	if not oldModel then
		warn(("  Plots[\"%s\"] not found — skipping."):format(slot))
		continue
	end
	local pivot = oldModel:GetPivot()
	table.insert(plan, { slot = slot, oldModel = oldModel, pivot = pivot })
	print(("  Plots[\"%s\"]: back up old model, clone Plots[\"%s\"] to pivot (%.1f, %.1f, %.1f)"):format(
		slot, SOURCE_SLOT, pivot.Position.X, pivot.Position.Y, pivot.Position.Z))
end

if #plan == 0 then
	print("[CloneFarm] Nothing to do.")
	return
end

if DRY_RUN then
	print("[CloneFarm] DRY_RUN — nothing changed. Set DRY_RUN = false to apply.")
	return
end

-- ------------------------------------------------------------------ apply
local backupFolder = workspace:FindFirstChild(BACKUP_FOLDER_NAME)
if not backupFolder then
	backupFolder = Instance.new("Folder")
	backupFolder.Name = BACKUP_FOLDER_NAME
	backupFolder.Parent = workspace
end

for _, entry in plan do
	-- Back up the old model at this slot (cleared attributes, same as plot 1's swap).
	entry.oldModel:SetAttribute("Taken", nil)
	entry.oldModel:SetAttribute("USERID", nil)
	entry.oldModel.Parent = backupFolder

	-- Clone the working farm, move it to where the old plot sat, rename to the slot, install.
	local clone = sourcePlot:Clone()
	clone:PivotTo(entry.pivot)
	clone:SetAttribute("Taken", nil)
	clone:SetAttribute("USERID", nil)
	clone.Name = entry.slot
	clone.Parent = plotsFolder

	print(("[CloneFarm] Plots[\"%s\"] now a new_farm clone (old model backed up)."):format(entry.slot))
end

-- ------------------------------------------------------------------ self-check
task.delay(1, function()
	print("[SelfCheck +1s]")
	print(("  Plots childCount=%d (expected 6)"):format(#plotsFolder:GetChildren()))
	for _, entry in plan do
		local swapped = plotsFolder:FindFirstChild(entry.slot)
		local soilOk = swapped and swapped:FindFirstChild("Soil") ~= nil
		local bedCount = 0
		if soilOk then
			for _, part in swapped.Soil:GetChildren() do
				if part:IsA("BasePart") then
					bedCount += 1
				end
			end
		end
		print(("  Plots[\"%s\"]: exists=%s Soil=%s beds=%d"):format(
			entry.slot, tostring(swapped ~= nil), tostring(soilOk), bedCount))
	end
end)

print("[CloneFarm] Done. Ctrl+S -> Play to test all 6 gardens.")
