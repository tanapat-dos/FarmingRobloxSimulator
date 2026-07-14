-- Harvest rarity tiers, sell multipliers, and crop-biased roll weights.

local HarvestRarityConfig = {
	TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Divine" },

	MULTIPLIERS = {
		Common = 1,
		Uncommon = 1.15,
		Rare = 1.35,
		Epic = 1.6,
		Legendary = 2,
		Mythical = 2.5,
		Divine = 3,
	},

	-- Seed shop tier → harvest quality odds (percent, should sum ~100)
	CROP_BIAS = {
		Common = {
			Common = 62,
			Uncommon = 28,
			Rare = 9,
			Epic = 1,
			Legendary = 0,
			Mythical = 0,
			Divine = 0,
		},
		Uncommon = {
			Common = 35,
			Uncommon = 40,
			Rare = 20,
			Epic = 4,
			Legendary = 1,
			Mythical = 0,
			Divine = 0,
		},
		Rare = {
			Common = 12,
			Uncommon = 33,
			Rare = 40,
			Epic = 12,
			Legendary = 2,
			Mythical = 1,
			Divine = 0,
		},
		Epic = {
			Common = 5,
			Uncommon = 18,
			Rare = 42,
			Epic = 28,
			Legendary = 5,
			Mythical = 2,
			Divine = 0,
		},
		Legendary = {
			Common = 0,
			Uncommon = 10,
			Rare = 30,
			Epic = 35,
			Legendary = 18,
			Mythical = 5,
			Divine = 2,
		},
		Mythical = {
			Common = 0,
			Uncommon = 5,
			Rare = 20,
			Epic = 35,
			Legendary = 25,
			Mythical = 10,
			Divine = 5,
		},
		Divine = {
			Common = 0,
			Uncommon = 0,
			Rare = 10,
			Epic = 25,
			Legendary = 35,
			Mythical = 20,
			Divine = 10,
		},
		Prismatic = {
			Common = 0,
			Uncommon = 0,
			Rare = 5,
			Epic = 20,
			Legendary = 35,
			Mythical = 25,
			Divine = 15,
		},
	},
}

-- Legacy-style mesh glow (Highlight fill + PointLight). No aura mesh/asset required.
HarvestRarityConfig.GLOW = {
	Uncommon = { fillTransparency = 0.84, outlineTransparency = 0.45, brightness = 0.55, range = 5 },
	Rare = { fillTransparency = 0.74, outlineTransparency = 0.3, brightness = 0.8, range = 6 },
	Epic = { fillTransparency = 0.64, outlineTransparency = 0.2, brightness = 1, range = 7 },
	Legendary = { fillTransparency = 0.54, outlineTransparency = 0.12, brightness = 1.15, range = 8 },
	Mythical = { fillTransparency = 0.44, outlineTransparency = 0.08, brightness = 1.3, range = 9 },
	Divine = { fillTransparency = 0.34, outlineTransparency = 0.04, brightness = 1.45, range = 10 },
}

function HarvestRarityConfig.isTier(name: string): boolean
	return HarvestRarityConfig.MULTIPLIERS[name] ~= nil
end

function HarvestRarityConfig.getMultiplier(rarity: string): number
	return HarvestRarityConfig.MULTIPLIERS[rarity] or 1
end

function HarvestRarityConfig.getGlowSettings(rarity: string)
	return HarvestRarityConfig.GLOW[rarity]
end

return HarvestRarityConfig
