--!strict
-- Client-safe VFX for per-harvest rarity.
-- Highlight + PointLight + RarityAuras sparkler (matches legacy crop harvest glow).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeedRarity = require(script.Parent.SeedRarity)
local HarvestRarityConfig = require(script.Parent.HarvestRarityConfig)

local HarvestRarityEffects = {}

local AURA_ATTACHMENT_NAME = "HarvestRarityAura"

local cachedAuraTemplate: Attachment? = nil

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

local function getAuraTemplate(): Attachment?
	if cachedAuraTemplate then
		return cachedAuraTemplate
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local aurasFolder = assets and assets:FindFirstChild("RarityAuras")
	local generic = aurasFolder and aurasFolder:FindFirstChild("Generic")
	if generic and generic:IsA("Attachment") then
		cachedAuraTemplate = generic
		return generic
	end

	return nil
end

local function tintParticleColor(emitter: ParticleEmitter, color: Color3)
	local highlight = Color3.new(
		math.min(1, color.R + 0.2),
		math.min(1, color.G + 0.2),
		math.min(1, color.B + 0.2)
	)
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, highlight),
	})
end

local function removeAuraFromRoot(root: Instance)
	for _, desc in root:GetDescendants() do
		if desc:IsA("Attachment") and desc.Name == AURA_ATTACHMENT_NAME then
			desc:Destroy()
		end
	end
end

local function applySparklerAura(host: BasePart, color: Color3, rateScale: number)
	local existing = host:FindFirstChild(AURA_ATTACHMENT_NAME)
	if existing then
		existing:Destroy()
	end

	local template = getAuraTemplate()
	if not template then
		return
	end

	local aura = template:Clone()
	aura.Name = AURA_ATTACHMENT_NAME

	for _, desc in aura:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			tintParticleColor(desc, color)
			desc.Rate *= rateScale
			desc.Enabled = true
		end
	end

	aura.Parent = host
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

	removeAuraFromRoot(root)
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

		local rateScale = 0.85 + glow.brightness * 0.35
		applySparklerAura(lightHost, color, rateScale)
	end
end

function HarvestRarityEffects.applyToTool(tool: Tool, rarity: string)
	HarvestRarityEffects.applyToTarget(tool, rarity)
end

function HarvestRarityEffects.applyToPlantModel(clientModel: Model, rarity: string)
	HarvestRarityEffects.applyToTarget(clientModel, rarity)
end

return HarvestRarityEffects
