-- Shared snippet for Command Bar integrate scripts (paste this block or require via Install).
local function requirePlantStageIntegrate(ReplicatedStorage)
	local modules = ReplicatedStorage:WaitForChild("Modules")
	local modScript = modules:FindFirstChild("PlantStageIntegrate")
	if not modScript or not modScript:IsA("ModuleScript") then
		error(
			"ReplicatedStorage.Modules.PlantStageIntegrate is missing. "
				.. "Paste & run tools/PlantStageIntegrateInstall.lua once, or sync Rojo."
		)
	end
	return require(modScript)
end

return requirePlantStageIntegrate
