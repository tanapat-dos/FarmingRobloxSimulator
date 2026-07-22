--!strict
-- Helpers for Studio integrate scripts: build ClientModel growth stages without duplicate mature meshes.

export type StageDef = {
	meshTag: string,
	appear: number,
	hideAt: number?,
}

local PlantStageIntegrate = {}

function PlantStageIntegrate.getModelGroundOffset(sourceModel: Model): Vector3
	local bbCF, bbSize = sourceModel:GetBoundingBox()
	local groundY = bbCF.Position.Y - bbSize.Y / 2
	return Vector3.new(bbCF.Position.X, groundY, bbCF.Position.Z)
end

function PlantStageIntegrate.harvestMeshIdSet(harvestModel: Model): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, inst in harvestModel:GetDescendants() do
		if inst:IsA("MeshPart") and inst.MeshId ~= "" then
			set[inst.MeshId] = true
		end
	end
	return set
end

function PlantStageIntegrate.findClientPartsByMeshId(clientModel: Model, meshId: string): { MeshPart }
	local out: { MeshPart } = {}
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

local function applyStageAttributes(clone: MeshPart, stage: StageDef)
	clone:SetAttribute("AppearPercentage", stage.appear)
	if stage.hideAt ~= nil then
		clone:SetAttribute("HideAtPercentage", stage.hideAt)
	end
end

export type MeshFilter = (mesh: MeshPart) -> boolean

function PlantStageIntegrate.addEarlyStageMeshes(
	clientModel: Model,
	sourceModel: Model,
	stage: StageDef,
	harvestIds: { [string]: boolean },
	addedMeshIds: { [string]: boolean },
	shouldExclude: MeshFilter?
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

-- Final stage: skip harvest pickup meshes; reuse prior-stage MeshParts instead of cloning duplicates.
function PlantStageIntegrate.addMatureStageMeshes(
	clientModel: Model,
	matureModel: Model,
	stage: StageDef,
	harvestIds: { [string]: boolean },
	addedMeshIds: { [string]: boolean },
	shouldExclude: MeshFilter?
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
	clientModel: Model,
	sproutModel: Model,
	growingModel: Model,
	matureModel: Model,
	harvestModel: Model,
	stages: { StageDef },
	shouldExclude: MeshFilter?
)
	local harvestIds = PlantStageIntegrate.harvestMeshIdSet(harvestModel)
	local addedMeshIds: { [string]: boolean } = {}

	PlantStageIntegrate.addEarlyStageMeshes(clientModel, sproutModel, stages[1], harvestIds, addedMeshIds, shouldExclude)
	PlantStageIntegrate.addEarlyStageMeshes(clientModel, growingModel, stages[2], harvestIds, addedMeshIds, shouldExclude)
	PlantStageIntegrate.addMatureStageMeshes(clientModel, matureModel, stages[3], harvestIds, addedMeshIds, shouldExclude)
end

return PlantStageIntegrate
