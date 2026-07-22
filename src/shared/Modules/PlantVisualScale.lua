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
	local prefix = PlantVisualScale.getFinalMeshName(cropName) .. "_"
	local best: BasePart? = nil
	local bestVolume = 0

	for _, desc in clientModel:GetDescendants() do
		if desc:IsA("BasePart") and string.sub(desc.Name, 1, #prefix) == prefix then
			local vol = desc.Size.X * desc.Size.Y * desc.Size.Z
			if vol > bestVolume then
				bestVolume = vol
				best = desc
			end
		end
	end
	if best then
		return best
	end

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

local function getTargetHeightStuds(cropName: string): number
	local display = EconomyBalance.PLANT_DISPLAY
	local perCrop = display and display.cropTargetHeightStuds
	if perCrop then
		local h = perCrop[cropName]
		if typeof(h) == "number" and h > 0 then
			return h
		end
	end
	return display and display.targetMatureHeightStuds or 5.5
end

local function collectPartsForHeightMeasure(clientModel: Model): { BasePart }
	local parts: { BasePart } = {}
	local maxAppear: number? = nil

	for _, desc in clientModel:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name ~= "PrimaryPart" then
			local ap = desc:GetAttribute("AppearPercentage")
			if typeof(ap) == "number" then
				maxAppear = if maxAppear == nil then ap else math.max(maxAppear, ap)
			end
		end
	end

	if maxAppear ~= nil then
		for _, desc in clientModel:GetDescendants() do
			if desc:IsA("BasePart") and desc:GetAttribute("AppearPercentage") == maxAppear then
				table.insert(parts, desc)
			end
		end
		return parts
	end

	for _, desc in clientModel:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name ~= "PrimaryPart" then
			if desc:IsA("MeshPart") or desc.Size.Magnitude > 0.12 then
				table.insert(parts, desc)
			end
		end
	end
	return parts
end

local function boundingHeightFromParts(parts: { BasePart }): number?
	if #parts == 0 then
		return nil
	end

	local measureModel = Instance.new("Model")
	for _, part in parts do
		local clone = part:Clone()
		clone.Anchored = true
		clone.Parent = measureModel
	end
	measureModel:ScaleTo(1)
	local _, size = measureModel:GetBoundingBox()
	measureModel:Destroy()
	if size.Y > 0.01 then
		return size.Y
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

	local temp = clientModel:Clone()
	for _, child in temp:GetChildren() do
		if string.sub(child.Name, 1, 6) == "fruit_" then
			child:Destroy()
		end
	end

	local parts = collectPartsForHeightMeasure(temp)
	local height = boundingHeightFromParts(parts)
	temp:Destroy()

	if height then
		heightCache[cropName] = height
		return height
	end

	return nil
end

function PlantVisualScale.getHeightNormalizeFactor(cropName: string): number
	local display = EconomyBalance.PLANT_DISPLAY
	local target = getTargetHeightStuds(cropName)
	local minFactor = display and display.minNormalizeFactor or 0.2
	local maxFactor = display and display.maxNormalizeFactor or 2.25

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

function PlantVisualScale.getFruitDisplayScale(cropName: string): number
	local display = EconomyBalance.PLANT_DISPLAY
	local overrides = display and display.cropFruitDisplayScale
	if overrides then
		local mul = overrides[cropName]
		if typeof(mul) == "number" and mul > 0 then
			return mul
		end
	end
	return 1
end

-- Scale for fruit Tool in backpack / character (not garden plant scale).
function PlantVisualScale.getHeldToolScale(cropName: string, fruitWeight: number): number
	local display = EconomyBalance.PLANT_DISPLAY
	local base = display and display.heldToolBaseScale or 0.48
	local weight = math.max(0.01, fruitWeight)

	local cropMul = 1
	local heldOverrides = display and display.cropHeldToolScale
	if heldOverrides then
		local override = heldOverrides[cropName]
		if typeof(override) == "number" and override > 0 then
			cropMul = override
		end
	end

	return weight * base * cropMul * PlantVisualScale.getFruitDisplayScale(cropName)
end

function PlantVisualScale.getWorldScale(cropName: string, plantSize: number): number
	local size = plantSize or 1
	return size * PlantVisualScale.getHeightNormalizeFactor(cropName)
end

function PlantVisualScale.clearCache()
	table.clear(heightCache)
end

return PlantVisualScale
