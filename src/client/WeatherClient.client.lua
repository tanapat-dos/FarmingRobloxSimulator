--[[
	WeatherClient — visuals + HUD for WeatherService.

	Rain is created on the CLIENT only (Workspace.WeatherEffects will not
	appear in Studio Explorer while viewing the Server — switch Explorer to
	Client during Play Test to inspect it).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EnvironmentLighting = require(ReplicatedStorage:WaitForChild("Modules").EnvironmentLighting)
local WeatherSounds = require(ReplicatedStorage:WaitForChild("Modules").WeatherSounds)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")

local HUD_TEXT = {
	Sunny = "☀️ Sunny — clear skies",
	Rain = "🌧 Rain — crops can turn <b>Wet</b> (x2 value)!",
	Thunderstorm = "⛈ Thunderstorm — <b>Wet</b> x2 and rare <b>Shocked</b> x8!",
}

local HUD_RIGHT_INSET = 12
local HUD_TOP_INSET = 8
local HUD_BANNER_HEIGHT = 30

-- ----------------------------------------------------------- ambient audio
local ambientFolder: Folder? = nil
local activeAmbient: Sound? = nil
local fadeThread: thread? = nil

local function getAmbientFolder(): Folder
	if ambientFolder and ambientFolder.Parent then
		return ambientFolder
	end

	local folder = playerGui:FindFirstChild("WeatherAmbient")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WeatherAmbient"
		folder.Parent = playerGui
	end

	ambientFolder = folder :: Folder
	return ambientFolder
end

local function stopFadeThread()
	if fadeThread then
		task.cancel(fadeThread)
		fadeThread = nil
	end
end

local function createAmbientSound(config: WeatherSounds.AmbientConfig): Sound
	local sound = Instance.new("Sound")
	sound.Name = "WeatherAmbientLoop"
	sound.SoundId = config.SoundId
	sound.Volume = 0
	sound.Looped = config.Looped
	sound.RollOffMaxDistance = 10000
	sound.RollOffMinDistance = 10
	sound.Parent = getAmbientFolder()
	return sound
end

local function fadeAmbientTo(weatherName: string)
	stopFadeThread()

	local config = WeatherSounds.getAmbientConfig(weatherName, soundsFolder)
	if not config then
		return
	end

	local targetVolume = config.Volume
	local previous = activeAmbient
	local nextSound = createAmbientSound(config)
	activeAmbient = nextSound

	nextSound:Play()

	fadeThread = task.spawn(function()
		local fadeInfo = TweenInfo.new(WeatherSounds.FADE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(nextSound, fadeInfo, { Volume = targetVolume }):Play()

		if previous then
			local fadeOut = TweenService:Create(previous, fadeInfo, { Volume = 0 })
			fadeOut:Play()
			fadeOut.Completed:Wait()
			previous:Stop()
			previous:Destroy()
		end

		fadeThread = nil
	end)
end

local function playThunderCrack()
	local config = WeatherSounds.getThunderConfig(soundsFolder)
	local thunder = Instance.new("Sound")
	thunder.Name = "ThunderCrack"
	thunder.SoundId = config.SoundId
	thunder.Volume = config.Volume
	thunder.Looped = false
	thunder.Parent = getAmbientFolder()
	thunder:Play()
	thunder.Ended:Once(function()
		thunder:Destroy()
	end)
end

-- ---------------------------------------------------------------- rain rig
local RAIN_FOLDER_NAME = "WeatherEffects"

local rainFolder: Folder? = nil
local rainPart: Part? = nil
local rainEmitter: ParticleEmitter? = nil
local rainConnection: RBXScriptConnection? = nil
local flashThread: thread? = nil
local pendingRainRate = 0
local buildingRain = false

local function getRainFolder(): Folder
	if rainFolder and rainFolder.Parent then
		return rainFolder
	end

	local folder = workspace:FindFirstChild(RAIN_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RAIN_FOLDER_NAME
		folder:SetAttribute("LocalWeatherFX", true)
		folder.Parent = workspace
	end

	rainFolder = folder :: Folder
	return rainFolder
end

local function waitForCamera(): Camera
	while not workspace.CurrentCamera do
		RunService.RenderStepped:Wait()
	end
	return workspace.CurrentCamera
end

local function applyRainRate(rate: number)
	pendingRainRate = rate
	if not rainEmitter then
		return
	end

	rainEmitter.Enabled = rate > 0
	rainEmitter.Rate = rate
	if rate > 0 then
		rainEmitter:Emit(math.clamp(math.floor(rate * 0.08), 40, 120))
	end
end

local function buildRainRig()
	if rainPart or buildingRain then
		return
	end

	buildingRain = true
	getRainFolder()

	task.spawn(function()
		waitForCamera()

		if rainPart then
			buildingRain = false
			applyRainRate(pendingRainRate)
			return
		end

		local part = Instance.new("Part")
		part.Name = "WeatherRainEmitter"
		part.Size = Vector3.new(160, 2, 160)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "RainDrops"
		emitter.Texture = "rbxassetid://241685767"
		emitter.Color = ColorSequence.new(Color3.fromRGB(190, 215, 255))
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0.25),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(1, 0.35),
		})
		emitter.Lifetime = NumberRange.new(1.2, 1.6)
		emitter.Speed = NumberRange.new(80, 110)
		emitter.Acceleration = Vector3.new(0, -60, 0)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.SpreadAngle = Vector2.new(12, 12)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Rate = 0
		emitter.Enabled = true
		emitter.LightEmission = 0.35
		emitter.LightInfluence = 0.25
		emitter.LockedToPart = false
		emitter.Parent = part

		part.Parent = getRainFolder()
		rainPart = part
		rainEmitter = emitter

		local camera = workspace.CurrentCamera
		if camera then
			part.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 55, 0))
		end

		if rainConnection then
			rainConnection:Disconnect()
		end

		rainConnection = RunService.RenderStepped:Connect(function()
			local activeCamera = workspace.CurrentCamera
			if activeCamera and rainPart then
				rainPart.CFrame = CFrame.new(activeCamera.CFrame.Position + Vector3.new(0, 55, 0))
			end
		end)

		buildingRain = false
		applyRainRate(pendingRainRate)
	end)
