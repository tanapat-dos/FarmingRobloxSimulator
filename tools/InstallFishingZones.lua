-- Run in Studio Command Bar to recreate canal fishing zones.
-- Terrain water has no asset id; these invisible parts define fishable regions.

local CollectionService = game:GetService("CollectionService")

local existing = workspace:FindFirstChild("FishingZones")
if existing then
	existing:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "FishingZones"
folder.Parent = workspace

local function createZone(name: string, center: Vector3, size: Vector3, zoneId: string, displayName: string, sortOrder: number)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = true
	part.CanQuery = true
	part.Transparency = 1
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(0, 170, 255)
	part.Size = size
	part.CFrame = CFrame.new(center)
	part:SetAttribute("ZoneId", zoneId)
	part:SetAttribute("ZoneType", "TerrainWater")
	part:SetAttribute("DisplayName", displayName)
	part:SetAttribute("SortOrder", sortOrder)
	part.Parent = folder
	CollectionService:AddTag(part, "FishingZone")
end

local centerX, centerZ = 6, -2
local width, length = 92, 124
local surfaceY = 41
local zoneHeight = 36
local third = length / 3
local segmentSize = Vector3.new(width, zoneHeight, third + 4)

createZone("CanalNorth", Vector3.new(centerX, surfaceY, centerZ - third), segmentSize, "CanalNorth", "Canal (North)", 1)
createZone("CanalBridge", Vector3.new(centerX, surfaceY, centerZ), segmentSize, "CanalBridge", "Canal (Bridge)", 2)
createZone("CanalSouth", Vector3.new(centerX, surfaceY, centerZ + third), segmentSize, "CanalSouth", "Canal (South)", 3)

print("[InstallFishingZones] Created Workspace.FishingZones with 3 canal segments.")
