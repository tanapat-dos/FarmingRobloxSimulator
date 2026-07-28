--!strict
--[[
	FishingService — server-authoritative canal fishing with a Pangya-style swing-timing
	minigame.

	Client flow:
	  1. Player enters a tagged FishingZone and presses F to cast.
	  2. Server picks the target fish, rolls a catch zone, and opens the timing session.
	  3. A marker sweeps back and forth across a bar; player presses F ONCE when it overlaps
	     the catch zone.
	  4. Server independently recomputes the marker position from its own clock and validates
	     the press. Landing inside the zone catches the fish (dead-center = Perfect payout);
	     missing, or never pressing before the timeout, lets the fish get away.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishingConfig = require(ReplicatedStorage:WaitForChild("Modules").FishingConfig)
local FishingStandRegistry = require(ReplicatedStorage:WaitForChild("Modules").FishingStandRegistry)

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

type FishingSession = {
	id: string,
	zoneId: string,
	fishId: string,
	startedAt: number,
	expiresAt: number,
	period: number,
	zoneMin: number,
	zoneMax: number,
	resolved: boolean,
}

local Service = {}

local activeSessions: { [Player]: FishingSession } = {}
local lastCastAt: { [Player]: number } = {}

local function ensureRemote(name: string): RemoteEvent
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote :: RemoteEvent
end

local fishingRemote = ensureRemote("Fishing")

local function notify(player: Player, message: string, kind: string?)
	local notifyRemote = remotes:FindFirstChild("Notify")
	if notifyRemote then
		notifyRemote:FireClient(player, message, kind or "info")
	end
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getZoneAtPosition(position: Vector3): FishingConfig.FishingZoneDef?
	local stands = FishingStandRegistry.collectStandParts()
	return FishingConfig.resolveZoneAtPosition(position, stands)
end

local function getPlayerZone(player: Player): FishingConfig.FishingZoneDef?
	local root = getRoot(player)
	if not root then
		return nil
	end
	return getZoneAtPosition(root.Position)
end

local function clearSession(player: Player)
	activeSessions[player] = nil
end

local function buildSession(zoneId: string, fishId: string): FishingSession
	local cfg = FishingConfig.MINIGAME
	local now = os.clock()
	local zoneMin, zoneMax = FishingConfig.rollCatchZone()

	return {
		id = HttpService:GenerateGUID(false),
		zoneId = zoneId,
		fishId = fishId,
		startedAt = now,
		expiresAt = now + cfg.SESSION_TIMEOUT,
		period = cfg.SWEEP_PERIOD_SECONDS,
		zoneMin = zoneMin,
		zoneMax = zoneMax,
		resolved = false,
	}
end

local function awardCatch(player: Player, session: FishingSession, perfect: boolean)
	local zone = getPlayerZone(player)
	if not zone or zone.id ~= session.zoneId then
		fishingRemote:FireClient(player, "result", { success = false, msg = "You moved too far from the water." })
		return
	end

	local fish = FishingConfig.getFishById(session.fishId)
	if not fish then
		fishingRemote:FireClient(player, "result", { success = false, msg = "Nothing bit this time." })
		return
	end

	local moneyService = cachedModules.Cache.MoneyService
	local dataService = cachedModules.Cache.DataService
	local payout = fish.value
	if perfect then
		payout = math.floor(payout * FishingConfig.MINIGAME.PERFECT_PAYOUT_MULTIPLIER)
	end
	local paid = moneyService.giveMoney(player, payout)

	-- Fish Coins: secondary currency for the Fish Coin Shop, scaled off the
	-- same base fish value (not the cash-boosted payout) so friend/pet/rebirth
	-- multipliers don't inflate it.
	local coinPayout = math.ceil(fish.value / 10)
	if perfect then
		coinPayout = math.ceil(coinPayout * FishingConfig.MINIGAME.PERFECT_PAYOUT_MULTIPLIER)
	end
	local coinsAwarded = moneyService.giveFishCoins(player, coinPayout)

	local data = dataService.getData(player)
	if data then
		data.FishingStats = data.FishingStats or { TotalCaught = 0, PerfectCasts = 0 }
		data.FishingStats.TotalCaught += 1
		if perfect then
			data.FishingStats.PerfectCasts += 1
		end
	end

	local msg = if perfect
		then `Perfect reel! Caught a {fish.displayName} (+${paid}, +🐟{coinsAwarded})`
		else `Caught a {fish.displayName} (+${paid}, +🐟{coinsAwarded})`

	fishingRemote:FireClient(player, "result", {
		success = true,
		perfect = perfect,
		fishId = fish.id,
		fishName = fish.displayName,
		reward = paid,
		fishCoins = coinsAwarded,
		msg = msg,
	})
	notify(player, msg, "success")
end

local function pushZoneState(player: Player)
	local zone = getPlayerZone(player)
	fishingRemote:FireClient(player, "zone", {
		inZone = zone ~= nil,
		zoneId = zone and zone.id or nil,
		displayName = zone and zone.displayName or nil,
	})
end

local function startCast(player: Player)
	if player:GetAttribute("DataLoaded") ~= true then
		notify(player, "Still loading your save data. Try again in a moment.", "error")
		return
	end

	if activeSessions[player] then
		notify(player, "Finish your current cast first.", "error")
		return
	end

	local zone = getPlayerZone(player)
	if not zone then
		notify(player, "Stand on the bridge or a fishing rock to cast.", "error")
		return
	end

	local now = os.clock()
	local lastCast = lastCastAt[player] or 0
	if now - lastCast < FishingConfig.MINIGAME.CAST_COOLDOWN then
		notify(player, "Wait a moment before casting again.", "error")
		return
	end

	local fish = FishingConfig.rollFish(zone.id, false)
	if not fish then
		notify(player, "Nothing is biting here right now.", "error")
		return
	end

	local session = buildSession(zone.id, fish.id)
	activeSessions[player] = session
	lastCastAt[player] = now

	fishingRemote:FireClient(player, "startMinigame", {
		sessionId = session.id,
		zoneId = zone.id,
		displayName = zone.displayName,
		fishId = fish.id,
		fishName = fish.displayName,
		modelName = fish.modelName,
		timeout = FishingConfig.MINIGAME.SESSION_TIMEOUT,
		period = session.period,
		zoneMin = session.zoneMin,
		zoneMax = session.zoneMax,
	})
end

-- One press per session: player presses F when they see the marker overlapping the catch
-- zone. The server recomputes the marker's position from its OWN clock (never trusts a
-- client-sent position/progress value) and evaluates the hit.
local function registerPress(player: Player, sessionId: string)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	local session = activeSessions[player]
	if not session or session.id ~= sessionId then
		notify(player, "That cast expired. Try again.", "error")
		return
	end

	if session.resolved then
		return
	end

	local now = os.clock()
	if now > session.expiresAt then
		clearSession(player)
		fishingRemote:FireClient(player, "result", { success = false, msg = "Too slow! The fish got away." })
		return
	end

	local zone = getPlayerZone(player)
	if not zone or zone.id ~= session.zoneId then
		clearSession(player)
		fishingRemote:FireClient(player, "result", { success = false, msg = "You moved too far from the water." })
		return
	end

	session.resolved = true

	local elapsed = now - session.startedAt
	local markerPosition = FishingConfig.getMarkerPosition(elapsed, session.period)
	local hit, perfect = FishingConfig.evaluatePress(
		markerPosition,
		session.zoneMin,
		session.zoneMax,
		FishingConfig.MINIGAME.PRESS_LATENCY_FORGIVENESS
	)

	clearSession(player)

	if not hit then
		fishingRemote:FireClient(player, "result", { success = false, msg = "Missed the timing! The fish got away." })
		return
	end

	awardCatch(player, session, perfect)
end

local function failSession(player: Player, session: FishingSession, message: string)
	clearSession(player)
	fishingRemote:FireClient(player, "result", { success = false, msg = message })
end

local function cancelCast(player: Player, sessionId: string)
	local session = activeSessions[player]
	if session and session.id == sessionId then
		failSession(player, session, "Cast cancelled.")
	end
end

function Service.init()
	FishingStandRegistry.ensureRegistered()

	fishingRemote.OnServerEvent:Connect(function(player: Player, action: string, payload: any)
		if typeof(action) ~= "string" then
			return
		end

		if action == "start" then
			startCast(player)
		elseif action == "press" then
			local sessionId = payload and payload.sessionId
			if typeof(sessionId) == "string" then
				registerPress(player, sessionId)
			end
		elseif action == "cancel" then
			local sessionId = payload and payload.sessionId
			if typeof(sessionId) == "string" then
				cancelCast(player, sessionId)
			end
		elseif action == "refreshZone" then
			pushZoneState(player)
		end
	end)

	for _, player in Players:GetPlayers() do
		task.defer(pushZoneState, player)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.delay(0.5, pushZoneState, player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearSession(player)
		lastCastAt[player] = nil
	end)

	-- Sessions no longer stream per-frame progress (the marker sweep is fully deterministic
	-- from startedAt+period, computed independently on both sides), so this loop only needs
	-- to expire casts the player never pressed for.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for player, session in activeSessions do
				if now > session.expiresAt then
					failSession(player, session, "The fish got away.")
				end
			end
		end
	end)
end

return Service
