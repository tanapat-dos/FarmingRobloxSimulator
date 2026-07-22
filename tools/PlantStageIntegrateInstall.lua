--[[
	Creates/updates ReplicatedStorage.Modules.PlantStageIntegrate (no Rojo required).
	Paste into Studio Command Bar once, then run IntegrateCrystalBlooms / BubbleRash / Mango.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ReplicatedStorage:WaitForChild("Modules")

local SOURCE = [==[
-- Helpers for Studio integrate scripts: build ClientModel growth stages without duplicate mature meshes.

local PlantStageIntegrate = {}

function PlantStageIntegrate.getModelGroundOffset(sourceModel)
	local bbCF, bbSize = sourceModel:GetBoundingBox()
	local groundY = bbCF.Position.Y - bbSize.Y / 2
	return Vector3.new(bbCF.Position.X, groundY, bbCF.Position.Z)
end

function PlantStageIntegrate.harvestMeshIdSet(harvestModel)
	local set = {}
	for _, inst in harvestModel:GetDescendants() do
		if inst:IsA("MeshPart") and inst.MeshId ~= "" then
			set[inst.MeshId] = true
		end
	end
	return set
end

function PlantStageIntegrate.findClientPartsByMeshId(clientModel, meshId)
	local out = {}
	if meshId == "" then
		return out
	end
	for _, desc in clientModel:GetDescendants() do
		if desc:IsA("MeshPart") and desc.MeshId == meshId then
			table.insert(out, desc)
		end
	end
	return out
end

local function applyStageAttributes(clone, stage)
	clone:SetAttribute("AppearPercentage", stage.appear)
	if stage.hideAt ~= nil then
		clone:SetAttribute("HideAtPercentage", stage.hideAt)
	end
end

function PlantStageIntegrate.addEarlyStageMeshes(
	clientModel,
	sourceModel,
	stage,
	harvestIds,
	addedMeshIds,
	shouldExclude
)
	local groundOffset = PlantStageIntegrate.getModelGroundOffset(sourceModel)

	for _, mesh in sourceModel:GetDescendants() do
		if mesh:IsA("MeshPart") then
			if shouldExclude and shouldExclude(mesh) then
				continue
			end
			if harvestIds[mesh.MeshId] then
				continue
			end
			if mesh.MeshId ~= "" and addedMeshIds[mesh.MeshId] then
				continue
			end

			local clone = mesh:Clone()
			clone.Name = stage.meshTag .. "_" .. mesh.Name
			clone.CFrame = mesh.CFrame - groundOffset
			clone.Anchored = true
			clone.CanCollide = false
			clone.CastShadow = false
			applyStageAttributes(clone, stage)
			clone.Parent = clientModel

			if mesh.MeshId ~= "" then
				addedMeshIds[mesh.MeshId] = true
			end
		end
	end
end

function PlantStageIntegrate.addMatureStageMeshes(
	clientModel,
	matureModel,
	stage,
	harvestIds,
	addedMeshIds,
	shouldExclude
)
	local groundOffset = PlantStageIntegrate.getModelGroundOffset(matureModel)

	for _, mesh in matureModel:GetDescendants() do
		if mesh:IsA("MeshPart") then
			if shouldExclude and shouldExclude(mesh) then
				continue
			end
			if harvestIds[mesh.MeshId] then
				continue
			end

			local meshId = mesh.MeshId
			if meshId ~= "" and addedMeshIds[meshId] then
				for _, part in PlantStageIntegrate.findClientPartsByMeshId(clientModel, meshId) do
					part:SetAttribute("HideAtPercentage", nil)
				end
				continue
			end

			local clone = mesh:Clone()
			clone.Name = stage.meshTag .. "_" .. mesh.Name
			clone.CFrame = mesh.CFrame - groundOffset
			clone.Anchored = true
			clone.CanCollide = false
			clone.CastShadow = false
			applyStageAttributes(clone, stage)
			clone.Parent = clientModel

			if meshId ~= "" then
				addedMeshIds[meshId] = true
			end
		end
	end
end

function PlantStageIntegrate.addThreeGrowthStages(
	clientModel,
	sproutModel,
	growingModel,
	matureModel,
	harvestModel,
	stages,
	shouldExclude
)
	local harvestIds = PlantStageIntegrate.harvestMeshIdSet(harvestModel)
	local addedMeshIds = {}

	PlantStageIntegrate.addEarlyStageMeshes(clientModel, sproutModel, stages[1], harvestIds, addedMeshIds, shouldExclude)
	PlantStageIntegrate.addEarlyStageMeshes(clientModel, growingModel, stages[2], harvestIds, addedMeshIds, shouldExclude)
	PlantStageIntegrate.addMatureStageMeshes(clientModel, matureModel, stages[3], harvestIds, addedMeshIds, shouldExclude)
end

return PlantStageIntegrate
]==]

local mod = modules:FindFirstChild("PlantStageIntegrate")
if not mod then
	mod = Instance.new("ModuleScript")
	mod.Name = "PlantStageIntegrate"
	mod.Parent = modules
end
mod.Source = SOURCE
print("[PlantStageIntegrateInstall] Ready at ReplicatedStorage.Modules.PlantStageIntegrate — save place (Ctrl+S).")
