--[[
	DayNightService — server-authoritative 12-minute day/night clock.

	Replicates GameClock (0–24) and DayPhase via workspace attributes so late
	joiners continue from the live server time.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNightConfig = require(ReplicatedStorage:WaitForChild("Modules").DayNightConfig)

local Service = {}

local serverStartTime = os.clock()
local updateRemote: RemoteEvent

local function ensureRemote(name: string): RemoteEvent
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote :: RemoteEvent
end

local function getGameClock(): number
	return DayNightConfig.computeGameClock(serverStartTime, DayNightConfig.START_CLOCK)
end

local function publishClock(clock: number)
	local phase = DayNightConfig.getPhase(clock)
	workspace:SetAttribute("GameClock", clock)
	workspace:SetAttribute("DayPhase", phase)
end

function Service.getGameClock(): number
	return getGameClock()
end

function Service.init()
	updateRemote = ensureRemote("DayNightSync")

	workspace:SetAttribute("DayLengthSeconds", DayNightConfig.DAY_LENGTH_SECONDS)
	publishClock(getGameClock())

	Players.PlayerAdded:Connect(function(player)
		updateRemote:FireClient(player, getGameClock(), workspace:GetAttribute("DayPhase"))
	end)

	local lastPhase = workspace:GetAttribute("DayPhase")
	RunService.Heartbeat:Connect(function()
		local clock = getGameClock()
		publishClock(clock)

		local phase = workspace:GetAttribute("DayPhase")
		if phase ~= lastPhase then
			lastPhase = phase
			updateRemote:FireAllClients(clock, phase)
		end
	end)
end

return Service
