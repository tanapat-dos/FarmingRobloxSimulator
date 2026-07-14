-- Command bar: normalize SeedPrefix to match crop folder names (Garlic, not garlic).
local seedDataModule = game.ReplicatedStorage.Modules.SeedData

for _, seedFolder in seedDataModule:GetChildren() do
	if not seedFolder:IsA("Folder") then
		continue
	end

	local cropName = seedFolder.Name:gsub(" Seed$", "")
	local seedPrefix = seedFolder:FindFirstChild("SeedPrefix")
	if seedPrefix then
		seedPrefix.Value = cropName
		print("[FixSeedPrefixes]", seedFolder.Name, "->", cropName)
	end
end

print("[FixSeedPrefixes] Done.")
