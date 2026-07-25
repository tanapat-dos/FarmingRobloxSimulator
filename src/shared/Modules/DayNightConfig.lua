--!strict
-- Day/night lighting keyframes and weather layering helpers.

export type LightingSample = {
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ColorShift_Top: Color3,
	ColorShift_Bottom: Color3,
	ShadowSoftness: number,
	ClockTime: number,

	-- Atmosphere gives aerial perspective (distant geometry fading toward the sky), which
	-- is the main depth cue in an outdoor scene. Haze rises at dawn/dusk — that is most of
	-- what makes golden hour look good.
	Density: number,
	Haze: number,
	Glare: number,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,

	-- ColorCorrection grading. Small values only; this is a polish pass, not a filter.
	Saturation: number,
	Contrast: number,
}

export type WeatherAdjust = {
	BrightnessMult: number,
	Ambient: Color3?,
	OutdoorAmbient: Color3?,
	-- Additive so weather layers on top of whatever the time of day is doing.
	DensityAdd: number?,
	HazeAdd: number?,
	GlareMult: number?,
	SaturationAdd: number?,
	ContrastAdd: number?,
}

local DayNightConfig = {}

-- Real-time spent on each portion of the 24h lighting loop (daylight vs everything else).
DayNightConfig.DAY_REAL_SECONDS = 9 * 60
DayNightConfig.NIGHT_REAL_SECONDS = 3 * 60
-- Full cycle length (also replicated on workspace as DayLengthSeconds).
DayNightConfig.DAY_LENGTH_SECONDS = DayNightConfig.DAY_REAL_SECONDS + DayNightConfig.NIGHT_REAL_SECONDS
-- In-game hours treated as "lit day" vs "night" for clock speed (matches keyframe sunrise/sunset).
DayNightConfig.DAYLIGHT_CLOCK_START = 6.5
DayNightConfig.DAYLIGHT_CLOCK_END = 19.5

DayNightConfig.START_CLOCK = 8 -- server boots at 8:00 AM

