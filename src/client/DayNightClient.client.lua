--!strict
-- Day/night lighting + top-right stack: diamonds, clock, seed timer, weather.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local DayNightConfig = require(ReplicatedStorage:WaitForChild("Modules").DayNightConfig)
local EnvironmentLighting = require(ReplicatedStorage:WaitForChild("Modules").EnvironmentLighting)
local ShopStock = require(ReplicatedStorage:WaitForChild("Modules").ShopStock)
local WeatherHudConfig = require(ReplicatedStorage:WaitForChild("Modules").WeatherHudConfig)

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local displayClock = DayNightConfig.START_CLOCK
local targetClock = DayNightConfig.START_CLOCK
local currentWeather = "Sunny"

local HUD_RIGHT_INSET = 12
local HUD_STACK_TOP = 8
local HUD_STACK_GAP = 4
local HUD_ROW_HEIGHT = 28
local HUD_DIAMOND_ROW_HEIGHT = 34
local HUD_STACK_WIDTH = 340
local DIAMOND_TEXT_COLOR = Color3.fromRGB(120, 210, 255)
local DEFAULT_RESTOCK_SECONDS = 300

local restockTargetSeconds = DEFAULT_RESTOCK_SECONDS
local restockSyncedAt = os.clock()

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
local hudGui: ScreenGui? = nil
local hudStack: Frame? = nil
local clockLabel: TextLabel? = nil
local seedShopLabel: TextLabel? = nil
local weatherLabel: TextLabel? = nil
local diamondLabel: TextLabel? = nil
local diamondHudListenerConnected = false

