--[[
	WeatherService — global weather cycle with gameplay hooks.

	States: Sunny (default) / Rain / Thunderstorm.
	- Weather is replicated via workspace attributes ("Weather", "WeatherEndsAt")
	  plus the WeatherChanged remote (fired on change and to late joiners).
	- While Rain is active, growing/ready fruits have a chance to gain the
	  "Wet" environmental mutation (x2 sell value).
	- Thunderstorms are rarer and can also apply "Shocked" (x8 sell value).
	Visuals live in src/client/WeatherClient.client.lua.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

local random = Random.new()

local WEATHERS = {
	{
		name = "Sunny",
		weight = 55,
		minDuration = 150,
		maxDuration = 240,
	},
	{
		name = "Rain",
		weight = 32,
		minDuration = 75,
		maxDuration = 140,
		mutations = { { name = "Wet", chancePct = 8 } },
	},
	{
		name = "Thunderstorm",
		weight = 13,
		minDuration = 50,
		maxDuration = 90,
		mutations = { { name = "Wet", chancePct = 10 }, { name = "Shocked", chancePct = 4 } },
	},
}

local MUTATION_TICK_SECONDS = 10

local currentWeather = WEATHERS[1]

local function ensureRemote(name: string): RemoteEvent
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local weatherChanged = ensureRemote("WeatherChanged")

local function pickNextWeather()
	local candidates = {}
	local totalWeight = 0
	for _, weather in WEATHERS do
		-- Never chain two identical special weathers back to back;
		-- Sunny is always allowed so the sky can clear.
		if weather.name == "Sunny" or weather.name ~= currentWeather.name then
			table.insert(candidates, weather)
			totalWeight += weather.weight
		end
	end

	local roll = random:NextNumber(0, totalWeight)
	for _, weather in candidates do
		roll -= weather.weight
		if roll <= 0 then
			return weather
		end
	end
	return candidates[#candidates]
end

local function applyWeatherMutations()
	local mutationService = cachedModules.Cache.MutationService
	local mutations = currentWeather.mutations
	if not mutations or not mutationService then
		return
	end

	local serverFolder = workspace:FindFirstChild("World")
		and workspace.World:FindFirstChild("Map")
		and workspace.World.Map:FindFirstChild("PlantedSeeds")
		and workspace.World.Map.PlantedSeeds:FindFirstChild("Server")
	if not serverFolder then
		return
	end

	for _, crop in serverFolder:GetChildren() do
		local serverConfig = crop:FindFirstChild("ServerConfiguration")
		local fruitsFolder = serverConfig and serverConfig:FindFirstChild("Fruits")
		if fruitsFolder then
			for _, fruitFolder in fruitsFolder:GetChildren() do
				for _, mutation in mutations do
					if random:NextNumber(0, 100) <= mutation.chancePct then
						mutationService.giveMutation(crop, fruitFolder.Name, mutation.name)
					end
				end
			end
		end
	end
end

function Service.getCurrentWeather(): string
	return currentWeather.name
end

local function setWeather(weather, duration: number)
	currentWeather = weather
	workspace:SetAttribute("Weather", weather.name)
	workspace:SetAttribute("WeatherEndsAt", os.time() + duration)
	weatherChanged:FireAllClients(weather.name, duration)
end

function Service.init()
	workspace:SetAttribute("Weather", currentWeather.name)
	workspace:SetAttribute("WeatherEndsAt", 0)

	-- Late joiners get the current state (attributes replicate anyway,
	-- but the remote carries the remaining duration).
	Players.PlayerAdded:Connect(function(player)
		local endsAt = workspace:GetAttribute("WeatherEndsAt") or 0
		local remaining = math.max(0, endsAt - os.time())
		weatherChanged:FireClient(player, currentWeather.name, remaining)
	end)

	-- Weather cycle
	task.spawn(function()
		-- Let plots/crops finish their first load before the first roll
		task.wait(5)
		while true do
			local weather = pickNextWeather()
			local duration = random:NextInteger(weather.minDuration, weather.maxDuration)
			setWeather(weather, duration)

			local endsAt = os.time() + duration
			while os.time() < endsAt do
				task.wait(MUTATION_TICK_SECONDS)
				if os.time() <= endsAt then
					applyWeatherMutations()
				end
			end
		end
	end)
end

return Service