end

local function setRain(rate: number)
	if rate > 0 then
		getRainFolder()
		buildRainRig()
		applyRainRate(rate)
	else
		applyRainRate(0)
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
			EnvironmentLighting.lightningBoost = 2.5
			playThunderCrack()
			task.wait(0.1)
			EnvironmentLighting.lightningBoost = 0
			task.wait(0.07)
			EnvironmentLighting.lightningBoost = 1.5
			playThunderCrack()
			task.wait(0.08)
			EnvironmentLighting.lightningBoost = 0
		end
	end)
end

-- ------------------------------------------------------------------ HUD
local weatherGui: ScreenGui? = nil
local hudLabel: TextLabel? = nil

local function ensureHud(): TextLabel
	if hudLabel and hudLabel.Parent then
		return hudLabel
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WeatherHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui
	weatherGui = gui

	local label = Instance.new("TextLabel")
	label.Name = "Banner"
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -HUD_RIGHT_INSET, 0, HUD_TOP_INSET)
	label.Size = UDim2.fromOffset(340, HUD_BANNER_HEIGHT)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(235, 240, 250)
	label.TextStrokeTransparency = 0.6
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Center
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
		return
	end
	label.Visible = false
end

-- ------------------------------------------------------------- apply state
local function onWeatherChanged(weatherName: string)
	stopFlashes()
	EnvironmentLighting.lightningBoost = 0

	if weatherName == "Rain" then
		setRain(900)
	elseif weatherName == "Thunderstorm" then
		setRain(1400)
		startFlashes()
	else
		setRain(0)
	end

	fadeAmbientTo(weatherName)
	setHud(weatherName)
end

remotes:WaitForChild("WeatherChanged").OnClientEvent:Connect(function(weatherName: string)
	onWeatherChanged(weatherName)
end)

workspace:GetAttributeChangedSignal("Weather"):Connect(function()
	local weatherName = workspace:GetAttribute("Weather")
	if typeof(weatherName) == "string" then
		onWeatherChanged(weatherName)
	end
end)

task.defer(function()
	local bootWeather = workspace:GetAttribute("Weather")
	if typeof(bootWeather) == "string" then
		onWeatherChanged(bootWeather)
	end
end)
