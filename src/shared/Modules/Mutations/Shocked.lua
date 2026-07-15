--[[
	Shocked mutation (environmental, applied by WeatherService during
	thunderstorms). Sell value: x8 (see GetFruitValue environmentalMutations).

	Follows the same module API as Golden/Rainbow, built procedurally.
]]

local runService = game:GetService("RunService")

local EFFECT_NAME = "ShockedMutationEffect"

local mutationEffect = {}

local function buildEffect(): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = EFFECT_NAME

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 210)),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	sparks.Lifetime = NumberRange.new(0.25, 0.5)
	sparks.Speed = NumberRange.new(2.5, 4.5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 12
	sparks.LightEmission = 1
	sparks.Parent = attachment

	local light = Instance.new("PointLight")
	light.Name = "SparkLight"
	light.Color = Color3.fromRGB(255, 244, 150)
	light.Brightness = 0.7
	light.Range = 6
	light.Parent = attachment

	return attachment
end

local function applyToPart(part: BasePart?)
	if part and not part:FindFirstChild(EFFECT_NAME) then
		buildEffect().Parent = part
	end
end

local function removeFromModel(model: Instance)
	for _, v in model:GetDescendants() do
		if v:IsA("Attachment") and v.Name == EFFECT_NAME then
			v:Destroy()
		end
	end
end

function mutationEffect.applyToolEffect(tool: Tool)
	if not runService:IsServer() then return end
	task.spawn(function()
		applyToPart(tool:FindFirstChild("Handle"))
	end)
end

function mutationEffect.applyEffect(clientModel: Model, seed_data: Folder, serverFruitPart)
	if seed_data.MultiHarvest.Value then
		local fruitModel = clientModel:FindFirstChild("fruit_" .. tostring(serverFruitPart.Name))
		if fruitModel then
			applyToPart(fruitModel.PrimaryPart)
		end
	else
		applyToPart(clientModel.PrimaryPart)
	end
end

function mutationEffect.removeEffect(clientModel: Model, seed_data: Folder, serverFruitPart)
	task.spawn(function()
		if seed_data.MultiHarvest.Value then
			local found = clientModel:FindFirstChild("fruit_" .. serverFruitPart.Name)
			if found then
				removeFromModel(found)
			end
		else
			removeFromModel(clientModel)
		end
	end)
end

return mutationEffect
