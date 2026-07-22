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
}

export type WeatherAdjust = {
	BrightnessMult: number,
	Ambient: Color3?,
	OutdoorAmbient: Color3?,
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
local KEYFRAMES: { LightingSample } = {
	{
		Brightness = 0.8,
		Ambient = Color3.fromRGB(48, 56, 82),
		OutdoorAmbient = Color3.fromRGB(38, 44, 68),
		ColorShift_Top = Color3.fromRGB(0, 0, 10),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ShadowSoftness = 0.6,
		ClockTime = 0,
	},
	{
		Brightness = 0.85,
		Ambient = Color3.fromRGB(52, 60, 88),
		OutdoorAmbient = Color3.fromRGB(42, 48, 72),
		ColorShift_Top = Color3.fromRGB(0, 0, 12),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ShadowSoftness = 0.55,
		ClockTime = 5,
	},
	{
		Brightness = 1.4,
		Ambient = Color3.fromRGB(145, 118, 98),
		OutdoorAmbient = Color3.fromRGB(170, 130, 105),
		ColorShift_Top = Color3.fromRGB(255, 170, 120),
		ColorShift_Bottom = Color3.fromRGB(255, 210, 160),
		ShadowSoftness = 0.35,
		ClockTime = 6.5,
	},
	{
		Brightness = 2.4,
		Ambient = Color3.fromRGB(140, 140, 140),
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		ColorShift_Top = Color3.fromRGB(255, 255, 255),
		ColorShift_Bottom = Color3.fromRGB(255, 255, 255),
		ShadowSoftness = 0.2,
		ClockTime = 10,
	},
	{
		Brightness = 2.6,
		Ambient = Color3.fromRGB(150, 150, 150),
		OutdoorAmbient = Color3.fromRGB(138, 138, 138),
		ColorShift_Top = Color3.fromRGB(255, 255, 255),
		ColorShift_Bottom = Color3.fromRGB(255, 255, 255),
		ShadowSoftness = 0.15,
		ClockTime = 14,
	},
	{
		Brightness = 1.5,
		Ambient = Color3.fromRGB(150, 115, 95),
		OutdoorAmbient = Color3.fromRGB(175, 125, 95),
		ColorShift_Top = Color3.fromRGB(255, 155, 95),
		ColorShift_Bottom = Color3.fromRGB(255, 195, 140),
		ShadowSoftness = 0.35,
		ClockTime = 18.5,
	},
	{
		Brightness = 0.95,
		Ambient = Color3.fromRGB(70, 78, 105),
		OutdoorAmbient = Color3.fromRGB(55, 62, 88),
		ColorShift_Top = Color3.fromRGB(40, 45, 80),
		ColorShift_Bottom = Color3.fromRGB(20, 20, 35),
		ShadowSoftness = 0.5,
		ClockTime = 20,
	},
	{
		Brightness = 0.8,
		Ambient = Color3.fromRGB(48, 56, 82),
		OutdoorAmbient = Color3.fromRGB(38, 44, 68),
		ColorShift_Top = Color3.fromRGB(0, 0, 10),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ShadowSoftness = 0.6,
		ClockTime = 24,
	},
}

local WEATHER_ADJUST: { [string]: WeatherAdjust } = {
	Sunny = {
		BrightnessMult = 1,
	},
	Rain = {
		BrightnessMult = 0.55,
		Ambient = Color3.fromRGB(105, 110, 122),
		OutdoorAmbient = Color3.fromRGB(120, 128, 140),
	},
	Thunderstorm = {
		BrightnessMult = 0.32,
		Ambient = Color3.fromRGB(70, 74, 88),
		OutdoorAmbient = Color3.fromRGB(85, 90, 105),
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
