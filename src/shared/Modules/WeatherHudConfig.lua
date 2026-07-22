--!strict
-- Weather banner copy for the top-right status stack.

local WeatherHudConfig = {}

WeatherHudConfig.BANNER_TEXT = {
	Sunny = "☀️ Sunny — clear skies",
	Rain = "🌧 Rain — crops can turn <b>Wet</b> (x2 value)!",
	Thunderstorm = "⛈ Thunderstorm — <b>Wet</b> x2 and rare <b>Shocked</b> x8!",
}

function WeatherHudConfig.getBannerText(weatherName: string): string?
	return WeatherHudConfig.BANNER_TEXT[weatherName]
end

return WeatherHudConfig
