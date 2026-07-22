--!strict
--[[
	DailyLoginService — 7-day streak daily login rewards.

	Rewards escalate over the 7-day streak; day 7 pays a Diamond bonus.
	After the 7th day the streak resets to day 1 (repeating cycle).
	Missing a day resets the streak.

	Data stored per player:
	  data.DailyLogin.LastClaimDay  — UTC day number of the last claim (os.time() // 86400)
	  data.DailyLogin.Streak        — 1-based streak day ALREADY CLAIMED this cycle

	Remote protocol (RemoteEvent "DailyLogin"):
	  server -> client: ("claimable", { streak, day, reward })   show claim popup
	  server -> client: ("claimed",   { streak, day, reward })   animate reward
	  server -> client: ("alreadyClaimed", { streak, nextIn })   already done today
	  client -> server: ("claim")                                 player presses claim
	  client -> server: ("request")                               check on login
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)
local EconomyBalance = require(ReplicatedStorage:WaitForChild("Modules").EconomyBalance)

local Service = {}

local SECONDS_PER_DAY = 86400
local STREAK_LENGTH = 7

local REWARDS = EconomyBalance.DAILY_LOGIN_REWARDS
Service.REWARDS = REWARDS

local function ensureRemote(name: string): RemoteEvent
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r :: RemoteEvent
end

local dailyRemote = ensureRemote("DailyLogin")

-- Returns the current UTC day number (floor of os.time / 86400).
local function currentDay(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

-- Seconds until the next UTC midnight.
local function secondsUntilNextDay(): number
	local now = os.time()
	local nextMidnight = (currentDay() + 1) * SECONDS_PER_DAY
	return math.max(0, nextMidnight - now)
end

-- Ensure data.DailyLogin exists (handles profiles loaded before this field).
local function ensureLoginData(data)
	if not data.DailyLogin then
		data.DailyLogin = { LastClaimDay = 0, Streak = 0 }
	end
end

-- Returns the next streak day the player would receive (1-based, wrapping).
local function nextStreakDay(currentStreak: number): number
	return (currentStreak % STREAK_LENGTH) + 1
end

-- Compute what the player's state is right now.
-- Returns: canClaim (bool), streakDay (1-7), daysSinceLast (number)
local function getLoginState(data): (boolean, number, number)
	ensureLoginData(data)
	local login = data.DailyLogin
	local today = currentDay()
	local daysSinceLast = today - (login.LastClaimDay or 0)

	local streakWouldContinue = daysSinceLast == 1 -- exactly 1 day since last claim
	local streakBroke = daysSinceLast > 1           -- missed at least one day

	local currentStreak = login.Streak or 0
	local nextDay: number

	if currentStreak == 0 or streakBroke then
		nextDay = 1  -- fresh start
	elseif streakWouldContinue then
		nextDay = nextStreakDay(currentStreak)
	else
		-- daysSinceLast == 0 → already claimed today
		nextDay = nextStreakDay(currentStreak)
	end

	local canClaim = daysSinceLast >= 1  -- new UTC day = claimable
	return canClaim, nextDay, daysSinceLast
end

local function pushState(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data then
		return
	end

	local canClaim, streakDay = getLoginState(data)

	if canClaim then
		dailyRemote:FireClient(player, "claimable", {
			streak = streakDay,
			day = streakDay,
			reward = REWARDS[streakDay],
		})
	else
		dailyRemote:FireClient(player, "alreadyClaimed", {
			streak = data.DailyLogin.Streak or 0,
			nextIn = secondsUntilNextDay(),
		})
	end
end

local function claimReward(player: Player)
	local dataService = cachedModules.Cache.DataService
	local moneyService = cachedModules.Cache.MoneyService
	local notifyRemote = remotes:FindFirstChild("Notify")

	local data = dataService.getData(player)
	if not data then
		return
	end

	local canClaim, streakDay, daysSinceLast = getLoginState(data)
	if not canClaim then
		dailyRemote:FireClient(player, "alreadyClaimed", {
			streak = data.DailyLogin.Streak or 0,
			nextIn = secondsUntilNextDay(),
		})
		return
	end

	local reward = REWARDS[streakDay]
	if not reward then
		return
	end

	-- If streak broke, reset to day 1 (already handled by getLoginState returning 1).
	data.DailyLogin.Streak = streakDay
	data.DailyLogin.LastClaimDay = currentDay()

	-- Grant rewards — cash gets multipliers, diamonds are flat.
	local actualCash = moneyService.giveMoney(player, reward.cash)
	local actualDiamonds = 0
	if reward.diamonds and reward.diamonds > 0 then
		actualDiamonds = moneyService.giveDiamonds(player, reward.diamonds)
	end

	-- Toast notification.
	if notifyRemote then
		local msg
		if actualDiamonds > 0 then
			msg = ("🗓️ Day %d! +$%d  💎 +%d"):format(streakDay, actualCash, actualDiamonds)
		else
			msg = ("🗓️ Day %d! +$%d"):format(streakDay, actualCash)
		end
		notifyRemote:FireClient(player, msg, "success")
	end

	-- Push the full claimed event so the client can animate.
	dailyRemote:FireClient(player, "claimed", {
		streak = streakDay,
		day = streakDay,
		reward = reward,
		actualCash = actualCash,
		actualDiamonds = actualDiamonds,
	})
end

function Service.dataLoaded(player: Player)
	-- Small delay so the character and HUD are ready before the popup.
	task.delay(2, function()
		if player.Parent then
			pushState(player)
		end
	end)
end

function Service.init()
	dailyRemote.OnServerEvent:Connect(function(player, action)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if action == "claim" then
			claimReward(player)
		elseif action == "request" then
			pushState(player)
		end
	end)
end

return Service
