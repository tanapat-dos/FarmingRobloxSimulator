--[[
	ADD SEED VIEWPORT MODELS
	Paste into Studio's Command Bar (View → Command Bar) and press Enter.

	Builds ReplicatedStorage.SeedModels previews from the FarmCrops pack
	final-stage mesh (SM_<Crop>). Replaces legacy brick previews.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local farmCropsSource = ServerStorage:FindFirstChild("FarmCropsSource")
local seedModels = ReplicatedStorage:WaitForChild("SeedModels")
local plantsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Plants")

local CROPS = {
	"Carrot", "Wheat", "Beetroot", "Eggplant", "Potato", "Radish",
	"Strawberry", "Corn", "Garlic", "Lettuce", "Pepper",
	"Pumpkin", "Tomato", "Grape", "Pineapple",
}

local function findFinalMesh(cropName: string): MeshPart?
	local meshName = "SM_" .. cropName
	if farmCropsSource then
		local stored = farmCropsSource:FindFirstChild(meshName)
		if stored and stored:IsA("MeshPart") then
			return stored
		end
	end
	local workspaceMesh = workspace:FindFirstChild(meshName)
	if workspaceMesh and workspaceMesh:IsA("MeshPart") then
		return workspaceMesh
	end

	local plantFolder = plantsFolder:FindFirstChild(cropName)
	local clientModel = plantFolder and plantFolder:FindFirstChild("ClientModel")
	if clientModel then
		local clientMesh = clientModel:FindFirstChild("SM_" .. cropName)
		if clientMesh and clientMesh:IsA("MeshPart") then
			return clientMesh
		end
	end

	return nil
end

local function isLegacyPreview(model: Model): boolean
	for _, child in model:GetChildren() do
		if child:IsA("MeshPart") then
			return false
		end
	end
	return true
end

local function createPreview(cropName: string, finalMesh: MeshPart)
	local seedModelName = cropName .. " Seed"
	local existing = seedModels:FindFirstChild(seedModelName)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = seedModelName

	local primaryPart = Instance.new("Part")
	primaryPart.Name = "PrimaryPart"
	primaryPart.Size = Vector3.new(0.1, 0.1, 0.1)
	primaryPart.Anchored = true
	primaryPart.CanCollide = false
	primaryPart.Transparency = 1
	primaryPart.CFrame = CFrame.new(0, 0, 0)
	primaryPart.Parent = model
	model.PrimaryPart = primaryPart

	local meshClone = finalMesh:Clone()
	meshClone.Anchored = true
	meshClone.CanCollide = false
	meshClone.CFrame = CFrame.new(0, meshClone.Size.Y / 2, 0)
	meshClone.Parent = model

	model.Parent = seedModels
	print("[AddSeedModels] Created preview: " .. seedModelName)
end

local ok = 0
for _, cropName in ipairs(CROPS) do
	local seedModelName = cropName .. " Seed"
	local existing = seedModels:FindFirstChild(seedModelName)
	if existing and not isLegacyPreview(existing) then
		print("[AddSeedModels] Already up to date – skipping: " .. seedModelName)
		ok += 1
		continue
	end

	local finalMesh = findFinalMesh(cropName)
	if not finalMesh then
		warn("[AddSeedModels] Missing final mesh for: " .. cropName)
		continue
	end

	createPreview(cropName, finalMesh)
	ok += 1
end

print(string.format("[AddSeedModels] Done — %d/%d crops.", ok, #CROPS))
