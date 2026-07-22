--!strict
-- Normalizes mature crop height so different meshes read at similar scale in the garden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyBalance = require(script.Parent.EconomyBalance)

local PlantVisualScale = {}

local heightCache: { [string]: number } = {}

local function getPlantsFolder(): Folder
	return ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Plants") :: Folder
end

function PlantVisualScale.getFinalMeshName(cropName: string): string
	return "SM_" .. cropName:gsub(" ", "")
end

function PlantVisualScale.findFinalMesh(clientModel: Model, cropName: string): BasePart?
	local tagged = clientModel:FindFirstChild(PlantVisualScale.getFinalMeshName(cropName))
	if tagged and tagged:IsA("BasePart") then
		return tagged
	end

	local legacy = clientModel:FindFirstChild("SM_" .. cropName)
	if legacy and legacy:IsA("BasePart") then
		return legacy
	end

	return nil
end

local function measureMatureHeightStuds(cropName: string): number?
	if heightCache[cropName] then
		return heightCache[cropName]
	end

	local plantFolder = getPlantsFolder():FindFirstChild(cropName)
	local clientModel = plantFolder and plantFolder:FindFirstChild("ClientModel")
	if not clientModel or not clientModel:IsA("Model") then
		return nil
	end

	local finalMesh = PlantVisualScale.findFinalMesh(clientModel, cropName)
	if finalMesh then
		local measureModel = Instance.new("Model")
		local clone = finalMesh:Clone()
		clone.Anchored = true
		clone.Parent = measureModel
		measureModel.PrimaryPart = clone
		local _, size = measureModel:GetBoundingBox()
		measureModel:Destroy()
		if size.Y > 0.01 then
			heightCache[cropName] = size.Y
			return size.Y
		end
	end

	local temp = clientModel:Clone()
	temp:ScaleTo(1)
	local _, size = temp:GetBoundingBox()
	temp:Destroy()
	if size.Y > 0.01 then
		heightCache[cropName] = size.Y
		return size.Y
	end

	return nil
end

function PlantVisualScale.getHeightNormalizeFactor(cropName: string): number
	local display = EconomyBalance.PLANT_DISPLAY
	local target = display and display.targetMatureHeightStuds or 5.5
	local minFactor = display and display.minNormalizeFactor or 0.2
	local maxFactor = display and display.maxNormalizeFactor or 3.5

	local matureHeight = measureMatureHeightStuds(cropName)
	if not matureHeight then
		return 1
	end

	local factor = target / matureHeight
	factor = math.clamp(factor, minFactor, maxFactor)

	local overrides = display and display.cropHeightMultiplier
	if overrides then
		local cropMul = overrides[cropName]
		if typeof(cropMul) == "number" and cropMul > 0 then
			factor *= cropMul
		end
	end

	return factor
end

function PlantVisualScale.getWorldScale(cropName: string, plantSize: number): number
	local size = plantSize or 1
	return size * PlantVisualScale.getHeightNormalizeFactor(cropName)
end

function PlantVisualScale.clearCache()
	table.clear(heightCache)
end

return PlantVisualScale
