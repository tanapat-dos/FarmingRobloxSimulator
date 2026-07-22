--!strict
-- Applies the shared seed bag mesh to seed tools (replaces legacy yellow brick Part).

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local SeedToolVisual = {}

SeedToolVisual.ASSET_ID = 16449117646

local cachedTemplate: Model? = nil

local function findModelRoot(asset: Instance): Model?
	if asset:IsA("Model") then
		return asset
	end
	local model = asset:FindFirstChildWhichIsA("Model", true)
	if model then
		return model
	end
	local mesh = asset:FindFirstChildWhichIsA("MeshPart", true)
	if mesh then
		local wrapper = Instance.new("Model")
		wrapper.Name = "SeedBagVisual"
		mesh.Parent = wrapper
		wrapper.PrimaryPart = mesh
		return wrapper
	end
	return nil
end

local function getTemplate(): Model?
	if cachedTemplate then
		return cachedTemplate
	end

	local stored = ServerStorage:FindFirstChild("SeedBagTemplate")
	if stored and stored:IsA("Model") then
		cachedTemplate = stored
		return cachedTemplate
	end

	local ok, asset = pcall(function()
		return InsertService:LoadAsset(SeedToolVisual.ASSET_ID)
	end)
	if not ok or not asset then
		warn("[SeedToolVisual] Failed to load seed bag asset:", asset)
		return nil
	end

	local root = findModelRoot(asset)
	if not root then
		asset:Destroy()
		warn("[SeedToolVisual] Seed bag asset has no usable model")
		return nil
	end

	local template = root:Clone()
	template.Name = "SeedBagTemplate"
	template.Parent = ServerStorage

	if not template.PrimaryPart then
		template.PrimaryPart = template:FindFirstChildWhichIsA("BasePart", true)
	end

	asset:Destroy()
	cachedTemplate = template
	return cachedTemplate
end

local function weldPartTo(part: BasePart, target: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
end

local function prepareVisual(root: Model, handle: BasePart)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end

	local primary = root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		return
	end

	root:PivotTo(handle.CFrame * CFrame.new(0, -0.15, 0))
	weldPartTo(primary, handle)

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= primary then
			weldPartTo(descendant, primary)
		end
	end
end

function SeedToolVisual.removeLegacyVisual(tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") and child ~= handle then
			child:Destroy()
		end
	end
end

function SeedToolVisual.apply(tool: Tool): boolean
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return false
	end

	if tool:FindFirstChild("SeedBagVisual") then
		return true
	end

	local template = getTemplate()
	if not template then
		return false
	end

	SeedToolVisual.removeLegacyVisual(tool)

	local visual = template:Clone()
	visual.Name = "SeedBagVisual"
	visual.Parent = tool
	prepareVisual(visual, handle)

	return true
end

return SeedToolVisual
