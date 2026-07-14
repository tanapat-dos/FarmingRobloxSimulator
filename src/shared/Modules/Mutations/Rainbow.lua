local runService = game:GetService("RunService")

local mutationEffect = {}

function mutationEffect.applyToolEffect(tool: Tool)
	if not runService:IsServer() then return end
	task.spawn(function()
		script.Part.RainbowEffect:Clone().Parent = tool.Handle
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
				script.Part.RainbowEffect:Clone().Parent = parent
			end
		end
	else
		script.Part.RainbowEffect:Clone().Parent = clientModel.PrimaryPart
	end
end

return mutationEffect
