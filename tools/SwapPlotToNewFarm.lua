--[[
	SWAP workspace.Plots["1"] -> new_farm   (test on one plot first)
	Paste into the Studio Command Bar.

	PlotService.getMaxPlots() is #workspace.Plots:GetChildren() and getAvailablePlot loops
	1..getMaxPlots() doing workspace.Plots[tostring(i)] — so the OLD plot model must be moved
	OUT of workspace.Plots entirely, not just hidden in place, or the child count goes to 7 and
	breaks that indexed lookup. This script parents the old model into a sibling
	"workspace.PlotsBackup" folder instead of deleting it, per instruction to keep it recoverable.

	new_farm gets renamed to "1" and reparented into workspace.Plots — same name PlotService
	looks up, same structural requirements already confirmed present (Soil with 6 beds,
	TPPart, ReferencePoint, Owner_Tag, PlayerSign.Main.SurfaceGui.{TextLabel,ImageLabel}).

	USAGE
	  1. Edit mode only.
	  2. Run with DRY_RUN = true first — confirms both source instances exist and reports the
	     plan without changing anything.
	  3. Set DRY_RUN = false and run again.
	  4. Confirm via [SelfCheck], then Ctrl+S -> Play. Test: join, confirm you spawn in the new
	     farm, plant/buy a bed, confirm beds 2-6 show the updated (reduced) prices.

	Does NOT touch player save data. A player who already owns beds on old plot "1" keeps
	that PlotsOwned count server-side — it just now applies to new_farm's beds instead.
--]]

--=============================== CONFIGURE ===============================
local PLOT_SLOT = "1" -- which workspace.Plots[N] to replace
local NEW_FARM_NAME = "new_farm"
local BACKUP_FOLDER_NAME = "PlotsBackup"
local DRY_RUN = false -- true = report the plan and change nothing
--=========================================================================

local plotsFolder = workspace:FindFirstChild("Plots")
if not plotsFolder then
	error("[SwapPlot] workspace.Plots not found.")
end

local oldPlot = plotsFolder:FindFirstChild(PLOT_SLOT)
if not oldPlot then
	error(("[SwapPlot] workspace.Plots[\"%s\"] not found."):format(PLOT_SLOT))
end

local newFarm = workspace:FindFirstChild(NEW_FARM_NAME)
if not newFarm then
	error(("[SwapPlot] workspace.%s not found."):format(NEW_FARM_NAME))
end

-- ------------------------------------------------------------------ structural check
-- Re-verify the requirements PlotService actually reads, so a bad swap fails loudly here
-- instead of silently breaking spawn/plant in-game.
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

print(("=== %s structural check ==="):format(NEW_FARM_NAME))
local allOk = true
for _, check in checks do
	local label, path = check[1], check[2]
	local found = requireChild(newFarm, path) ~= nil
	print(("  %-40s %s"):format(label, found and "OK" or "MISSING"))
	if not found then
		allOk = false
	end
end

local soil = newFarm:FindFirstChild("Soil")
local bedCount = 0
if soil then
	for _, part in soil:GetChildren() do
		if part:IsA("BasePart") then
			bedCount += 1
		end
	end
end
print(("  Soil bed count: %d"):format(bedCount))

if not allOk then
	error(("[SwapPlot] %s is missing required structure — fix before swapping."):format(NEW_FARM_NAME))
end

print(("=== Plan ==="))
print(("  Move workspace.Plots[\"%s\"] -> workspace.%s.%s"):format(PLOT_SLOT, BACKUP_FOLDER_NAME, oldPlot.Name))
print(("  Move workspace.%s -> workspace.Plots[\"%s\"]"):format(NEW_FARM_NAME, PLOT_SLOT))
print(("  workspace.Plots child count after swap: %d (unchanged)"):format(#plotsFolder:GetChildren()))

if DRY_RUN then
	print("[SwapPlot] DRY_RUN — nothing changed. Set DRY_RUN = false to apply.")
	return
end

-- ------------------------------------------------------------------ apply
local backupFolder = workspace:FindFirstChild(BACKUP_FOLDER_NAME)
if not backupFolder then
	backupFolder = Instance.new("Folder")
	backupFolder.Name = BACKUP_FOLDER_NAME
	backupFolder.Parent = workspace
end

-- Clear any stale Taken/USERID attributes before moving it out — a moved-aside plot showing
-- as "taken" would be confusing if ever inspected later, and it's no longer live anyway.
oldPlot:SetAttribute("Taken", nil)
oldPlot:SetAttribute("USERID", nil)
oldPlot.Parent = backupFolder

newFarm.Name = PLOT_SLOT
newFarm.Parent = plotsFolder

print(("[SwapPlot] Swapped. workspace.Plots[\"%s\"] is now %s (backed up as workspace.%s.%s)."):format(
	PLOT_SLOT, NEW_FARM_NAME, BACKUP_FOLDER_NAME, oldPlot.Name))

-- ------------------------------------------------------------------ self-check
task.delay(1, function()
	local swapped = plotsFolder:FindFirstChild(PLOT_SLOT)
	local backedUp = backupFolder:FindFirstChild(oldPlot.Name)
	print(("[SelfCheck +1s] Plots[\"%s\"] exists=%s  backup exists=%s  Plots childCount=%d"):format(
		PLOT_SLOT, tostring(swapped ~= nil), tostring(backedUp ~= nil), #plotsFolder:GetChildren()))
end)

print("[SwapPlot] Remember: EconomyBalance.PLOTS.maxOwned/prices should already match new_farm's bed count (6). Ctrl+S -> Play to test.")
