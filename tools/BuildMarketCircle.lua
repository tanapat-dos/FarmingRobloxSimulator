--[[
	MARKET CIRCLE — paste into Studio Command Bar and press Enter.

	Rearranges the shopping zone into a circular market plaza:
	  - The four shop buildings (SeedShop, SellStuff, PetShop, GearShop)
	    move onto a circle facing the center, signs and NPCs riding along.
	  - Cobbled plaza disc, central fountain, lamp ring, benches, planters.
	  - Anchor parts (OrderBoardAnchor / GearKioskAnchor / RebirthAltarAnchor)
	    are placed in the N/E/W gaps so the runtime stands spawn inside the
	    market; the south gap stays open with a cobble path toward spawn.

	Decorative pieces live in workspace.MarketCircle (rebuilt on re-run);
	building moves target absolute positions, so re-running is safe.
	Run BEFORE PolishMap/DecorateMap so their keep-outs see the new layout.
	Save the place after running.
]]

local CONFIG = {
	center = Vector3.new(-13, 0, 150), -- Y is resolved from the ground
	buildingRadius = 26,
	standRadius = 21,
	plazaRadius = 32,
	lampRadius = 27,
	benchRadius = 16,
	planterRadius = 24,
	pathTo = Vector3.new(1, 0, 10), -- walkway toward spawn
}

local report = {}
local function log(line)
	table.insert(report, line)
end

local old = workspace:FindFirstChild("MarketCircle")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "MarketCircle"
folder.Parent = workspace

-- --------------------------------------------------------------- landmarks
local shops = workspace:FindFirstChild("Shops")
assert(shops, "[MarketCircle] workspace.Shops not found")

local BUILDINGS = {
	{ shop = "SeedShop", sign = "SeedShopSign", npc = "Buy", angle = 45 },
	{ shop = "PetShop", sign = "PetShopSign", npc = "PetNPC", angle = 135 },
	{ shop = "SellStuff", sign = "SellStuffSign", npc = "Sell", angle = 225 },
	{ shop = "GearShop", sign = "GearShopSign", npc = "Gear", angle = 315 },
}

-- ground height at the plaza center
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local exclude = { folder }
for _, entry in BUILDINGS do
	local model = shops:FindFirstChild(entry.shop)
	if model then
		table.insert(exclude, model)
	end
end
for _, name in { "MapDecor", "MapPolish", "OrderBoard", "RebirthAltar", "GearKiosk" } do
	local found = workspace:FindFirstChild(name)
	if found then
		table.insert(exclude, found)
	end
end
rayParams.FilterDescendantsInstances = exclude

local probe = workspace:Raycast(CONFIG.center + Vector3.new(0, 200, 0), Vector3.new(0, -500, 0), rayParams)
assert(probe, "[MarketCircle] could not find ground at the plaza center")
local groundY = probe.Position.Y
local center = Vector3.new(CONFIG.center.X, groundY, CONFIG.center.Z)
log(("Plaza center: (%.0f, %.1f, %.0f)"):format(center.X, groundY, center.Z))

local function ringPosition(radius: number, angleDeg: number): Vector3
	local a = math.rad(angleDeg)
	return center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

-- ---------------------------------------------------------- move buildings
local characters = shops:FindFirstChild("Characters")
for _, entry in BUILDINGS do
	local model = shops:FindFirstChild(entry.shop)
	if not model then
		log(("SKIP %s: model not found."):format(entry.shop))
		continue
	end

	local oldPivot = model:GetPivot()
	local targetPos = ringPosition(CONFIG.buildingRadius, entry.angle)
	targetPos = Vector3.new(targetPos.X, oldPivot.Position.Y, targetPos.Z)
	local lookTarget = Vector3.new(center.X, oldPivot.Position.Y, center.Z)
	local newPivot = CFrame.lookAt(targetPos, lookTarget)
	model:PivotTo(newPivot)

	-- sign rides along with its shop, keeping its relative placement
	local sign = shops:FindFirstChild(entry.sign)
	if sign then
		local rel = oldPivot:ToObjectSpace(sign:GetPivot())
		sign:PivotTo(newPivot * rel)
	end

	-- NPC: keep relative placement when it was near the shop, otherwise
	-- stand it 7 studs in front of the doorway facing outward
	local npc = characters and characters:FindFirstChild(entry.npc)
	if npc then
		local npcPivot = npc:GetPivot()
		local rel = oldPivot:ToObjectSpace(npcPivot)
		if rel.Position.Magnitude <= 30 then
			npc:PivotTo(newPivot * rel)
		else
			local spot = newPivot * CFrame.new(0, npcPivot.Position.Y - oldPivot.Position.Y, -7)
			npc:PivotTo(CFrame.lookAt(spot.Position,
				Vector3.new(center.X, spot.Position.Y, center.Z)))
		end
	end

	log(("Moved %s (+sign%s) to %d degrees."):format(
		entry.shop, npc and " +NPC" or "", entry.angle))
