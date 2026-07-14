--[[
	Hide leftover FarmCrops pack meshes from Workspace.
	Paste into Studio Command Bar and press Enter.

	Moves all Workspace SM_* MeshParts into ServerStorage.FarmCropsSource
	so they no longer appear in the middle of the map.
	Integration scripts still find meshes there when rebuilding plants.
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
	if child:IsA("MeshPart") and child.Name:match("^SM_") then
		child.Anchored = true
		child.CanCollide = false
		child.Parent = source
		moved += 1
	end
end

print("[HideWorkspaceCropMeshes] Moved", moved, "meshes to", source:GetFullName())
