--!strict
-- Client-safe VFX for per-harvest rarity (no Highlight outline — mesh sheen + soft light + sparkler).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SeedRarity = require(script.Parent.SeedRarity)
local HarvestRarityConfig = require(script.Parent.HarvestRarityConfig)

local HarvestRarityEffects = {}

local AURA_ATTACHMENT_NAME = "HarvestRarityAura"
local LEGACY_HIGHLIGHT_NAME = "HarvestRarityHighlight"
local LIGHT_NAME = "HarvestRarityLight"
local PULSE_TWEEN_NAME = "HarvestRarityPulseTween"

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

local function clearMeshSheen(root: Instance)
	for _, desc in root:GetDescendants() do
		if desc:IsA("BasePart") then
			local r = desc:GetAttribute("HarvestOrigColorR")
			if typeof(r) == "number" then
				local g = desc:GetAttribute("HarvestOrigColorG")
				local b = desc:GetAttribute("HarvestOrigColorB")
				if typeof(g) == "number" and typeof(b) == "number" then
					desc.Color = Color3.new(r, g, b)
				end
				local refl = desc:GetAttribute("HarvestOrigReflectance")
				if typeof(refl) == "number" then
					desc.Reflectance = refl
				end
			end
			desc:SetAttribute("HarvestOrigColorR", nil)
			desc:SetAttribute("HarvestOrigColorG", nil)
			desc:SetAttribute("HarvestOrigColorB", nil)
			desc:SetAttribute("HarvestOrigReflectance", nil)
		end
	end
end

local function applyMeshSheen(root: Instance, rarity: string, accent: Color3)
	local meshSettings = HarvestRarityConfig.getMeshSettings(rarity)
	if not meshSettings then
		return
	end

	local tint = meshSettings.colorTint or 0
	local reflectance = meshSettings.reflectance or 0

	for _, desc in root:GetDescendants() do
		if desc:IsA("BasePart") then
			if desc:GetAttribute("HarvestOrigColorR") == nil then
				desc:SetAttribute("HarvestOrigColorR", desc.Color.R)
				desc:SetAttribute("HarvestOrigColorG", desc.Color.G)
				desc:SetAttribute("HarvestOrigColorB", desc.Color.B)
				desc:SetAttribute("HarvestOrigReflectance", desc.Reflectance)
			end
			local orig = Color3.new(
				desc:GetAttribute("HarvestOrigColorR") :: number,
				desc:GetAttribute("HarvestOrigColorG") :: number,
				desc:GetAttribute("HarvestOrigColorB") :: number
			)
			desc.Color = orig:Lerp(accent, math.clamp(tint, 0, 1))
			desc.Reflectance = math.clamp(reflectance, 0, 1)
		end
	end
end

local function stopLightPulse(light: PointLight)
	local existing = light:FindFirstChild(PULSE_TWEEN_NAME)
	if existing then
		existing:Destroy()
	end
end

local function startLightPulse(light: PointLight, glow: { brightness: number, pulse: boolean? })
	if not glow.pulse then
		return
	end

	stopLightPulse(light)

	local base = glow.brightness
	local tweenInfo = TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local driver = Instance.new("NumberValue")
	driver.Name = PULSE_TWEEN_NAME
	driver.Value = base
	driver.Parent = light

	driver.Changed:Connect(function()
		light.Brightness = driver.Value
	end)

	TweenService:Create(driver, tweenInfo, { Value = base * 0.55 }):Play()
end

local function removeLegacyHighlight(root: Instance)
	local highlight = root:FindFirstChild(LEGACY_HIGHLIGHT_NAME)
	if highlight and highlight:IsA("Highlight") then
		highlight:Destroy()
	end
end

function HarvestRarityEffects.removeFromTarget(target: Instance)
	local root = findEffectRoot(target)
	if not root then
		return
	end

	removeLegacyHighlight(root)

	for _, desc in root:GetDescendants() do
		if desc:IsA("PointLight") and desc.Name == LIGHT_NAME then
			stopLightPulse(desc)
			desc:Destroy()
		end
	end

	removeAuraFromRoot(root)
	clearMeshSheen(root)
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
	applyMeshSheen(root, rarity, color)

	local lightHost = getLightHost(target, root)
	if lightHost then
		local light = Instance.new("PointLight")
		light.Name = LIGHT_NAME
		light.Color = color
		light.Brightness = glow.brightness
		light.Range = glow.range
		light.Shadows = false
		light.Parent = lightHost

		startLightPulse(light, glow)

		local sparklerScale = glow.sparklerScale or (0.85 + glow.brightness * 0.35)
		applySparklerAura(lightHost, color, sparklerScale)
	end
end

function HarvestRarityEffects.applyToTool(tool: Tool, rarity: string)
	HarvestRarityEffects.applyToTarget(tool, rarity)
end

function HarvestRarityEffects.applyToPlantModel(clientModel: Model, rarity: string)
	HarvestRarityEffects.applyToTarget(clientModel, rarity)
end

return HarvestRarityEffects
