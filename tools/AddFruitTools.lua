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
	"Pumpkin", "Tomato", "Grape", "Pineapple", "Bubble Rash", "Crystal Blooms", "Mango",
}

local function cropMeshPrefix(cropName: string): string
	return "SM_" .. cropName:gsub(" ", "")
end

local LEGACY_ONLY = { "Cacao", "Blueberry" }

local function findFinalMeshes(cropName: string): { MeshPart }
	local meshName = "SM_" .. cropName
	local prefix = cropMeshPrefix(cropName)

	if farmCropsSource then
		local stored = farmCropsSource:FindFirstChild(meshName)
		if stored and stored:IsA("MeshPart") then
			return { stored }
		end
	end

	local workspaceMesh = workspace:FindFirstChild(meshName)
	if workspaceMesh and workspaceMesh:IsA("MeshPart") then
		return { workspaceMesh }
	end

	local clientModel = plantsFolder:FindFirstChild(cropName)
		and plantsFolder[cropName]:FindFirstChild("ClientModel")
	if not clientModel then
		return {}
	end

	local direct = clientModel:FindFirstChild(meshName)
	if direct and direct:IsA("MeshPart") then
		return { direct }
	end

	local finals: { MeshPart } = {}
	for _, descendant in clientModel:GetDescendants() do
		if descendant:IsA("MeshPart")
			and string.find(descendant.Name, prefix .. "_", 1, true)
			and not string.find(descendant.Name, "_Seed_", 1, true)
			and not string.find(descendant.Name, "_Stage1_", 1, true)
			and not string.find(descendant.Name, "_Stage2_", 1, true)
			and not string.find(descendant.Name, "_Stage3_", 1, true)
			and not string.find(descendant.Name, "_Stage4_", 1, true)
		then
			table.insert(finals, descendant)
		end
	end

	return finals
end

local function createFruitTool(cropName: string, finalMeshes: { MeshPart })
	local existing = cropsFolder:FindFirstChild(cropName)
	if existing then
		existing:Destroy()
	end

	if #finalMeshes == 0 then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = cropName
	tool.RequiresHandle = true
	tool.CanBeDropped = true

	local handle: BasePart
	if #finalMeshes == 1 then
		handle = finalMeshes[1]:Clone()
	else
		local temp = Instance.new("Model")
		for _, mesh in finalMeshes do
			local clone = mesh:Clone()
			clone.Parent = temp
		end
		local center = temp:GetBoundingBox().Position
		temp:Destroy()

		handle = finalMeshes[1]:Clone()
		handle.CFrame = handle.CFrame - center

		for index = 2, #finalMeshes do
			local clone = finalMeshes[index]:Clone()
			clone.Anchored = false
			clone.CanCollide = false
			clone.Massless = true
			clone.CFrame = clone.CFrame - center
			clone.Parent = tool

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = clone
			weld.Parent = handle
		end
	end

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
	local finalMeshes = findFinalMeshes(cropName)
	if #finalMeshes == 0 then
		warn("[AddFruitTools] Missing final mesh for: " .. cropName)
		continue
	end

	createFruitTool(cropName, finalMeshes)
	ok += 1
end

print(string.format("[AddFruitTools] Done — %d/%d fruit tools.", ok, #CROPS))