local function makeHudRow(name: string, width: number, textColor: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromOffset(width, HUD_ROW_HEIGHT)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = textColor
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Center
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return label
end

local function formatDiamondCount(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return formatted:gsub("^,", "")
end

local function destroyLegacyDiamondHud()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local mainGui = pg:FindFirstChild("Main")
	if mainGui then
		local legacy = mainGui:FindFirstChild("DiamondCount")
		if legacy then
			legacy:Destroy()
		end
	end
end

local function updateDiamondHudDisplay()
	if not diamondLabel then
		return
	end
	local amount = player:GetAttribute("Diamonds") or 0
	diamondLabel.Text = "💎 " .. formatDiamondCount(amount)
end

local function connectDiamondHudListener()
	if diamondHudListenerConnected then
		return
	end
	diamondHudListenerConnected = true
	player:GetAttributeChangedSignal("Diamonds"):Connect(updateDiamondHudDisplay)
end

local function ensureHud(): (TextLabel, TextLabel)
	if hudGui and hudGui.Parent then
		local stack = hudGui:FindFirstChild("TopRightStack")
		if stack and stack:IsA("Frame") then
			local clock = stack:FindFirstChild("Clock")
			local seed = stack:FindFirstChild("SeedShopRestock")
			local weather = stack:FindFirstChild("WeatherBanner")
			local diamond = stack:FindFirstChild("DiamondCount")
			if
				clock
				and seed
				and weather
				and diamond
				and clock:IsA("TextLabel")
				and seed:IsA("TextLabel")
				and weather:IsA("TextLabel")
				and diamond:IsA("TextLabel")
			then
				hudStack = stack
				clockLabel = clock
				seedShopLabel = seed
				weatherLabel = weather
				diamondLabel = diamond
				connectDiamondHudListener()
				return clockLabel, seedShopLabel
			end
		end
		hudGui:Destroy()
		hudGui = nil
		hudStack = nil
		clockLabel = nil
		seedShopLabel = nil
		weatherLabel = nil
		diamondLabel = nil
	end

	destroyLegacyDiamondHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DayNightHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	hudGui = gui

	local stack = Instance.new("Frame")
	stack.Name = "TopRightStack"
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.Position = UDim2.new(1, -HUD_RIGHT_INSET, 0, HUD_STACK_TOP)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	stack.Size = UDim2.fromOffset(HUD_STACK_WIDTH, 0)
	stack.BackgroundTransparency = 1
	stack.Parent = gui
	hudStack = stack

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, HUD_STACK_GAP)
	layout.Parent = stack

	local diamond = Instance.new("TextLabel")
	diamond.Name = "DiamondCount"
	diamond.LayoutOrder = 1
	diamond.Size = UDim2.fromOffset(130, HUD_DIAMOND_ROW_HEIGHT)
	diamond.BackgroundColor3 = Color3.fromRGB(22, 24, 38)
	diamond.BackgroundTransparency = 0.1
	diamond.Text = "💎 0"
	diamond.TextColor3 = DIAMOND_TEXT_COLOR
	diamond.Font = Enum.Font.GothamBold
	diamond.TextSize = 18
	diamond.TextXAlignment = Enum.TextXAlignment.Center
	diamond.Parent = stack

	local diamondCorner = Instance.new("UICorner")
	diamondCorner.CornerRadius = UDim.new(0, 10)
	diamondCorner.Parent = diamond

	local diamondStroke = Instance.new("UIStroke")
	diamondStroke.Color = Color3.fromRGB(80, 150, 200)
	diamondStroke.Thickness = 1.5
	diamondStroke.Transparency = 0.4
	diamondStroke.Parent = diamond

	diamondLabel = diamond

	local clock = makeHudRow("Clock", 130, Color3.fromRGB(235, 240, 250))
	clock.LayoutOrder = 2
	clock.TextSize = 15
	clock.TextStrokeTransparency = 0.65
	clock.Parent = stack
	clockLabel = clock

	local seed = makeHudRow("SeedShopRestock", HUD_STACK_WIDTH, Color3.fromRGB(210, 245, 150))
	seed.LayoutOrder = 3
	seed.Text = "🌾 Seeds: --:--"
	seed.Parent = stack

	local seedStroke = Instance.new("UIStroke")
	seedStroke.Color = Color3.fromRGB(100, 140, 70)
	seedStroke.Thickness = 1
	seedStroke.Transparency = 0.35
	seedStroke.Parent = seed

	seedShopLabel = seed

	local weather = Instance.new("TextLabel")
	weather.Name = "WeatherBanner"
	weather.LayoutOrder = 4
	weather.Size = UDim2.fromOffset(HUD_STACK_WIDTH, 0)
	weather.AutomaticSize = Enum.AutomaticSize.Y
	weather.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
	weather.BackgroundTransparency = 0.15
	weather.TextColor3 = Color3.fromRGB(235, 240, 250)
	weather.TextStrokeTransparency = 0.6
	weather.Font = Enum.Font.GothamBold
	weather.TextSize = 13
	weather.TextWrapped = true
	weather.RichText = true
	weather.TextXAlignment = Enum.TextXAlignment.Center
	weather.Visible = false
	weather.Parent = stack

	local weatherCorner = Instance.new("UICorner")
	weatherCorner.CornerRadius = UDim.new(0, 8)
	weatherCorner.Parent = weather

	local weatherPad = Instance.new("UIPadding")
	weatherPad.PaddingTop = UDim.new(0, 4)
	weatherPad.PaddingBottom = UDim.new(0, 4)
	weatherPad.PaddingLeft = UDim.new(0, 6)
	weatherPad.PaddingRight = UDim.new(0, 6)
	weatherPad.Parent = weather

	weatherLabel = weather
	connectDiamondHudListener()
	updateDiamondHudDisplay()
	return clock, seed
end

local function setWeatherHud(weatherName: string)
	ensureHud()
	if not weatherLabel then
		return
	end
	local text = WeatherHudConfig.getBannerText(weatherName)
	if text then
		weatherLabel.Text = text
		weatherLabel.Visible = true
	else
		weatherLabel.Visible = false
	end
end

local function getClientSignals(): Folder
	local folder = ReplicatedStorage:FindFirstChild("ClientSignals")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientSignals"
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

local function syncRestockSeconds(seconds: number)
	restockTargetSeconds = math.max(0, math.floor(seconds))
	restockSyncedAt = os.clock()
	local _, seed = ensureHud()
	seed.Text = ("🌾 Seeds: %s"):format(ShopStock.formatCountdown(restockTargetSeconds))
end

local function parseSeedShopPayload(timeLeft: unknown)
	if typeof(timeLeft) == "number" then
		syncRestockSeconds(timeLeft)
	elseif typeof(timeLeft) == "string" then
		local minutes, secs = string.match(timeLeft, "^(%d+):(%d+)$")
		if minutes and secs then
			syncRestockSeconds(tonumber(minutes) :: number * 60 + (tonumber(secs) :: number))
		else
			local _, seed = ensureHud()
			seed.Text = "🌾 Seeds: " .. timeLeft
		end
	end
end

local function updateClockHud(clock: number)
	local clockRow, _seedRow = ensureHud()
	local phase = DayNightConfig.getPhase(clock)
	local icon = DayNightConfig.getPhaseIcon(phase)
	clockRow.Text = `{icon} {DayNightConfig.formatClock(clock)}`
end

local function updateSeedShopHudDisplay()
	local elapsed = os.clock() - restockSyncedAt
	local remaining = math.max(0, math.floor(restockTargetSeconds - elapsed))
	local _, seed = ensureHud()
	seed.Text = ("🌾 Seeds: %s"):format(ShopStock.formatCountdown(remaining))
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

local intervalAttr = workspace:GetAttribute("SeedShopRestockInterval")
if typeof(intervalAttr) == "number" then
	DEFAULT_RESTOCK_SECONDS = intervalAttr
	restockTargetSeconds = intervalAttr
end

ensureHud()
updateSeedShopHudDisplay()
updateDiamondHudDisplay()
destroyLegacyDiamondHud()

local legacyWeatherGui = player:WaitForChild("PlayerGui"):FindFirstChild("WeatherHUD")
if legacyWeatherGui then
	legacyWeatherGui:Destroy()
end

local weatherHudEvent = getClientSignals():FindFirstChild("WeatherHudUpdate")
if not weatherHudEvent then
	weatherHudEvent = Instance.new("BindableEvent")
	weatherHudEvent.Name = "WeatherHudUpdate"
	weatherHudEvent.Parent = getClientSignals()
end
weatherHudEvent.Event:Connect(setWeatherHud)

local bootWeather = workspace:GetAttribute("Weather")
if typeof(bootWeather) == "string" then
	setWeatherHud(bootWeather)
end

workspace:GetAttributeChangedSignal("Weather"):Connect(function()
	local weatherName = workspace:GetAttribute("Weather")
	if typeof(weatherName) == "string" then
		setWeatherHud(weatherName)
	end
end)

workspace:GetAttributeChangedSignal("GameClock"):Connect(function()
	targetClock = getServerClock()
end)

workspace:GetAttributeChangedSignal("Weather"):Connect(function()
	refreshWeatherFromAttribute()
end)

workspace:GetAttributeChangedSignal("SeedShopRestockRemaining"):Connect(function()
	local value = workspace:GetAttribute("SeedShopRestockRemaining")
	if typeof(value) == "number" then
		syncRestockSeconds(value)
	end
end)

local attrSeconds = workspace:GetAttribute("SeedShopRestockRemaining")
if typeof(attrSeconds) == "number" then
	syncRestockSeconds(attrSeconds)
end

remotes:WaitForChild("DayNightSync").OnClientEvent:Connect(function(clock: number)
	if typeof(clock) == "number" then
		targetClock = clock
	end
end)

remotes:WaitForChild("WeatherChanged").OnClientEvent:Connect(function(weatherName: string)
	if typeof(weatherName) == "string" then
		currentWeather = weatherName
		setWeatherHud(weatherName)
	end
end)

task.spawn(function()
	local seedShopTimerRemote = remotes:WaitForChild("SeedShopTimer", 60)
	if seedShopTimerRemote and seedShopTimerRemote:IsA("RemoteEvent") then
		seedShopTimerRemote.OnClientEvent:Connect(parseSeedShopPayload)
	end
end)

local lastSeedHudTick = 0
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

	local now = os.clock()
	if now - lastSeedHudTick >= 0.25 then
		lastSeedHudTick = now
		updateSeedShopHudDisplay()
	end
end)

applyLighting(displayClock, currentWeather)
updateClockHud(displayClock)
