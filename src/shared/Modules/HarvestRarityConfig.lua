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

-- PointLight + RarityAuras sparkler (+ mesh sheen). No Highlight outline.
-- Common = no overlay. Higher tiers = stronger light + particles + reflectance.
HarvestRarityConfig.GLOW = {
	Uncommon = { brightness = 0.3, range = 3.5, sparklerScale = 0.4 },
	Rare = { brightness = 0.55, range = 5, sparklerScale = 0.7 },
	Epic = { brightness = 0.85, range = 6.5, sparklerScale = 1.05 },
	Legendary = { brightness = 1.05, range = 8, sparklerScale = 1.35 },
	Mythical = { brightness = 1.25, range = 9.5, sparklerScale = 1.65, pulse = true },
	Divine = { brightness = 1.45, range = 11, sparklerScale = 2, pulse = true },
}

-- Subtle “premium” read on the mesh itself (no SurfaceAppearance required).
HarvestRarityConfig.MESH = {
	Uncommon = { reflectance = 0.06, colorTint = 0.06 },
	Rare = { reflectance = 0.12, colorTint = 0.1 },
	Epic = { reflectance = 0.2, colorTint = 0.16 },
	Legendary = { reflectance = 0.28, colorTint = 0.22 },
	Mythical = { reflectance = 0.36, colorTint = 0.28 },
	Divine = { reflectance = 0.45, colorTint = 0.34 },
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

function HarvestRarityConfig.getMeshSettings(rarity: string)
	return HarvestRarityConfig.MESH[rarity]
end

return HarvestRarityConfig