-- Sample points across the 24h cycle (ClockTime matches GameClock).
-- Midday ambient is deliberately LOWER and slightly cool (sky bounce) rather than the flat
-- grey it used to be. High grey ambient fills in shadows and desaturates everything, which
-- reads as "evenly lit and lifeless". Keeping ambient down lets the directional sun carry
-- the scene, so shadows have depth and greens stay saturated.
local KEYFRAMES: { LightingSample } = {
	{ -- midnight
		Brightness = 0.8,
		Ambient = Color3.fromRGB(38, 46, 72),
		OutdoorAmbient = Color3.fromRGB(30, 36, 60),
		ColorShift_Top = Color3.fromRGB(0, 0, 10),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ShadowSoftness = 0.6,
		ClockTime = 0,
		Density = 0.42,
		Haze = 0.9,
		Glare = 0,
		AtmosphereColor = Color3.fromRGB(80, 92, 130),
		AtmosphereDecay = Color3.fromRGB(28, 34, 62),
		Saturation = -0.06,
		Contrast = 0.08,
	},
	{ -- pre-dawn
		Brightness = 0.85,
		Ambient = Color3.fromRGB(42, 50, 78),
		OutdoorAmbient = Color3.fromRGB(34, 40, 64),
		ColorShift_Top = Color3.fromRGB(0, 0, 12),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ShadowSoftness = 0.55,
		ClockTime = 5,
		Density = 0.44,
		Haze = 1.4,
		Glare = 0.04,
		AtmosphereColor = Color3.fromRGB(105, 112, 150),
		AtmosphereDecay = Color3.fromRGB(40, 46, 78),
		Saturation = -0.04,
		Contrast = 0.07,
	},
	{ -- sunrise: heavy warm haze is what sells golden hour
		Brightness = 1.4,
		Ambient = Color3.fromRGB(120, 100, 88),
		OutdoorAmbient = Color3.fromRGB(150, 118, 98),
		ColorShift_Top = Color3.fromRGB(255, 170, 120),
		ColorShift_Bottom = Color3.fromRGB(255, 210, 160),
		ShadowSoftness = 0.35,
		ClockTime = 6.5,
		Density = 0.37,
		Haze = 2.7,
		Glare = 0.32,
		AtmosphereColor = Color3.fromRGB(226, 186, 152),
		AtmosphereDecay = Color3.fromRGB(150, 108, 88),
		Saturation = 0.08,
		Contrast = 0.04,
	},
	{ -- mid-morning
		Brightness = 2.4,
		Ambient = Color3.fromRGB(92, 96, 108),
		OutdoorAmbient = Color3.fromRGB(112, 124, 142),
		ColorShift_Top = Color3.fromRGB(255, 250, 240),
		ColorShift_Bottom = Color3.fromRGB(245, 248, 255),
		ShadowSoftness = 0.2,
		ClockTime = 10,
		Density = 0.31,
		Haze = 1.5,
		Glare = 0.18,
		AtmosphereColor = Color3.fromRGB(199, 212, 228),
		AtmosphereDecay = Color3.fromRGB(106, 132, 168),
		Saturation = 0.1,
		Contrast = 0.05,
	},
	{ -- afternoon peak
		Brightness = 2.6,
		Ambient = Color3.fromRGB(96, 100, 112),
		OutdoorAmbient = Color3.fromRGB(118, 130, 148),
		ColorShift_Top = Color3.fromRGB(255, 252, 244),
		ColorShift_Bottom = Color3.fromRGB(248, 250, 255),
		ShadowSoftness = 0.15,
		ClockTime = 14,
		Density = 0.28,
		Haze = 1.3,
		Glare = 0.2,
		AtmosphereColor = Color3.fromRGB(203, 216, 232),
		AtmosphereDecay = Color3.fromRGB(112, 138, 174),
		Saturation = 0.1,
		Contrast = 0.05,
	},
	{ -- sunset
		Brightness = 1.5,
		Ambient = Color3.fromRGB(126, 100, 86),
		OutdoorAmbient = Color3.fromRGB(155, 114, 90),
		ColorShift_Top = Color3.fromRGB(255, 155, 95),
		ColorShift_Bottom = Color3.fromRGB(255, 195, 140),
		ShadowSoftness = 0.35,
		ClockTime = 18.5,
		Density = 0.38,
		Haze = 2.9,
		Glare = 0.34,
		AtmosphereColor = Color3.fromRGB(232, 176, 138),
		AtmosphereDecay = Color3.fromRGB(158, 96, 78),
		Saturation = 0.1,
		Contrast = 0.04,
	},
	{ -- dusk
		Brightness = 0.95,
		Ambient = Color3.fromRGB(58, 66, 94),
		OutdoorAmbient = Color3.fromRGB(46, 54, 80),
		ColorShift_Top = Color3.fromRGB(40, 45, 80),
		ColorShift_Bottom = Color3.fromRGB(20, 20, 35),
		ShadowSoftness = 0.5,
		ClockTime = 20,
		Density = 0.41,
		Haze = 1.5,
		Glare = 0.06,
		AtmosphereColor = Color3.fromRGB(120, 122, 158),
		AtmosphereDecay = Color3.fromRGB(52, 56, 92),
		Saturation = 0.02,
		Contrast = 0.07,
	},
	{ -- wrap to midnight
		Brightness = 0.8,
		Ambient = Color3.fromRGB(38, 46, 72),
		OutdoorAmbient = Color3.fromRGB(30, 36, 60),
		ColorShift_Top = Color3.fromRGB(0, 0, 10),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ShadowSoftness = 0.6,
		ClockTime = 24,
		Density = 0.42,
		Haze = 0.9,
		Glare = 0,
		AtmosphereColor = Color3.fromRGB(80, 92, 130),
		AtmosphereDecay = Color3.fromRGB(28, 34, 62),
		Saturation = -0.06,
		Contrast = 0.08,
	},
}

