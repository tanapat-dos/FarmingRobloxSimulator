--!strict
-- Client-safe helpers for showing saltwater fish meshes in ViewportFrames.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishingModelPreview = {}

local function getFishModelsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	return assets:FindFirstChild("FishModels") :: Folder?
end

local function stripScripts(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function wrapMesh(source: Instance): Model?
	local model = Instance.new("Model")
	model.Name = "FishPreview"

	if source:IsA("MeshPart") or source:IsA("BasePart") then
		local clone = source:Clone()
		clone.Anchored = true
		clone.CanCollide = false
		clone.Parent = model
		model.PrimaryPart = clone
	elseif source:IsA("Model") then
		local clone = source:Clone()
		clone.Parent = model
		stripScripts(clone)
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		return clone
	else
		model:Destroy()
		return nil
	end

	stripScripts(model)
	return model
end

function FishingModelPreview.getSource(modelName: string): Instance?
	local folder = getFishModelsFolder()
	if not folder then
		return nil
	end
	return folder:FindFirstChild(modelName)
end

function FishingModelPreview.mount(viewport: ViewportFrame, modelName: string): Model?
	viewport:ClearAllChildren()

	local source = FishingModelPreview.getSource(modelName)
	if not source then
		return nil
	end

	local model = wrapMesh(source)
	if not model or not model.PrimaryPart then
		return nil
	end

	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Name = "FishPreviewCamera"
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local cf, size = model:GetBoundingBox()
	local center = cf.Position
	local distance = math.max(size.X, size.Y, size.Z) * 0.9 + 1.2
	camera.CFrame = CFrame.new(center + Vector3.new(distance * 0.35, size.Y * 0.15, distance), center)

	return model
end

return FishingModelPreview