end

-- ------------------------------------------------------------ stand anchors
local STANDS = {
	{ name = "OrderBoardAnchor", angle = 90 },
	{ name = "GearKioskAnchor", angle = 0 },
	{ name = "RebirthAltarAnchor", angle = 180 },
}
for _, stand in STANDS do
	local existing = workspace:FindFirstChild(stand.name, true)
	if existing then
		existing:Destroy()
	end
	local anchor = Instance.new("Part")
	anchor.Name = stand.name
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	local pos = ringPosition(CONFIG.standRadius, stand.angle)
	anchor.CFrame = CFrame.lookAt(Vector3.new(pos.X, groundY, pos.Z),
		Vector3.new(center.X, groundY, center.Z))
	anchor.Parent = folder
end
log("Placed stand anchors at N/E/W; south gap left open toward spawn.")

-- ------------------------------------------------------------------ plaza
local function newPart(name, size, cframe, material, color, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

local plaza = newPart("PlazaDisc", Vector3.new(CONFIG.plazaRadius * 2, 0.35, CONFIG.plazaRadius * 2),
	CFrame.new(center + Vector3.new(0, 0.15, 0)), Enum.Material.Cobblestone, Color3.fromRGB(132, 126, 116))
plaza.Shape = Enum.PartType.Cylinder
plaza.CFrame = plaza.CFrame * CFrame.Angles(0, 0, math.rad(90))

-- fountain
local basin = newPart("FountainBasin", Vector3.new(10, 1.2, 10),
	CFrame.new(center + Vector3.new(0, 0.75, 0)), Enum.Material.Slate, Color3.fromRGB(96, 100, 110))
basin.Shape = Enum.PartType.Cylinder
basin.CFrame = basin.CFrame * CFrame.Angles(0, 0, math.rad(90))

local water = newPart("FountainWater", Vector3.new(8.6, 0.7, 8.6),
	CFrame.new(center + Vector3.new(0, 1.05, 0)), Enum.Material.Glass, Color3.fromRGB(120, 190, 235), false)
water.Shape = Enum.PartType.Cylinder
water.Transparency = 0.35
water.CFrame = water.CFrame * CFrame.Angles(0, 0, math.rad(90))

local column = newPart("FountainColumn", Vector3.new(1.4, 3.4, 1.4),
	CFrame.new(center + Vector3.new(0, 2.4, 0)), Enum.Material.Slate, Color3.fromRGB(104, 108, 120))
local crown = newPart("FountainCrown", Vector3.new(2, 0.9, 2),
	CFrame.new(center + Vector3.new(0, 4.35, 0)), Enum.Material.Slate, Color3.fromRGB(96, 100, 110))
crown.Shape = Enum.PartType.Ball
crown.CanCollide = false

local spray = Instance.new("ParticleEmitter")
spray.Color = ColorSequence.new(Color3.fromRGB(170, 215, 245))
spray.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.25),
	NumberSequenceKeypoint.new(1, 0.1),
})
spray.Transparency = NumberSequence.new(0.4)
spray.Lifetime = NumberRange.new(0.8, 1.2)
spray.Speed = NumberRange.new(7, 9)
spray.SpreadAngle = Vector2.new(14, 14)
spray.Acceleration = Vector3.new(0, -22, 0)
spray.Rate = 26
spray.LightEmission = 0.35
spray.Parent = crown

