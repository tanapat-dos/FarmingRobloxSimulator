-- Central economy tuning for the buy → grow → sell → pet loop.

local EconomyBalance = {}

EconomyBalance.STARTING_CASH = 500

EconomyBalance.EGG_ORDER = {
	"Common Egg",
	"Uncommon Egg",
	"Godly Egg",
	"Galactic Egg",
	"Divine Egg",
}

EconomyBalance.PET_BOOST_RANGES = {
	["Common Egg"] = { min = 5, max = 8 },
	["Uncommon Egg"] = { min = 12, max = 18 },
	["Godly Egg"] = { min = 28, max = 38 },
	["Galactic Egg"] = { min = 50, max = 65 },
	["Divine Egg"] = { min = 85, max = 100 },
}

EconomyBalance.PET_BOOSTS = {
	["Common Egg"] = {
		Dog = 5,
		Cat = 6,
		Bear = 6,
		Bull = 7,
		Fox = 7,
		Bunny = 8,
	},
	["Uncommon Egg"] = {
		Lizard = 12,
		Rabbit = 13,
		Deer = 14,
		Star = 14,
		Alien = 15,
		Dragon = 16,
		["Water Dragon"] = 18,
	},
	["Godly Egg"] = {
		["Sand Dweller"] = 28,
		Varan = 30,
		Crepitus = 32,
		Primus = 33,
		Gloxcinia = 34,
		Helios = 35,
		Aether = 36,
		Hyperion = 38,
	},
	["Galactic Egg"] = {
		["Galactic Plushie"] = 50,
		["Galactic Hedgehog"] = 52,
		["Galactic Saturn"] = 54,
		["Galactic System"] = 56,
		["Galactic Angel"] = 58,
		["Galactic Queen"] = 60,
		["Galactic Lord"] = 62,
		["Galactic Overlord"] = 65,
	},
	["Divine Egg"] = {
		Polygonis = 85,
		["Divine Sun"] = 92,
		["The Star of Lakshmi"] = 100,
	},
}

EconomyBalance.PET_GROWTH_REDUCTION = {
	["Godly Egg"] = {
		Varan = 5,
		Primus = 8,
		Gloxcinia = 10,
		Helios = 12,
		Aether = 15,
	},
	["Galactic Egg"] = {
		["Galactic Plushie"] = 6,
		["Galactic Hedgehog"] = 8,
		["Galactic Saturn"] = 10,
		["Galactic System"] = 12,
		["Galactic Angel"] = 14,
		["Galactic Queen"] = 16,
		["Galactic Lord"] = 18,
	},
	["Divine Egg"] = {
		Polygonis = 8,
		["Divine Sun"] = 12,
	},
}

EconomyBalance.EGGS = {
	["Common Egg"] = { cost = 300, rarity = "Common" },
	["Uncommon Egg"] = { cost = 1800, rarity = "Uncommon" },
	["Godly Egg"] = { cost = 7500, rarity = "Rare" },
	["Galactic Egg"] = { cost = 30000, rarity = "Epic" },
	["Divine Egg"] = { cost = 120000, rarity = "Legendary" },
}

EconomyBalance.CROPS = {
	["Carrot Seed"] = { price = 15, baseValue = 6, growthTime = 120, rarity = "Common" },
	["Radish Seed"] = { price = 20, baseValue = 8, growthTime = 180, rarity = "Common" },
	["Wheat Seed"] = { price = 25, baseValue = 10, growthTime = 240, rarity = "Common" },
	["Lettuce Seed"] = { price = 30, baseValue = 12, growthTime = 270, rarity = "Common" },
	["Potato Seed"] = { price = 35, baseValue = 14, growthTime = 300, rarity = "Common" },
	["Beetroot Seed"] = { price = 40, baseValue = 16, growthTime = 330, rarity = "Common" },
	["Tomato Seed"] = { price = 55, baseValue = 22, growthTime = 360, rarity = "Uncommon" },
	["Garlic Seed"] = { price = 65, baseValue = 26, growthTime = 420, rarity = "Uncommon" },
	["Corn Seed"] = { price = 80, baseValue = 32, growthTime = 480, rarity = "Uncommon" },
	["Strawberry Seed"] = { price = 100, baseValue = 40, growthTime = 420, rarity = "Uncommon" },
	["Pepper Seed"] = { price = 130, baseValue = 52, growthTime = 540, rarity = "Uncommon" },
	["Pumpkin Seed"] = { price = 180, baseValue = 72, growthTime = 660, rarity = "Rare" },
	["Grape Seed"] = { price = 250, baseValue = 100, growthTime = 780, rarity = "Rare" },
	["Eggplant Seed"] = { price = 350, baseValue = 140, growthTime = 900, rarity = "Rare" },
	["Pineapple Seed"] = { price = 500, baseValue = 200, growthTime = 1200, rarity = "Epic" },
}

function EconomyBalance.pctToMultiplier(pct)
	return 1 + pct / 100
end

function EconomyBalance.getEggBoostRange(eggName)
	return EconomyBalance.PET_BOOST_RANGES[eggName]
end

function EconomyBalance.formatEggBoostRange(eggName)
	local range = EconomyBalance.getEggBoostRange(eggName)
	if not range then
		return ""
	end
	return string.format("+%d-%d%%", range.min, range.max)
end

function EconomyBalance.getEggBoostMidPct(eggName)
	local range = EconomyBalance.getEggBoostRange(eggName)
	if not range then
		return 0
	end
	return math.floor((range.min + range.max) / 2)
end

function EconomyBalance.getPetBoostPct(eggName, petName)
	local eggPets = EconomyBalance.PET_BOOSTS[eggName]
	if eggPets and eggPets[petName] then
		return eggPets[petName]
	end
	local range = EconomyBalance.getEggBoostRange(eggName)
	if range then
		return math.floor((range.min + range.max) / 2)
	end
	return nil
end

function EconomyBalance.getPetBoostMultiplier(eggName, petName)
	local pct = EconomyBalance.getPetBoostPct(eggName, petName)
	if pct then
		return EconomyBalance.pctToMultiplier(pct)
	end
	return 1
end

function EconomyBalance.getPetGrowthReductionPct(eggName, petName)
	local eggPets = EconomyBalance.PET_GROWTH_REDUCTION[eggName]
	if eggPets and eggPets[petName] then
		return eggPets[petName]
	end
	return 0
end

function EconomyBalance.getEffectiveGrowthTime(baseSeconds, growthReductionPct)
	local reduction = math.clamp(growthReductionPct or 0, 0, 90)
	return math.max(1, baseSeconds * (1 - reduction / 100))
end

function EconomyBalance.getEggData()
	return EconomyBalance.EGGS
end

function EconomyBalance.getEggOrder()
	return EconomyBalance.EGG_ORDER
end

return EconomyBalance
