-- Client-safe VFX for per-harvest rarity.
-- Legacy brick-style glow: Highlight fill + PointLight on the existing mesh.
-- No separate aura model or ReplicatedStorage asset required.

local SeedRarity = require(script.Parent.SeedRarity)
local HarvestRarityConfig = require(script.Parent.HarvestRarityConfig)

local HarvestRarityEffects = {}

local function getRarityColor(rarity: string): Color3
	local style = SeedRarity[rarity]
	if typeof(style) == "Color3" then
		return style
	end
	if style then
		return Color3.fromRGB(255, 120, 255)
	end
	return Color3.fromRGB(200, 200, 200)
end

local function findEffectRoot(target: Instance): Model?
	if target:IsA("Tool") then
		return target
	end
	if target:IsA("Model") then
		return target
	end
	return target:FindFirstAncestorWhichIsA("Model")
end

local function getLightHost(target: Instance, root: Model): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Tool") then
		return target:FindFirstChild("Handle") :: BasePart?
	end
	return root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
end

function HarvestRarityEffects.removeFromTarget(target: Instance)
	local root = findEffectRoot(target)
	if not root then
		return
	end

	local highlight = root:FindFirstChild("HarvestRarityHighlight")
	if highlight then
		highlight:Destroy()
	end

	for _, desc in root:GetDescendants() do
		if desc.Name == "HarvestRarityLight" then
			desc:Destroy()
		end
	end
end

function HarvestRarityEffects.applyToTarget(target: Instance, rarity: string)
	if not rarity or rarity == "" or rarity == "Common" then
		HarvestRarityEffects.removeFromTarget(target)
		return
	end

	local glow = HarvestRarityConfig.getGlowSettings(rarity)
	if not glow then
		return
	end

	local root = findEffectRoot(target)
	if not root then
		return
	end

	HarvestRarityEffects.removeFromTarget(root)

	local color = getRarityColor(rarity)

	local highlight = Instance.new("Highlight")
	highlight.Name = "HarvestRarityHighlight"
	highlight.Adornee = root
	highlight.FillColor = color
	highlight.FillTransparency = glow.fillTransparency
	highlight.OutlineColor = color
	highlight.OutlineTransparency = glow.outlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = root

	local lightHost = getLightHost(target, root)
	if lightHost then
		local light = Instance.new("PointLight")
		light.Name = "HarvestRarityLight"
		light.Color = color
		light.Brightness = glow.brightness
		light.Range = glow.range
		light.Shadows = false
		light.Parent = lightHost
	end
end

function HarvestRarityEffects.applyToTool(tool: Tool, rarity: string)
	HarvestRarityEffects.applyToTarget(tool, rarity)
end

function HarvestRarityEffects.applyToPlantModel(clientModel: Model, rarity: string)
	HarvestRarityEffects.applyToTarget(clientModel, rarity)
end

return HarvestRarityEffects
