--!strict
-- Shared fishing zones, fish loot, and mash-F reel minigame tuning.

export type FishingZoneDef = {
	id: string,
	displayName: string,
	zoneType: "TerrainWater",
	center: Vector3,
	size: Vector3,
	sortOrder: number,
}

export type FishDef = {
	id: string,
	displayName: string,
	modelName: string,
	value: number,
	weight: number,
}

local FishingConfig = {}

FishingConfig.ZONE_TAG = "FishingZone"
FishingConfig.STAND_TAG = "FishingStand"
FishingConfig.FISH_MODELS_FOLDER = "FishModels"

FishingConfig.MINIGAME = {
	PROGRESS_PER_TAP = 0.085,
	DECAY_PER_SECOND = 0.14,
	MIN_TAP_INTERVAL = 0.07,
	MAX_TAPS_PER_SECOND = 14,
	CAST_COOLDOWN = 2.5,
	SESSION_TIMEOUT = 10,
	PERFECT_TIME_REMAINING = 3,
	PERFECT_PAYOUT_MULTIPLIER = 1.35,
	MAX_DISTANCE_FROM_ZONE = 18,
	-- Tight bounds: must stand on bridge / fishing rocks (see STAND_TAG).
	STAND_MARGIN = 3,
	STAND_VERTICAL_REACH = 14,
	FLOOR_RAYCAST_DEPTH = 22,
}

FishingConfig.ZONES = {
	{
		id = "CanalFull",
		displayName = "Canal",
		zoneType = "TerrainWater",
		center = Vector3.new(6, 41, -20),
		size = Vector3.new(120, 44, 240),
		sortOrder = 1,
	},
	{
		id = "WaterfallPool",
		displayName = "Waterfall Pool",
		zoneType = "TerrainWater",
		center = Vector3.new(-17.5, 48, -229),
		size = Vector3.new(85, 55, 90),
		sortOrder = 2,
	},
} :: { FishingZoneDef }

-- Meshes live in ReplicatedStorage.Assets.FishModels (saltwater pack asset 10851288693).
FishingConfig.FISH = {
	{ id = "saupe", displayName = "Saupe Fish", modelName = "Saupe Fish", value = 20, weight = 45 },
	{ id = "blue_fish", displayName = "Blue Fish", modelName = "Blue Fish", value = 35, weight = 30 },
	{ id = "mullet", displayName = "Mullet", modelName = "Mullet", value = 55, weight = 18 },
	{ id = "cod", displayName = "Cod", modelName = "Cod", value = 80, weight = 7 },
	{ id = "red_snapper", displayName = "Red Snapper", modelName = "Red Snapper", value = 120, weight = 4 },
	{ id = "tuna", displayName = "Tuna", modelName = "Tuna", value = 150, weight = 3 },
} :: { FishDef }

FishingConfig.ZONE_FISH = {
	CanalFull = { "saupe", "blue_fish", "mullet", "cod", "red_snapper", "tuna" },
	WaterfallPool = { "mullet", "cod", "red_snapper", "tuna" },
	-- Legacy zone ids (old 3-part install) map to canal loot.
	CanalNorth = { "saupe", "blue_fish", "mullet", "cod" },
	CanalBridge = { "saupe", "blue_fish", "mullet", "cod", "red_snapper" },
	CanalSouth = { "mullet", "cod", "red_snapper", "tuna" },
}

function FishingConfig.getZoneById(zoneId: string): FishingZoneDef?
	for _, zone in FishingConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

function FishingConfig.isPointInZone(point: Vector3, zone: FishingZoneDef): boolean
	local half = zone.size * 0.5
	local delta = point - zone.center
	return math.abs(delta.X) <= half.X
		and math.abs(delta.Y) <= half.Y
		and math.abs(delta.Z) <= half.Z
end

function FishingConfig.isPlayerNearZone(point: Vector3, zone: FishingZoneDef): boolean
	return FishingConfig.isPointInZone(point, zone)
end

function FishingConfig.isPlayerOnStandPart(point: Vector3, part: BasePart): boolean
	local margin = FishingConfig.MINIGAME.STAND_MARGIN
	local verticalReach = FishingConfig.MINIGAME.STAND_VERTICAL_REACH
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	if math.abs(localPoint.X) > half.X + margin or math.abs(localPoint.Z) > half.Z + margin then
		return false
	end
	if localPoint.Y < -half.Y - 2 or localPoint.Y > half.Y + verticalReach then
		return false
	end
	return true
end

function FishingConfig.resolveZoneAtPosition(position: Vector3, standParts: { Instance }): FishingZoneDef?
	if #standParts == 0 then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = standParts

	local origin = position + Vector3.new(0, 1.5, 0)
	local direction = Vector3.new(0, -FishingConfig.MINIGAME.FLOOR_RAYCAST_DEPTH, 0)
	local hit = workspace:Raycast(origin, direction, params)
	if hit and hit.Instance:IsA("BasePart") then
		local zoneId = hit.Instance:GetAttribute("ZoneId")
		if typeof(zoneId) == "string" then
			local zone = FishingConfig.getZoneById(zoneId)
			if zone then
				return zone
			end
		end
	end

	local bestZone: FishingZoneDef? = nil
	local bestDistance = math.huge
	for _, inst in standParts do
		if inst:IsA("BasePart") and FishingConfig.isPlayerOnStandPart(position, inst) then
			local zoneId = inst:GetAttribute("ZoneId")
			if typeof(zoneId) == "string" then
				local zone = FishingConfig.getZoneById(zoneId)
				if zone then
					local distance = (inst.Position - position).Magnitude
					if distance < bestDistance then
						bestDistance = distance
						bestZone = zone
					end
				end
			end
		end
	end

	return bestZone
end

function FishingConfig.applyDecay(progress: number, elapsed: number): number
	if elapsed <= 0 then
		return progress
	end
	return math.max(0, progress - FishingConfig.MINIGAME.DECAY_PER_SECOND * elapsed)
end

function FishingConfig.applyTap(progress: number): number
	return math.min(1, progress + FishingConfig.MINIGAME.PROGRESS_PER_TAP)
end

function FishingConfig.isPerfectCatch(elapsed: number, timeout: number): boolean
	return (timeout - elapsed) >= FishingConfig.MINIGAME.PERFECT_TIME_REMAINING
end

function FishingConfig.getFishById(fishId: string): FishDef?
	for _, fish in FishingConfig.FISH do
		if fish.id == fishId then
			return fish
		end
	end
	return nil
end

function FishingConfig.rollFish(zoneId: string, perfect: boolean): FishDef?
	local pool = FishingConfig.ZONE_FISH[zoneId]
	if not pool then
		return nil
	end

	local entries: { { fish: FishDef, weight: number } } = {}
	local totalWeight = 0
	for _, fishId in pool do
		local fish = FishingConfig.getFishById(fishId)
		if fish then
			local weight = fish.weight
			if perfect and fish.id == "tuna" then
				weight *= 2
			elseif perfect then
				weight = math.floor(weight * 1.35)
			end
			totalWeight += weight
			table.insert(entries, { fish = fish, weight = weight })
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = math.random(1, totalWeight)
	local running = 0
	for _, entry in entries do
		running += entry.weight
		if roll <= running then
			return entry.fish
		end
	end

	return entries[#entries].fish
end

return FishingConfig
