--[[
	WeatherClient — visuals + HUD for WeatherService.

	Everything is built procedurally (no .rbxl assets required):
	- Rain: camera-following emitter part with streak particles.
	- Thunderstorm: heavier rain, darker mood, random lightning flashes.
	- Mood: Lighting tweens per weather, restored on Sunny.
	- HUD: small top-center banner describing the active weather perk.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local MOOD_TWEEN = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local originalLighting = {
	Brightness = Lighting.Brightness,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Ambient = Lighting.Ambient,
}

local MOODS = {
	Sunny = originalLighting,
	Rain = {
		Brightness = math.max(0.6, originalLighting.Brightness * 0.55),
		OutdoorAmbient = Color3.fromRGB(120, 128, 140),
		Ambient = Color3.fromRGB(105, 110, 122),
	},
	Thunderstorm = {
		Brightness = math.max(0.35, originalLighting.Brightness * 0.3),
		OutdoorAmbient = Color3.fromRGB(85, 90, 105),
		Ambient = Color3.fromRGB(70, 74, 88),
	},
}

local HUD_TEXT = {
	Rain = "🌧 Rain — crops can turn <b>Wet</b> (x2 value)!",
	Thunderstorm = "⛈ Thunderstorm — <b>Wet</b> x2 and rare <b>Shocked</b> x8!",
}

-- ---------------------------------------------------------------- rain rig
local rainPart: Part? = nil
local rainEmitter: ParticleEmitter? = nil
local rainConnection: RBXScriptConnection? = nil
local flashThread: thread? = nil

local function buildRainRig()
	if rainPart then
		return
	end

	local part = Instance.new("Part")
	part.Name = "WeatherRainEmitter"
	part.Size = Vector3.new(90, 1, 90)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RainDrops"
	emitter.Color = ColorSequence.new(Color3.fromRGB(180, 205, 235))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.1)
	emitter.Speed = NumberRange.new(55, 70)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(4, 4)
	emitter.Rate = 0
	emitter.LightEmission = 0.15
	emitter.LightInfluence = 0.9
	emitter.Parent = part

	part.Parent = workspace.CurrentCamera
	rainPart = part
	rainEmitter = emitter

	rainConnection = RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and rainPart then
			rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
		end
	end)
end

local function setRain(rate: number)
	if rate > 0 then
		buildRainRig()
	end
	if rainEmitter then
		rainEmitter.Rate = rate
	end
end

-- ------------------------------------------------------------- lightning
local function stopFlashes()
	if flashThread then
		task.cancel(flashThread)
		flashThread = nil
	end
end

local function startFlashes()
	stopFlashes()
	flashThread = task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(6, 14))
			local before = Lighting.Brightness
			Lighting.Brightness = before + 2.5
			task.wait(0.1)
			Lighting.Brightness = before
			task.wait(0.07)
			Lighting.Brightness = before + 1.5
			task.wait(0.08)
			Lighting.Brightness = before
		end
	end)
end

-- ------------------------------------------------------------------ HUD
local hudLabel: TextLabel? = nil

local function ensureHud(): TextLabel
	if hudLabel and hudLabel.Parent then
		return hudLabel
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WeatherHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Banner"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 8)
	label.Size = UDim2.fromOffset(340, 30)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(235, 240, 250)
	label.TextStrokeTransparency = 0.6
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.RichText = true
	label.Visible = false
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	hudLabel = label
	return label
end

local function setHud(weatherName: string)
	local label = ensureHud()
	local text = HUD_TEXT[weatherName]
	if text then
		label.Text = text
		label.Visible = true
	else
		label.Visible = false
	end
end

-- ------------------------------------------------------------- apply state
local function applyMood(weatherName: string)
	local mood = MOODS[weatherName] or MOODS.Sunny
	TweenService:Create(Lighting, MOOD_TWEEN, {
		Brightness = mood.Brightness,
		OutdoorAmbient = mood.OutdoorAmbient,
		Ambient = mood.Ambient,
	}):Play()
end

local function onWeatherChanged(weatherName: string)
	stopFlashes()

	if weatherName == "Rain" then
		setRain(350)
	elseif weatherName == "Thunderstorm" then
		setRain(650)
		startFlashes()
	else
		setRain(0)
	end

	applyMood(weatherName)
	setHud(weatherName)
end

remotes:WaitForChild("WeatherChanged").OnClientEvent:Connect(function(weatherName: string)
	onWeatherChanged(weatherName)
end)

-- Attributes replicate before the remote for late joiners; apply once at boot.
local bootWeather = workspace:GetAttribute("Weather")
if typeof(bootWeather) == "string" then
	onWeatherChanged(bootWeather)
end