-- lamp ring (skips the south walkway gap)
local lampCount = 0
for angle = 0, 315, 45 do
	if angle ~= 270 then -- 270 degrees = south gap
		local pos = ringPosition(CONFIG.lampRadius, angle)
		newPart("LampPole", Vector3.new(0.5, 6.5, 0.5),
			CFrame.new(pos.X, groundY + 3.25, pos.Z), Enum.Material.Wood, Color3.fromRGB(105, 78, 52))
		local head = newPart("LampHead", Vector3.new(1, 1, 1),
			CFrame.new(pos.X, groundY + 6.9, pos.Z), Enum.Material.Neon, Color3.fromRGB(255, 214, 150), false)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 214, 150)
		light.Brightness = 1
		light.Range = 16
		light.Parent = head
		lampCount += 1
	end
end

-- benches facing the fountain
local benchCount = 0
for angle = 45, 315, 90 do
	local pos = ringPosition(CONFIG.benchRadius, angle)
	local cf = CFrame.lookAt(Vector3.new(pos.X, groundY, pos.Z),
		Vector3.new(center.X, groundY, center.Z))
	newPart("BenchSeat", Vector3.new(4, 0.35, 1.3), cf * CFrame.new(0, 1.05, 0),
		Enum.Material.WoodPlanks, Color3.fromRGB(124, 92, 60))
	newPart("BenchBack", Vector3.new(4, 1.2, 0.3), cf * CFrame.new(0, 1.8, 0.6),
		Enum.Material.WoodPlanks, Color3.fromRGB(124, 92, 60))
	for _, sideX in { -1.6, 1.6 } do
		newPart("BenchLeg", Vector3.new(0.35, 1, 1.1), cf * CFrame.new(sideX, 0.5, 0),
			Enum.Material.Wood, Color3.fromRGB(96, 70, 46))
	end
	benchCount += 1
end

-- planters between benches
local FLOWER_COLORS = {
	Color3.fromRGB(240, 120, 140),
	Color3.fromRGB(250, 200, 90),
	Color3.fromRGB(150, 130, 240),
}
local rng = Random.new(20260716)
local planterCount = 0
for angle = 22, 337, 45 do
	if angle < 250 or angle > 290 then -- keep the south gap clear
		local pos = ringPosition(CONFIG.planterRadius, angle)
		newPart("Planter", Vector3.new(2.2, 0.8, 2.2),
			CFrame.new(pos.X, groundY + 0.4, pos.Z), Enum.Material.Slate, Color3.fromRGB(110, 104, 96))
		local soil = newPart("PlanterSoil", Vector3.new(1.8, 0.3, 1.8),
			CFrame.new(pos.X, groundY + 0.85, pos.Z), Enum.Material.Ground, Color3.fromRGB(92, 68, 52), false)
		local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
		for _ = 1, 4 do
			local bloom = newPart("Bloom", Vector3.new(0.34, 0.24, 0.34),
				CFrame.new(pos.X + rng:NextNumber(-0.6, 0.6), groundY + 1.15, pos.Z + rng:NextNumber(-0.6, 0.6)),
				Enum.Material.SmoothPlastic, color, false)
			bloom.Shape = Enum.PartType.Ball
		end
		planterCount += 1
	end
end

-- walkway toward spawn
local from = Vector3.new(center.X, groundY, center.Z + CONFIG.plazaRadius)
local to = Vector3.new(CONFIG.pathTo.X, groundY, CONFIG.pathTo.Z)
local span = (to - from)
local steps = math.max(1, math.floor(span.Magnitude / 6))
for i = 0, steps do
	local pos = from + span * (i / steps)
	local look = CFrame.lookAt(pos, pos + span.Unit)
	newPart("Walkway", Vector3.new(6, 0.3, 6.6), look * CFrame.new(0, 0.12, 0),
		Enum.Material.Cobblestone, Color3.fromRGB(132, 126, 116))
end

log(("Plaza built: fountain, %d lamps, %d benches, %d planters, %d walkway slabs.")
	:format(lampCount, benchCount, planterCount, steps + 1))

print("================ MARKET CIRCLE REPORT ================")
for _, line in report do
	print("• " .. line)
end
print("Playtest, nudge CONFIG values and re-run if needed, then save the place.")
