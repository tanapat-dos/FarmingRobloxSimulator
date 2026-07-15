--!strict
-- Ambient weather audio config (swap SoundIds or add templates under ReplicatedStorage.Sounds).

export type AmbientConfig = {
	SoundId: string,
	Volume: number,
	Looped: boolean,
}

local WeatherSounds = {}

-- Default loops — override via ReplicatedStorage.Sounds/Weather* templates if needed.
WeatherSounds.AMBIENT = {
	Sunny = {
		SoundId = "rbxassetid://97357579003831",
		Volume = 0.22,
		Looped = true,
	},
	Rain = {
		SoundId = "rbxassetid://1516791621",
		Volume = 0.38,
		Looped = true,
	},
	Thunderstorm = {
		SoundId = "rbxassetid://82247046952844",
		Volume = 0.48,
		Looped = true,
	},
}

WeatherSounds.THUNDER_CRACK = {
	SoundId = "rbxassetid://82247046952844",
	Volume = 0.7,
	Looped = false,
}

WeatherSounds.FADE_SECONDS = 1.8

local TEMPLATE_NAMES = {
	Sunny = "WeatherSunny",
	Rain = "WeatherRain",
	Thunderstorm = "WeatherThunderstorm",
	ThunderCrack = "WeatherThunder",
}

function WeatherSounds.getAmbientConfig(weatherName: string, soundsFolder: Instance?): AmbientConfig?
	local templateName = TEMPLATE_NAMES[weatherName]
	if soundsFolder and templateName then
		local template = soundsFolder:FindFirstChild(templateName)
		if template and template:IsA("Sound") then
			return {
				SoundId = template.SoundId,
				Volume = template.Volume,
				Looped = template.Looped,
			}
		end
	end

	local config = WeatherSounds.AMBIENT[weatherName]
	if config then
		return config
	end
	return WeatherSounds.AMBIENT.Sunny
end

function WeatherSounds.getThunderConfig(soundsFolder: Instance?): AmbientConfig
	if soundsFolder then
		local template = soundsFolder:FindFirstChild(TEMPLATE_NAMES.ThunderCrack)
		if template and template:IsA("Sound") then
			return {
				SoundId = template.SoundId,
				Volume = template.Volume,
				Looped = false,
			}
		end
	end
	return WeatherSounds.THUNDER_CRACK
end

return WeatherSounds
