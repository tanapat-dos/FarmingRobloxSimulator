--!strict
-- Day/night lighting + top-right clock HUD (visual only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local DayNightConfig = require(ReplicatedStorage:WaitForChild("Modules").DayNightConfig)
local EnvironmentLighting = require(ReplicatedStorage:WaitForChild("Modules").EnvironmentLighting)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local displayClock = DayNightConfig.START_CLOCK
local targetClock = DayNightConfig.START_CLOCK
local currentWeather = "Sunny"

local HUD_RIGHT_INSET = 12
local HUD_TOP_INSET = 8
local HUD_BANNER_HEIGHT = 30
local HUD_STACK_GAP = 4
local HUD_CLOCK_TOP = HUD_TOP_INSET + HUD_BANNER_HEIGHT + HUD_STACK_GAP

local function getServerClock(): number
	local clock = workspace:GetAttribute("GameClock")
	if typeof(clock) == "number" then
		return clock
	end
	return DayNightConfig.START_CLOCK
end

local function applyLighting(clock: number, weatherName: string)
	local day = DayNightConfig.sampleDayLighting(clock)
	local merged = DayNightConfig.applyWeather(day, weatherName)

	Lighting.ClockTime = merged.ClockTime
	Lighting.Brightness = merged.Brightness + EnvironmentLighting.lightningBoost
	Lighting.Ambient = merged.Ambient
	Lighting.OutdoorAmbient = merged.OutdoorAmbient
	Lighting.ColorShift_Top = merged.ColorShift_Top
	Lighting.ColorShift_Bottom = merged.ColorShift_Bottom
	Lighting.ShadowSoftness = merged.ShadowSoftness
	Lighting.GlobalShadows = true
end

-- ------------------------------------------------------------------ HUD
local clockGui: ScreenGui? = nil
local clockLabel: TextLabel? = nil

local function ensureClockHud(): TextLabel
	if clockLabel and clockLabel.Parent then
		return clockLabel
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DayNightHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	clockGui = gui

	local label = Instance.new("TextLabel")
	label.Name = "Clock"
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -HUD_RIGHT_INSET, 0, HUD_CLOCK_TOP)
	label.Size = UDim2.fromOffset(130, 28)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(235, 240, 250)
	label.TextStrokeTransparency = 0.65
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	clockLabel = label
	return label
end

local function updateClockHud(clock: number)
	local label = ensureClockHud()
	local phase = DayNightConfig.getPhase(clock)
	local icon = DayNightConfig.getPhaseIcon(phase)
	label.Text = `{icon} {DayNightConfig.formatClock(clock)}`
end

local function refreshWeatherFromAttribute()
	local weather = workspace:GetAttribute("Weather")
	if typeof(weather) == "string" then
		currentWeather = weather
	end
end

refreshWeatherFromAttribute()
targetClock = getServerClock()
displayClock = targetClock

workspace:GetAttributeChangedSignal("GameClock"):Connect(function()
	targetClock = getServerClock()
end)

workspace:GetAttributeChangedSignal("Weather"):Connect(function()
	refreshWeatherFromAttribute()
end)

remotes:WaitForChild("DayNightSync").OnClientEvent:Connect(function(clock: number)
	if typeof(clock) == "number" then
		targetClock = clock
	end
end)

remotes:WaitForChild("WeatherChanged").OnClientEvent:Connect(function(weatherName: string)
	if typeof(weatherName) == "string" then
		currentWeather = weatherName
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local diff = targetClock - displayClock
	if diff > 12 then
		diff -= 24
	elseif diff < -12 then
		diff += 24
	end
	displayClock = (displayClock + diff * math.min(1, dt * 6)) % 24

	applyLighting(displayClock, currentWeather)
	updateClockHud(displayClock)
end)

applyLighting(displayClock, currentWeather)
updateClockHud(displayClock)
