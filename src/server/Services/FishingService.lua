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
	attemptsUsed: number,
}

local Service = {}

local activeSessions: { [Player]: FishingSession } = {}
local lastCastAt: { [Player]: number } = {}
local lastZoneRefreshAt: { [Player]: number } = {}

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

local function buildSession(zoneId: string, fish: FishingConfig.FishDef): FishingSession
	local cfg = FishingConfig.MINIGAME
	-- Shared, client-synchronised clock (NOT os.clock) so the client renders the identical
	-- sweep. See the latency note on FishingConfig.MINIGAME.
	local now = FishingConfig.now()

	-- Difficulty scales with the fish's rarity: rarer fish get a narrower catch zone and a
	-- faster sweep, so the minigame itself telegraphs "this one's worth more, and harder."
	local difficulty = FishingConfig.getDifficultyForRarity(fish.rarity)
	local zoneMin, zoneMax = FishingConfig.rollCatchZone(difficulty.widthMul)
	local period = FishingConfig.getSweepPeriod(difficulty.speedMul)

	return {
		id = HttpService:GenerateGUID(false),
		zoneId = zoneId,
		fishId = fish.id,
		startedAt = now,
		expiresAt = now + cfg.SESSION_TIMEOUT,
		period = period,
		zoneMin = zoneMin,
		zoneMax = zoneMax,
		resolved = false,
		attemptsUsed = 0,
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
		modelName = fish.modelName,
		rarity = fish.rarity,
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

	local now = FishingConfig.now()
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

	local session = buildSession(zone.id, fish)
	activeSessions[player] = session
	lastCastAt[player] = now

	fishingRemote:FireClient(player, "startMinigame", {
		sessionId = session.id,
		zoneId = zone.id,
		displayName = zone.displayName,
		fishId = fish.id,
		fishName = fish.displayName,
		modelName = fish.modelName,
		rarity = fish.rarity,
		timeout = FishingConfig.MINIGAME.SESSION_TIMEOUT,
		period = session.period,
		zoneMin = session.zoneMin,
		zoneMax = session.zoneMax,
		maxAttempts = FishingConfig.MINIGAME.MAX_ATTEMPTS,
		-- Absolute start time on the shared GetServerTimeNow clock. The client anchors its
		-- sweep to THIS rather than to its own arrival time, so download latency can't offset
		-- the two sweeps relative to each other.
		startedAt = session.startedAt,
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

	local cfg = FishingConfig.MINIGAME
	local now = FishingConfig.now()
	if now > session.expiresAt then
		clearSession(player)
		local msg = "Too slow! The fish got away."
		fishingRemote:FireClient(player, "result", { success = false, msg = msg })
		notify(player, msg, "error")
		return
	end

	local zone = getPlayerZone(player)
	if not zone or zone.id ~= session.zoneId then
		clearSession(player)
		local msg = "You moved too far from the water."
		fishingRemote:FireClient(player, "result", { success = false, msg = msg })
		notify(player, msg, "error")
		return
	end

	session.attemptsUsed += 1

	--[[
		Rewind by the press's upstream travel time so the marker is evaluated where the player
		actually SAW it, not where it has since moved to. GetNetworkPing is measured by the
		server (a client cannot inflate it), and the result is clamped so even a wild reading
		can't rewind far enough to make a hit guaranteed.
	]]
	local pingCompensation = 0
	local okPing, pingSeconds = pcall(function()
		return player:GetNetworkPing()
	end)
	if okPing and typeof(pingSeconds) == "number" and pingSeconds > 0 then
		pingCompensation = math.clamp(pingSeconds * cfg.PING_COMPENSATION_FACTOR, 0, cfg.PING_COMPENSATION_MAX)
	end

	-- Never rewind past the start of the cast.
	local elapsed = math.max(0, (now - session.startedAt) - pingCompensation)
	local markerPosition = FishingConfig.getMarkerPosition(elapsed, session.period)
	local hit, perfect = FishingConfig.evaluatePress(
		markerPosition,
		session.zoneMin,
		session.zoneMax,
		cfg.PRESS_LATENCY_FORGIVENESS
	)

	if hit then
		session.resolved = true
		clearSession(player)
		awardCatch(player, session, perfect)
		return
	end

	-- Missed — check remaining attempts
	local remaining = cfg.MAX_ATTEMPTS - session.attemptsUsed
	if remaining <= 0 then
		session.resolved = true
		clearSession(player)
		local msg = "Missed all attempts! The fish got away."
		fishingRemote:FireClient(player, "result", { success = false, msg = msg })
		notify(player, msg, "error")
	else
		-- Tell the client how many attempts remain so it can update the UI. "miss" (not
		-- "result") — the client plays a quick shake/red-flash cue but keeps the minigame
		-- open, since the cast itself is still alive.
		fishingRemote:FireClient(player, "miss", {
			sessionId = session.id,
			attemptsLeft = remaining,
		})
	end
end

local function failSession(player: Player, session: FishingSession, message: string)
	clearSession(player)
	fishingRemote:FireClient(player, "result", { success = false, msg = message })
	notify(player, message, "error")
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
		elseif action == "timedOut" then
			--[[
				The client noticed the cast ran past its timeout and cleared its own UI. Retire
				the server session immediately instead of leaving it alive until the next 0.25s
				sweep of the expiry loop — otherwise the player can recast inside that gap and
				get a confusing "Finish your current cast first."
			]]
			local sessionId = payload and payload.sessionId
			local session = activeSessions[player]
			if typeof(sessionId) == "string" and session and session.id == sessionId then
				clearSession(player)
			end
		elseif action == "refreshZone" then
			-- Throttled: this handler raycasts and scans the stand registry, so an unmodified
			-- client's 1 Hz poll is fine but a spamming one must not be able to amplify it.
			local now = FishingConfig.now()
			local last = lastZoneRefreshAt[player] or 0
			if now - last < FishingConfig.MINIGAME.ZONE_REFRESH_MIN_INTERVAL then
				return
			end
			lastZoneRefreshAt[player] = now
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
		lastZoneRefreshAt[player] = nil
	end)

	-- Sessions no longer stream per-frame progress (the marker sweep is fully deterministic
	-- from startedAt+period, computed independently on both sides), so this loop only needs
	-- to expire casts the player never pressed for.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = FishingConfig.now()
			for player, session in activeSessions do
				if now > session.expiresAt then
					failSession(player, session, "The fish got away.")
				end
			end
		end
	end)
end

return Service
