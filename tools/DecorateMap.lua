--[[
	MAP DECORATION — paste into Studio Command Bar and press Enter.

	The place has no decoration assets (World/Visuals is empty), so this
	builds everything procedurally:
	  - primitive trees (trunk + layered canopies), bushes, rocks
	  - flower patches with slow ambient "butterfly" particles
	  - decorative crop clusters cloned from Assets.Plants ClientModels
	All placement is seeded (re-run = same layout), raycast-snapped to the
	ground, and rejected near plots, shops, and spawns.

	Everything lives in workspace.MapDecor — re-running rebuilds it.
	Tune CONFIG and re-run until it feels right, then save the place.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	seed = 20260715,
	treeCount = 34,
	bushCount = 26,
	rockCount = 18,
	flowerPatchCount = 22,
	cropClusterCount = 10,
	ringInner = 12,   -- studs beyond the keep-out zones
	ringOuter = 85,   -- max distance from the map's landmark center
	keepOutMargin = 10,
}

local rng = Random.new(CONFIG.seed)

local old = workspace:FindFirstChild("MapDecor")
if old then
	old:Destroy()
end
local decorFolder = Instance.new("Folder")
decorFolder.Name = "MapDecor"
decorFolder.Parent = workspace

-- ------------------------------------------------------- placement helpers
local keepOut = {} -- { {position, radius} }
local landmarks = {}

local function addKeepOut(instance, radius)
	local ok, cf, size = pcall(function()
		if instance:IsA("Model") then
			return instance:GetBoundingBox()
		end
		return instance.CFrame, instance.Size
	end)
	if ok and cf then
		local r = radius or (math.max(size.X, size.Z) / 2 + CONFIG.keepOutMargin)
		table.insert(keepOut, { position = cf.Position, radius = r })
		table.insert(landmarks, cf.Position)
	end
end

local plots = workspace:FindFirstChild("Plots")
if plots then
	for _, plot in plots:GetChildren() do
		addKeepOut(plot)
	end
end
local shops = workspace:FindFirstChild("Shops")
if shops then
	for _, shop in shops:GetChildren() do
		addKeepOut(shop, 18)
	end
end
for _, name in { "OrderBoard", "RebirthAltar", "GearKiosk" } do
	local landmark = workspace:FindFirstChild(name)
	if landmark then
		addKeepOut(landmark, 10)
	end
end
for _, spawnLocation in workspace:GetDescendants() do
	if spawnLocation:IsA("SpawnLocation") then
		addKeepOut(spawnLocation, 16)
	end
end

if #landmarks == 0 then
	error("[DecorateMap] Found no plots/shops to anchor around — aborting.")
end

local center = Vector3.zero
for _, position in landmarks do
	center += position
end
center /= #landmarks

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { decorFolder,
	workspace:FindFirstChild("MapPolish") or decorFolder,
	workspace.World and workspace.World.Map and workspace.World.Map.PlantedSeeds or decorFolder }

local function groundAt(x: number, z: number): Vector3?
	local result = workspace:Raycast(Vector3.new(x, center.Y + 120, z), Vector3.new(0, -400, 0), rayParams)
	if result then
		return result.Position
	end
	return nil
end

local function pickSpot(): Vector3?
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(CONFIG.ringInner, CONFIG.ringOuter)
		local x = center.X + math.cos(angle) * distance
		local z = center.Z + math.sin(angle) * distance

		local blocked = false
		for _, zone in keepOut do
			local dx = x - zone.position.X
			local dz = z - zone.position.Z
			if dx * dx + dz * dz < zone.radius * zone.radius then
				blocked = true
				break
			end
		end

		if not blocked then
			local ground = groundAt(x, z)
			if ground then
				return ground
			end
		end
	end
	return nil
end

local function newPart(name, size, cframe, material, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent or decorFolder
	return part
end

-- ----------------------------------------------------------------- makers
local TRUNK = Color3.fromRGB(105, 78, 52)
local LEAF_COLORS = {
	Color3.fromRGB(88, 140, 74),
	Color3.fromRGB(76, 128, 66),
	Color3.fromRGB(102, 152, 80),
}

local function makeTree(position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = rng:NextNumber(7, 11)
	local trunkWidth = rng:NextNumber(1.1, 1.7)

	local trunk = newPart("Trunk", Vector3.new(trunkWidth, height, trunkWidth),
		CFrame.new(position + Vector3.new(0, height / 2, 0)), Enum.Material.Wood, TRUNK, model)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CFrame = trunk.CFrame * CFrame.Angles(0, 0, math.rad(90))

	local leafColor = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local canopyBase = position + Vector3.new(0, height, 0)
	for i = 1, 3 do
		local ballSize = rng:NextNumber(4.5, 6.5) - (i - 1) * 1.1
		local offset = Vector3.new(
			rng:NextNumber(-1.4, 1.4),
			(i - 1) * ballSize * 0.45,
			rng:NextNumber(-1.4, 1.4)
		)
		local ball = newPart("Canopy", Vector3.new(ballSize, ballSize * 0.85, ballSize),
			CFrame.new(canopyBase + offset), Enum.Material.Grass, leafColor, model)
		ball.Shape = Enum.PartType.Ball
		ball.CanCollide = false
	end

	model.Parent = decorFolder
end

local function makeBush(position: Vector3)
	local size = rng:NextNumber(2, 3.4)
	local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	for i = 1, rng:NextInteger(2, 3) do
		local ball = newPart("Bush", Vector3.new(size, size * 0.7, size),
			CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), size * 0.3, rng:NextNumber(-1, 1))),
			Enum.Material.Grass, color)
		ball.Shape = Enum.PartType.Ball
		ball.CanCollide = false
	end
