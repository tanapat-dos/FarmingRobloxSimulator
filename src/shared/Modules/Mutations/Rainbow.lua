local runService = game:GetService("RunService")

local mutationEffect = {}

-- The particle template is a baked child (script.Part.RainbowEffect) that only
-- exists in the .rbxl ($ignoreUnknownInstances). Guard so a source-only build
-- degrades to "no sparkle" with one warning instead of erroring per call.
local warnedMissing = false
local function getEffectTemplate(): Instance?
	local part = script:FindFirstChild("Part")
	local template = part and part:FindFirstChild("RainbowEffect")
	if not template and not warnedMissing then
		warnedMissing = true
		warn("[Rainbow] Missing baked effect template script.Part.RainbowEffect")
	end
	return template
end

function mutationEffect.applyToolEffect(tool: Tool)
	if not runService:IsServer() then return end
	task.spawn(function()
		local template = getEffectTemplate()
		if template and tool:FindFirstChild("Handle") then
			template:Clone().Parent = tool.Handle
		end
	end)
end

function mutationEffect.removeEffect(clientModel: Model, seed_data: Folder, serverFruitPart)
	task.spawn(function()
		if seed_data.MultiHarvest.Value then
			local found = clientModel:FindFirstChild("fruit_"..serverFruitPart.Name)
			if found then
				for _,v in found:GetDescendants() do
					if v:IsA("Attachment") and v.Name == "RainbowEffect" then
						v:Destroy()
					end
				end
			end
		else
			for _,v in clientModel:GetDescendants() do
				if v:IsA("Attachment") and v.Name == "RainbowEffect" then
					v:Destroy()
				end
			end
		end
	end)
end

function mutationEffect.applyEffect(clientModel: Model, seed_data: Folder, serverFruitPart)
	if seed_data.MultiHarvest.Value then
		local fruitModel = clientModel:FindFirstChild("fruit_"..tostring(serverFruitPart.Name))
		if fruitModel then
			local parent = fruitModel.PrimaryPart
			if parent then
				local template = getEffectTemplate()
				if template then
					template:Clone().Parent = parent
				end
			end
		end
	else
		local template = getEffectTemplate()
		if template and clientModel.PrimaryPart then
			template:Clone().Parent = clientModel.PrimaryPart
		end
	end
end

return mutationEffect
