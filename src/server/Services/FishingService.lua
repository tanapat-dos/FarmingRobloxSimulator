--!strict
--[[
	FishingService — server-authoritative canal fishing with a mash-F reel minigame.

	Client flow:
	  1. Player enters a tagged FishingZone and presses F to cast.
	  2. Server picks the target fish, validates zone + cooldown, and opens the reel session.
	  3. Player spams F to fill the reel bar before the fish escapes.
	  4. Server validates each tap and awards cash for the pre-rolled fish on success.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishingConfig = require(ReplicatedStorage:WaitForChild("Modules").FishingConfig)

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

type FishingSession = {
	id: string,
	zoneId: string,
	fishId: string,
	progress: number,
	startedAt: number,
	expiresAt: number,
	lastProgressAt: number,
	lastTapAt: number,
	tapCount: number,
	tapsThisSecond: number,
	tapWindowStart: number,
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
	for _, part in CollectionService:GetTagged(FishingConfig.ZONE_TAG) do
		if part:IsA("BasePart") then
			local zoneId = part:GetAttribute("ZoneId")
			if typeof(zoneId) == "string" then
				local zone = FishingConfig.getZoneById(zoneId)
				if zone and FishingConfig.isPlayerNearZone(position, zone) then
					return zone
				end
			end
		end
	end

	for _, zone in FishingConfig.ZONES do
		if FishingConfig.isPlayerNearZone(position, zone) then
			return zone
		end
	end

	return nil
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

	return {
		id = HttpService:GenerateGUID(false),
		zoneId = zoneId,
		fishId = fishId,
		progress = 0,
		startedAt = now,
		expiresAt = now + cfg.SESSION_TIMEOUT,
		lastProgressAt = now,
		lastTapAt = 0,
		tapCount = 0,
		tapsThisSecond = 0,
		tapWindowStart = now,
	}
end

local function syncProgress(player: Player, session: FishingSession)
	fishingRemote:FireClient(player, "progress", {
		sessionId = session.id,
		progress = session.progress,
	})
end

local function awardCatch(player: Player, session: FishingSession)
	local zone = getPlayerZone(player)
	if not zone or zone.id ~= session.zoneId then
		fishingRemote:FireClient(player, "result", { success = false, msg = "You moved too far from the water." })
		return
	end

	local elapsed = os.clock() - session.startedAt
	local timeout = FishingConfig.MINIGAME.SESSION_TIMEOUT
	local perfect = FishingConfig.isPerfectCatch(elapsed, timeout)
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

	local data = dataService.getData(player)
	if data then
		data.FishingStats = data.FishingStats or { TotalCaught = 0, PerfectCasts = 0 }
		data.FishingStats.TotalCaught += 1
		if perfect then
			data.FishingStats.PerfectCasts += 1
		end
	end

	local msg = if perfect
		then `Perfect reel! Caught a {fish.displayName} (+${paid})`
		else `Caught a {fish.displayName} (+${paid})`

	fishingRemote:FireClient(player, "result", {
		success = true,
		perfect = perfect,
		fishId = fish.id,
		fishName = fish.displayName,
		reward = paid,
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
		notify(player, "Move closer to the canal to fish.", "error")
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
		progress = 0,
	})
end

local function updateSessionProgress(session: FishingSession, now: number)
	local elapsed = now - session.lastProgressAt
	session.progress = FishingConfig.applyDecay(session.progress, elapsed)
	session.lastProgressAt = now
end

local function registerTap(player: Player, sessionId: string)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	local session = activeSessions[player]
	if not session or session.id ~= sessionId then
		notify(player, "That cast expired. Try again.", "error")
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

	local cfg = FishingConfig.MINIGAME
	if session.lastTapAt > 0 and (now - session.lastTapAt) < cfg.MIN_TAP_INTERVAL then
		return
	end

	if now - session.tapWindowStart >= 1 then
		session.tapWindowStart = now
		session.tapsThisSecond = 0
	end
	if session.tapsThisSecond >= cfg.MAX_TAPS_PER_SECOND then
		return
	end

	updateSessionProgress(session, now)

	session.progress = FishingConfig.applyTap(session.progress)
	session.lastTapAt = now
	session.tapCount += 1
	session.tapsThisSecond += 1

	syncProgress(player, session)

	if session.progress >= 1 then
		clearSession(player)
		awardCatch(player, session)
	end
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
	fishingRemote.OnServerEvent:Connect(function(player: Player, action: string, payload: any)
		if typeof(action) ~= "string" then
			return
		end

		if action == "start" then
			startCast(player)
		elseif action == "tap" then
			local sessionId = payload and payload.sessionId
			if typeof(sessionId) == "string" then
				registerTap(player, sessionId)
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

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for player, session in activeSessions do
				if now > session.expiresAt then
					failSession(player, session, "The fish got away.")
				else
					local previousProgress = session.progress
					updateSessionProgress(session, now)
					if session.progress ~= previousProgress then
						syncProgress(player, session)
					end
				end
			end
		end
	end)
end

return Service
