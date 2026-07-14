--[[
	ADD FRUIT TOOLS (harvested crop items)
	Paste into Studio's Command Bar and press Enter.

	Creates ReplicatedStorage.Assets.Crops/<CropName> Tool templates
	using the FarmCrops final mesh (SM_<Crop>) as the Handle visual.
	Replaces legacy brick fruit tools.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local farmCropsSource = ServerStorage:FindFirstChild("FarmCropsSource")
local cropsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Crops")
local plantsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Plants")

local CROPS = {
	"Carrot", "Wheat", "Beetroot", "Eggplant", "Potato", "Radish",
	"Strawberry", "Corn", "Garlic", "Lettuce", "Pepper",
	"Pumpkin", "Tomato", "Grape", "Pineapple",
}

local LEGACY_ONLY = { "Cacao", "Blueberry" }

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

	local clientModel = plantsFolder:FindFirstChild(cropName)
		and plantsFolder[cropName]:FindFirstChild("ClientModel")
	if clientModel then
		local mesh = clientModel:FindFirstChild("SM_" .. cropName)
		if mesh and mesh:IsA("MeshPart") then
			return mesh
		end
	end

	return nil
end

local function createFruitTool(cropName: string, finalMesh: MeshPart)
	local existing = cropsFolder:FindFirstChild(cropName)
	if existing then
		existing:Destroy()
	end

	local tool = Instance.new("Tool")
	tool.Name = cropName
	tool.RequiresHandle = true
	tool.CanBeDropped = true

	local handle = finalMesh:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Parent = tool

	tool.Grip = CFrame.new(0, -handle.Size.Y * 0.15, 0)
		* CFrame.Angles(math.rad(90), 0, 0)

	tool.Parent = cropsFolder
	print("[AddFruitTools] Created fruit tool: " .. cropName)
end

for _, legacyName in ipairs(LEGACY_ONLY) do
	local legacy = cropsFolder:FindFirstChild(legacyName)
	if legacy then
		legacy:Destroy()
		print("[AddFruitTools] Removed legacy fruit tool: " .. legacyName)
	end
end

local ok = 0
for _, cropName in ipairs(CROPS) do
	local finalMesh = findFinalMesh(cropName)
	if not finalMesh then
		warn("[AddFruitTools] Missing final mesh for: " .. cropName)
		continue
	end

	createFruitTool(cropName, finalMesh)
	ok += 1
end

print(string.format("[AddFruitTools] Done — %d/%d fruit tools.", ok, #CROPS))
