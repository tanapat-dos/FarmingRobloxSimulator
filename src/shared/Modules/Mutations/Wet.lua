--[[
	Wet mutation (environmental, applied by WeatherService during rain).
	Sell value: x2 (see GetFruitValue environmentalMutations).

	Follows the same module API as Golden/Rainbow, but builds its drip
	effect procedurally so no baked .rbxl asset is required.
]]

local runService = game:GetService("RunService")

local EFFECT_NAME = "WetMutationEffect"

local mutationEffect = {}

local function buildEffect(): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = EFFECT_NAME

	local drips = Instance.new("ParticleEmitter")
	drips.Name = "Drips"
	drips.Color = ColorSequence.new(Color3.fromRGB(120, 175, 255))
	drips.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	drips.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	drips.Lifetime = NumberRange.new(0.7, 1.1)
	drips.Speed = NumberRange.new(0.5, 1.2)
	drips.Acceleration = Vector3.new(0, -8, 0)
	drips.EmissionDirection = Enum.NormalId.Bottom
	drips.SpreadAngle = Vector2.new(35, 35)
	drips.Rate = 6
	drips.LightEmission = 0.3
	drips.Parent = attachment

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