-- Weather layers on top of the time-of-day sample. Rain/storms push haze and density up and
-- pull saturation down, so bad weather reads as heavy air rather than just "darker".
local WEATHER_ADJUST: { [string]: WeatherAdjust } = {
	Sunny = {
		BrightnessMult = 1,
	},
	Rain = {
		BrightnessMult = 0.55,
		Ambient = Color3.fromRGB(88, 94, 108),
		OutdoorAmbient = Color3.fromRGB(104, 114, 130),
		DensityAdd = 0.06,
		HazeAdd = 2.5,
		GlareMult = 0.2,
		SaturationAdd = -0.14,
		ContrastAdd = 0.02,
	},
	Thunderstorm = {
		BrightnessMult = 0.32,
		Ambient = Color3.fromRGB(60, 66, 80),
		OutdoorAmbient = Color3.fromRGB(74, 82, 98),
		DensityAdd = 0.12,
		HazeAdd = 4.2,
		GlareMult = 0,
		SaturationAdd = -0.22,
		ContrastAdd = 0.06,
	},
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(lerp(a.R, b.R, t), lerp(a.G, b.G, t), lerp(a.B, b.B, t))
end

local function sampleKeyframes(clock: number): LightingSample
	local wrapped = clock % 24
	local frames = KEYFRAMES

	for index = 1, #frames - 1 do
		local a = frames[index]
		local b = frames[index + 1]
		if wrapped >= a.ClockTime and wrapped <= b.ClockTime then
			local span = b.ClockTime - a.ClockTime
			local t = if span > 0 then (wrapped - a.ClockTime) / span else 0
			return {
				Brightness = lerp(a.Brightness, b.Brightness, t),
				Ambient = lerpColor(a.Ambient, b.Ambient, t),
				OutdoorAmbient = lerpColor(a.OutdoorAmbient, b.OutdoorAmbient, t),
				ColorShift_Top = lerpColor(a.ColorShift_Top, b.ColorShift_Top, t),
				ColorShift_Bottom = lerpColor(a.ColorShift_Bottom, b.ColorShift_Bottom, t),
				ShadowSoftness = lerp(a.ShadowSoftness, b.ShadowSoftness, t),
				ClockTime = lerp(a.ClockTime, b.ClockTime, t),
				Density = lerp(a.Density, b.Density, t),
				Haze = lerp(a.Haze, b.Haze, t),
				Glare = lerp(a.Glare, b.Glare, t),
				AtmosphereColor = lerpColor(a.AtmosphereColor, b.AtmosphereColor, t),
				AtmosphereDecay = lerpColor(a.AtmosphereDecay, b.AtmosphereDecay, t),
				Saturation = lerp(a.Saturation, b.Saturation, t),
				Contrast = lerp(a.Contrast, b.Contrast, t),
			}
		end
	end

	return frames[#frames]
end

function DayNightConfig.getPhase(clock: number): string
	local hour = clock % 24
	local dayStart = DayNightConfig.DAYLIGHT_CLOCK_START
	local dayEnd = DayNightConfig.DAYLIGHT_CLOCK_END
	if hour >= 5 and hour < dayStart then
		return "Dawn"
	elseif hour >= dayStart and hour < 17 then
		return "Day"
	elseif hour >= 17 and hour < dayEnd then
		return "Dusk"
	end
	return "Night"
end

function DayNightConfig.formatClock(clock: number): string
	local wrapped = clock % 24
	local hour24 = math.floor(wrapped)
	local minutes = math.floor((wrapped - hour24) * 60 + 0.5)
	if minutes >= 60 then
		hour24 += 1
		minutes = 0
	end
	hour24 %= 24

	local suffix = if hour24 >= 12 then "PM" else "AM"
	local hour12 = hour24 % 12
	if hour12 == 0 then
		hour12 = 12
	end

	return string.format("%d:%02d %s", hour12, minutes, suffix)
end

function DayNightConfig.getPhaseIcon(phase: string): string
	if phase == "Dawn" then
		return "🌅"
	elseif phase == "Day" then
		return "☀"
	elseif phase == "Dusk" then
		return "🌇"
	end
	return "🌙"
end

function DayNightConfig.sampleDayLighting(clock: number): LightingSample
	return sampleKeyframes(clock)
end

-- Atmosphere ranges Roblox accepts: Density 0..1, Haze 0..100, Glare 0..100.
-- Density above ~0.6 turns the scene into soup, so it is clamped tighter than the engine max.
local MAX_DENSITY = 0.6
local MAX_HAZE = 10
local MAX_GLARE = 3

function DayNightConfig.applyWeather(day: LightingSample, weatherName: string): LightingSample
	local adjust = WEATHER_ADJUST[weatherName] or WEATHER_ADJUST.Sunny
	return {
		Brightness = day.Brightness * adjust.BrightnessMult,
		Ambient = adjust.Ambient or day.Ambient,
		OutdoorAmbient = adjust.OutdoorAmbient or day.OutdoorAmbient,
		ColorShift_Top = day.ColorShift_Top,
		ColorShift_Bottom = day.ColorShift_Bottom,
		ShadowSoftness = day.ShadowSoftness,
		ClockTime = day.ClockTime,
		Density = math.clamp(day.Density + (adjust.DensityAdd or 0), 0, MAX_DENSITY),
		Haze = math.clamp(day.Haze + (adjust.HazeAdd or 0), 0, MAX_HAZE),
		Glare = math.clamp(day.Glare * (adjust.GlareMult or 1), 0, MAX_GLARE),
		AtmosphereColor = day.AtmosphereColor,
		AtmosphereDecay = day.AtmosphereDecay,
		Saturation = math.clamp(day.Saturation + (adjust.SaturationAdd or 0), -1, 1),
		Contrast = math.clamp(day.Contrast + (adjust.ContrastAdd or 0), -1, 1),
	}
end

local function getCycleOffset(startClock: number): number
	local dayStart = DayNightConfig.DAYLIGHT_CLOCK_START
	local dayEnd = DayNightConfig.DAYLIGHT_CLOCK_END
	local daySpan = dayEnd - dayStart
	local nightSpan = 24 - daySpan
	local dayReal = DayNightConfig.DAY_REAL_SECONDS
	local nightReal = DayNightConfig.NIGHT_REAL_SECONDS
	local hour = startClock % 24

	if hour >= dayStart and hour < dayEnd then
		return ((hour - dayStart) / daySpan) * dayReal
	end

	local nightHour = if hour >= dayEnd then hour - dayEnd else (24 - dayEnd) + hour
	return dayReal + (nightHour / nightSpan) * nightReal
end

function DayNightConfig.computeGameClock(serverStartTime: number, startClock: number, nowTime: number?): number
	local now = nowTime or os.clock()
	local elapsed = now - serverStartTime

	local dayStart = DayNightConfig.DAYLIGHT_CLOCK_START
	local dayEnd = DayNightConfig.DAYLIGHT_CLOCK_END
	local daySpan = dayEnd - dayStart
	local nightSpan = 24 - daySpan
	local dayReal = DayNightConfig.DAY_REAL_SECONDS
	local nightReal = DayNightConfig.NIGHT_REAL_SECONDS
	local cycleLength = dayReal + nightReal
	local cyclePos = (elapsed + getCycleOffset(startClock)) % cycleLength

	if cyclePos < dayReal then
		return dayStart + (cyclePos / dayReal) * daySpan
	end

	local nightPos = cyclePos - dayReal
	return (dayEnd + (nightPos / nightReal) * nightSpan) % 24
end

return DayNightConfig
