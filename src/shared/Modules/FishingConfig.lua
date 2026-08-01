--!strict
-- Shared fishing zones, fish loot, and Pangya-style swing-timing minigame tuning.

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

--[[
	Swing-timing minigame (Pangya-style): a marker sweeps back and forth across a 0..1 bar.
	The player gets up to MAX_ATTEMPTS presses per cast — press while the marker overlaps the
	catch zone to land the fish (dead-center of the zone = Perfect, better payout); miss every
	attempt, or never press before the timeout, and the fish gets away.

	TIMING / LATENCY (this was a real bug — do not "simplify" it back):
	The sweep is driven by `workspace:GetServerTimeNow()`, which is the SAME synchronised clock
	on the server and on every client. The server sends the cast's absolute `startedAt` in that
	clock domain, so both sides place the marker at an identical position at any real instant.

	The first version instead called `os.clock()` independently on each side and set the
	client's `startedAt` when the "startMinigame" message ARRIVED. That made the client's sweep
	lag the server's by the full round-trip time, so the server scored presses against a marker
	position the player never saw. The marker crosses the bar in SWEEP_PERIOD_SECONDS/2 seconds,
	so at 100 ms RTT the two sides disagreed by ~12.5% of the bar — wider than the Perfect
	window, which made Perfect unreachable and turned visually-centered hits into misses for
	anyone without a LAN-grade connection.

	The shared clock removes the download half of that error. What remains is only the UPSTREAM
	travel time of the press, which the server subtracts via Player:GetNetworkPing() (see
	PING_COMPENSATION_FACTOR); PRESS_LATENCY_FORGIVENESS absorbs the leftover jitter.
]]
FishingConfig.MINIGAME = {
	CAST_COOLDOWN = 2.5,
	SESSION_TIMEOUT = 6, -- seconds the player has to press before the fish escapes
	SWEEP_PERIOD_SECONDS = 1.6, -- time for one full 0 -> 1 -> 0 sweep
	MAX_ATTEMPTS = 3, -- presses allowed per cast; miss all 3 and the fish escapes
	-- Catch zone width is randomized per cast (fraction of the 0..1 bar) so it can't be
	-- memorized; narrower zones are simply harder, not tied to fish rarity.
	ZONE_WIDTH_MIN = 0.16,
	ZONE_WIDTH_MAX = 0.26,
	-- Fraction of the zone's width, centered, that counts as a Perfect hit.
	PERFECT_ZONE_FRACTION = 0.4,
	PERFECT_PAYOUT_MULTIPLIER = 1.35,
	--[[
		Player:GetNetworkPing() reports roughly ONE-WAY latency, and a press only travels one
		way (client -> server), so the default factor is 1. If playtesting shows hits still
		registering late, raise toward 2 (i.e. treat the reading as round-trip); if they
		register early, lower it. Compensation is clamped by PING_COMPENSATION_MAX so an absurd
		ping reading can never rewind the marker far enough to guarantee a hit.
	]]
	PING_COMPENSATION_FACTOR = 1,
	PING_COMPENSATION_MAX = 0.35,
	-- Slack added to the zone bounds when validating a press, absorbing the residual ping
	-- jitter that the compensation above cannot perfectly cancel.
	PRESS_LATENCY_FORGIVENESS = 0.05,
	-- Tight bounds: must stand on bridge / fishing rocks (see STAND_TAG).
	STAND_MARGIN = 3,
	STAND_VERTICAL_REACH = 14,
	FLOOR_RAYCAST_DEPTH = 22,
	-- Per-player throttle for the client's periodic "refreshZone" request, so a modified
	-- client can't spam the raycast + stand-registry scan that handler performs.
	ZONE_REFRESH_MIN_INTERVAL = 0.5,
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

--[[
	The clock the sweep is measured against. GetServerTimeNow() is synchronised between the
	server and every client, so both sides derive the same marker position for the same real
	instant. Both the client renderer and the server's press validation MUST use this — see the
	latency note on MINIGAME above for why using per-side clocks broke the minigame.
]]
function FishingConfig.now(): number
	return workspace:GetServerTimeNow()
end

-- Deterministic 0 -> 1 -> 0 -> ... triangle wave, so client and server compute the exact
-- same marker position from (elapsed time, period) without any network sync.
function FishingConfig.getMarkerPosition(elapsedSeconds: number, periodSeconds: number): number
	if periodSeconds <= 0 then
		return 0
	end
	-- Map elapsed time onto a 0..2 sawtooth, then fold the 1..2 half back down to 1..0.
	local t = (elapsedSeconds % periodSeconds) / periodSeconds * 2
	if t <= 1 then
		return t
	end
	return 2 - t
end

-- Rolls a random catch zone [min, max] within the 0..1 bar, sized between
-- ZONE_WIDTH_MIN and ZONE_WIDTH_MAX, fully inside the bar.
function FishingConfig.rollCatchZone(): (number, number)
	local cfg = FishingConfig.MINIGAME
	local width = math.random() * (cfg.ZONE_WIDTH_MAX - cfg.ZONE_WIDTH_MIN) + cfg.ZONE_WIDTH_MIN
	local center = math.random() * (1 - width) + width / 2
	return math.clamp(center - width / 2, 0, 1), math.clamp(center + width / 2, 0, 1)
end

-- Returns (hit, perfect) for a press at `markerPosition` against zone [zoneMin, zoneMax].
-- `forgiveness` widens the zone bounds slightly to absorb client/server latency.
function FishingConfig.evaluatePress(
	markerPosition: number,
	zoneMin: number,
	zoneMax: number,
	forgiveness: number?
): (boolean, boolean)
	local slack = forgiveness or 0
	local hit = markerPosition >= (zoneMin - slack) and markerPosition <= (zoneMax + slack)
	if not hit then
		return false, false
	end

	local zoneCenter = (zoneMin + zoneMax) / 2
	local zoneWidth = math.max(0.0001, zoneMax - zoneMin)
	local perfectHalfWidth = (zoneWidth * FishingConfig.MINIGAME.PERFECT_ZONE_FRACTION) / 2
	local perfect = math.abs(markerPosition - zoneCenter) <= perfectHalfWidth
	return true, perfect
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
