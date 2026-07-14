--!strict
--[[
	Moves leftover FarmCrops pack SM_* MeshParts from Workspace into
	ServerStorage.FarmCropsSource so they do not appear in the map center.
	Runs once on every server start (Studio and live).
--]]

local ServerStorage = game:GetService("ServerStorage")

local source = ServerStorage:FindFirstChild("FarmCropsSource")
if not source then
	source = Instance.new("Folder")
	source.Name = "FarmCropsSource"
	source.Parent = ServerStorage
end

local moved = 0
for _, child in workspace:GetChildren() do
	if child:IsA("MeshPart") and string.match(child.Name, "^SM_") then
		child.Anchored = true
		child.CanCollide = false
		child.Parent = source
		moved += 1
	end
end

if moved > 0 then
	print("[HideWorkspaceCropMeshes] Moved", moved, "pack meshes out of Workspace")
end
