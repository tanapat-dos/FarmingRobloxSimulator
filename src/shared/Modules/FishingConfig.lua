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
}

FishingConfig.ZONES = {
	{
		id = "CanalNorth",
		displayName = "Canal (North)",
		zoneType = "TerrainWater",
		center = Vector3.new(6, 41, -43.33333206176758),
		size = Vector3.new(92, 36, 45.33333206176758),
		sortOrder = 1,
	},
	{
		id = "CanalBridge",
		displayName = "Canal (Bridge)",
		zoneType = "TerrainWater",
		center = Vector3.new(6, 41, -2),
		size = Vector3.new(92, 36, 45.33333206176758),
		sortOrder = 2,
	},
	{
		id = "CanalSouth",
		displayName = "Canal (South)",
		zoneType = "TerrainWater",
		center = Vector3.new(6, 41, 39.33333206176758),
		size = Vector3.new(92, 36, 45.33333206176758),
		sortOrder = 3,
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
	CanalNorth = { "saupe", "blue_fish", "mullet" },
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
	local half = zone.size * 0.5
	local delta = point - zone.center
	local verticalAllowance = 8
	return math.abs(delta.X) <= half.X
		and math.abs(delta.Y) <= half.Y + verticalAllowance
		and math.abs(delta.Z) <= half.Z
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
