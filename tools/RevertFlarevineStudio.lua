--[[
	REVERT FLAREVINE (game integration only)
	Paste into Studio Command Bar once.

	Removes ReplicatedStorage / ServerStorage Flarevine crop assets and SeedData.
	Does NOT destroy Workspace art — moves Flarevine* display models to
	Workspace.FlarevineDisplay_backup.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local function moveToBackup(inst: Instance)
	local backup = workspace:FindFirstChild("FlarevineDisplay_backup")
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "FlarevineDisplay_backup"
		backup.Parent = workspace
	end
	inst.Parent = backup
end

for _, child in workspace:GetChildren() do
	if child:IsA("Model") and string.find(child.Name, "Flarevine", 1, true) then
		moveToBackup(child)
		print("[RevertFlarevine] Moved to backup:", child.Name)
	end
end

local seedData = ReplicatedStorage.Modules.SeedData
local seedFolder = seedData:FindFirstChild("Flarevine Seed")
if seedFolder then
	seedFolder:Destroy()
	print("[RevertFlarevine] Removed SeedData Flarevine Seed")
end

if seedData:IsA("ModuleScript") then
	local src = seedData.Source
	local patched = src:gsub('\n\t\t"Flarevine Seed",', "")
	if patched ~= src then
		seedData.Source = patched
		print("[RevertFlarevine] Removed Flarevine Seed from seedOrder")
	end
end

local plants = ReplicatedStorage.Assets.Plants
local plant = plants:FindFirstChild("Flarevine")
if plant then
	plant:Destroy()
	print("[RevertFlarevine] Removed Assets.Plants.Flarevine")
end

local crops = ReplicatedStorage.Assets.Crops
local crop = crops:FindFirstChild("Flarevine")
if crop then
	crop:Destroy()
	print("[RevertFlarevine] Removed Assets.Crops.Flarevine")
end

local cropSeeds = ServerStorage:FindFirstChild("CropSeeds")
if cropSeeds then
	local tool = cropSeeds:FindFirstChild("Flarevine Seed")
	if tool then
		tool:Destroy()
		print("[RevertFlarevine] Removed ServerStorage crop seed tool")
	end
end

local seedModels = ReplicatedStorage:FindFirstChild("SeedModels")
if seedModels then
	local sm = seedModels:FindFirstChild("Flarevine Seed")
	if sm then
		sm:Destroy()
		print("[RevertFlarevine] Removed SeedModels preview")
	end
end

local eb = ReplicatedStorage.Modules:FindFirstChild("EconomyBalance")
if eb and eb:IsA("ModuleScript") then
	local src = eb.Source
	local patched = src:gsub("\n\t%[\"Flarevine Seed\"%] = {[^}]-},", "")
	if patched ~= src then
		eb.Source = patched
		print("[RevertFlarevine] Removed Flarevine from EconomyBalance (Studio copy)")
	end
end

print("[RevertFlarevine] Done. Sync EconomyBalance from Rojo. Workspace art is in FlarevineDisplay_backup.")
