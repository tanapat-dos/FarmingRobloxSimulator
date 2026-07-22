--[[
	RESTORE BUBBLE RASH DISPLAY MODELS
	Paste into Studio Command Bar and press Enter.

	Rebuilds all 3 friend art stages as top-level Workspace models
	(left → right on the baseplate row). Does not modify playable crop assets.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CROP_NAME = "Bubble Rash"

-- Original friend row on the green baseplate (Z ~ 173). Wider spacing so all 3 read clearly.
local DISPLAY_STAGES = {
	{ name = "Bubble Rash Sprout", filter = "_Seed_", pos = Vector3.new(-210, 41, 173) },
	{ name = "Bubble Rash Early Growth", filter = "_Stage1_", pos = Vector3.new(-195, 41, 173) },
	{ name = "Bubble Rash Harvest", filter = "SM_BubbleRash_Meshes", pos = Vector3.new(-180, 41, 173) },
}

local clientModel = ReplicatedStorage.Assets.Plants[CROP_NAME].ClientModel

local function matchesStage(mesh: MeshPart, filter: string): boolean
	if filter == "SM_BubbleRash_Meshes" then
		return string.find(mesh.Name, filter, 1, true) ~= nil
	end
	return string.find(mesh.Name, filter, 1, true) ~= nil
end

local function clearOldDisplayModels()
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and (
			child.Name:find("Bubble Rash", 1, true)
			or child:GetAttribute("BubbleRashDisplay") == true
		) then
			child:Destroy()
		end
	end

	local folder = workspace:FindFirstChild("BubbleRashDisplay")
	if folder then
		folder:Destroy()
	end
end

local function buildStageModel(stageName: string, filter: string, targetPos: Vector3): Model?
	local model = Instance.new("Model")
	model.Name = stageName
	model:SetAttribute("BubbleRashDisplay", true)

	for _, mesh in clientModel:GetDescendants() do
		if mesh:IsA("MeshPart") and matchesStage(mesh, filter) then
			local clone = mesh:Clone()
			clone.Anchored = true
			clone.CanCollide = false
			clone.Transparency = 0
			clone:SetAttribute("AppearPercentage", nil)
			clone:SetAttribute("HideAtPercentage", nil)
			clone.Parent = model
		end
	end

	local partCount = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			partCount += 1
		end
	end
	if partCount == 0 then
		model:Destroy()
		return nil
	end

	local cf, size = model:GetBoundingBox()
	local bottomY = cf.Position.Y - size.Y / 2
	local offset = targetPos - Vector3.new(cf.Position.X, bottomY, cf.Position.Z)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = part.CFrame + offset
		end
	end

	local placedCF, placedSize = model:GetBoundingBox()
	local primary = Instance.new("Part")
	primary.Name = "PrimaryPart"
	primary.Size = Vector3.new(0.1, 0.1, 0.1)
	primary.Anchored = true
	primary.CanCollide = false
	primary.Transparency = 1
	primary.CFrame = CFrame.new(placedCF.Position.X, placedCF.Position.Y - placedSize.Y / 2, placedCF.Position.Z)
	primary.Parent = model
	model.PrimaryPart = primary
	model.Parent = workspace

	return model
end

clearOldDisplayModels()

local created = 0
for _, stage in DISPLAY_STAGES do
	if buildStageModel(stage.name, stage.filter, stage.pos) then
		created += 1
	end
end

print(string.format("[BubbleRash] Restored %d/%d display models on the baseplate row.", created, #DISPLAY_STAGES))
