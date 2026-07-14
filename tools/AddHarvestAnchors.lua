--[[
	Add HarvestAnchor parts to pack crop ServerModels.
	Run in Studio Command Bar after IntegrateCrops (or anytime anchors are missing).
]]

local plantsFolder = game.ReplicatedStorage.Assets.Plants

for _, plantFolder in plantsFolder:GetChildren() do
	if not plantFolder:IsA("Folder") then
		continue
	end

	local cropName = plantFolder.Name
	local clientModel = plantFolder:FindFirstChild("ClientModel")
	local serverModel = plantFolder:FindFirstChild("ServerModel")
	if not clientModel or not serverModel then
		continue
	end

	local old = serverModel:FindFirstChild("HarvestAnchor")
	if old then
		old:Destroy()
	end

	local anchor = Instance.new("Part")
	anchor.Name = "HarvestAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1

	local finalMesh = clientModel:FindFirstChild("SM_" .. cropName)
	if finalMesh and finalMesh:IsA("BasePart") then
		local anchorY = finalMesh.Position.Y + finalMesh.Size.Y * 0.35
		anchor.CFrame = CFrame.new(0, anchorY, 0)
	else
		local cf, size = clientModel:GetBoundingBox()
		anchor.CFrame = serverModel:GetPivot():ToObjectSpace(
			CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.35, 0))
		)
	end

	anchor.Parent = serverModel

	print("[HarvestAnchor] Added to", cropName)
end

print("[HarvestAnchor] Done.")