end

local function makeRock(position: Vector3)
	local baseSize = rng:NextNumber(1.4, 3.2)
	local gray = rng:NextNumber(0.45, 0.62)
	for i = 1, rng:NextInteger(1, 3) do
		local size = baseSize * rng:NextNumber(0.5, 1)
		local rock = newPart("Rock", Vector3.new(size, size * 0.75, size),
			CFrame.new(position + Vector3.new(rng:NextNumber(-1.2, 1.2), size * 0.25, rng:NextNumber(-1.2, 1.2)))
				* CFrame.Angles(rng:NextNumber(0, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.4)),
			Enum.Material.Slate, Color3.new(gray, gray, gray + 0.03))
		rock.Shape = Enum.PartType.Ball
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(240, 120, 140),
	Color3.fromRGB(250, 200, 90),
	Color3.fromRGB(150, 130, 240),
	Color3.fromRGB(250, 250, 250),
}

local function makeFlowerPatch(position: Vector3)
	local patchColor = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for i = 1, rng:NextInteger(4, 7) do
		local offset = Vector3.new(rng:NextNumber(-2.4, 2.4), 0, rng:NextNumber(-2.4, 2.4))
		local stemHeight = rng:NextNumber(0.5, 0.9)
		newPart("Stem", Vector3.new(0.12, stemHeight, 0.12),
			CFrame.new(position + offset + Vector3.new(0, stemHeight / 2, 0)),
			Enum.Material.Grass, Color3.fromRGB(96, 140, 80))
		local bloom = newPart("Bloom", Vector3.new(0.36, 0.24, 0.36),
			CFrame.new(position + offset + Vector3.new(0, stemHeight + 0.1, 0)),
			Enum.Material.SmoothPlastic, patchColor)
		bloom.Shape = Enum.PartType.Ball
		bloom.CanCollide = false
	end

	-- ambient butterflies drifting over the patch
	local host = newPart("ButterflyHost", Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position + Vector3.new(0, 1.6, 0)), Enum.Material.SmoothPlastic, patchColor)
	host.Transparency = 1
	host.CanCollide = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(patchColor)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(1, 0.12),
	})
	emitter.Transparency = NumberSequence.new(0.25)
	emitter.Lifetime = NumberRange.new(2.5, 4)
	emitter.Speed = NumberRange.new(0.4, 0.9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0.6
	emitter.LightEmission = 0.25
	emitter.Parent = host
end

local plantsFolder = ReplicatedStorage:FindFirstChild("Assets")
	and ReplicatedStorage.Assets:FindFirstChild("Plants")

local function makeCropCluster(position: Vector3)
	if not plantsFolder then
		return false
	end
	local cropFolders = plantsFolder:GetChildren()
	if #cropFolders == 0 then
		return false
	end
	local cropFolder = cropFolders[rng:NextInteger(1, #cropFolders)]
	local clientModel = cropFolder:FindFirstChild("ClientModel")
	if not clientModel then
		return false
	end

	local cluster = Instance.new("Model")
	cluster.Name = "WildCrop_" .. cropFolder.Name
	for i = 1, rng:NextInteger(2, 4) do
		local clone = clientModel:Clone()
		clone.Name = tostring(i)
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			elseif descendant:IsA("ProximityPrompt") or descendant:IsA("Script")
				or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
				descendant:Destroy()
			end
		end
		clone:ScaleTo(rng:NextNumber(0.7, 1.05))
		local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local ground = groundAt(position.X + offset.X, position.Z + offset.Z) or position
		clone:PivotTo(CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		clone.Parent = cluster
	end
	cluster.Parent = decorFolder
	return true
end

-- ------------------------------------------------------------------ build
local placed = { Tree = 0, Bush = 0, Rock = 0, Flowers = 0, Crops = 0 }

local function scatter(count, key, maker)
	for _ = 1, count do
		local spot = pickSpot()
		if spot then
			local ok = maker(spot)
			if ok ~= false then
				placed[key] += 1
			end
		end
	end
end

scatter(CONFIG.treeCount, "Tree", makeTree)
scatter(CONFIG.bushCount, "Bush", makeBush)
scatter(CONFIG.rockCount, "Rock", makeRock)
scatter(CONFIG.flowerPatchCount, "Flowers", makeFlowerPatch)
scatter(CONFIG.cropClusterCount, "Crops", makeCropCluster)

print("================ MAP DECOR REPORT ================")
print(("Anchored around %d landmarks, center (%.0f, %.0f, %.0f)"):format(
	#landmarks, center.X, center.Y, center.Z))
for key, count in placed do
	print(("• %s: %d placed"):format(key, count))
end
print("Re-run any time — MapDecor rebuilds with the same seed. Save when happy.")
