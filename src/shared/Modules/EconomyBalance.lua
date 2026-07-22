-- Central economy tuning for the buy → grow → sell → pet loop.
-- Target pacing (solo, ~8 active plots):
--   Common Egg ~6–8 min | Uncommon ~15–20 min | Godly ~60–75 min
--   Galactic ~2–3 hrs | Divine ~8–10 hrs (multi-session retention)

local EconomyBalance = {}

EconomyBalance.STARTING_CASH = 100

-- 7-day daily login streak (cash before rebirth/pet multipliers).
EconomyBalance.DAILY_LOGIN_REWARDS = {
	{ day = 1, cash = 50, diamonds = 0 },
	{ day = 2, cash = 100, diamonds = 0 },
	{ day = 3, cash = 200, diamonds = 0 },
	{ day = 4, cash = 350, diamonds = 0 },
	{ day = 5, cash = 600, diamonds = 0 },
	{ day = 6, cash = 1000, diamonds = 0 },
	{ day = 7, cash = 2000, diamonds = 10 },
}

-- Plot progression: every garden has 8 physical soil beds; bed 1 is free,
-- beds 2..maxOwned are purchasable in order, the rest stay reserved.
-- Rescaled to use all 8 physical beds with a steep exponential curve —
-- unlocking the last plot is a genuine late-game milestone, not a Day 1 buy.
EconomyBalance.PLOTS = {
	startOwned = 1,
	maxOwned = 8,
	cropsPerPlot = 10,
	-- prices[n] = cost of the nth bed (index 1 is the free starter bed)
	prices = { 0, 5000, 20000, 60000, 150000, 350000, 750000, 1500000 },
}

-- Mature crop height in the garden (studs at plantSize 1), after per-crop mesh normalization.
EconomyBalance.PLANT_DISPLAY = {
	targetMatureHeightStuds = 6.75,
	minNormalizeFactor = 0.2,
	maxNormalizeFactor = 3.5,
	-- Fine-tune outliers (multiplies height normalize factor after clamp).
	cropHeightMultiplier = {
		Carrot = 0.78,
	},
}

-- Garden upgrades purchased from the Upgrade Board (server authoritative).
-- GrowthReduction: leveled, permanent % off crop grow time. levels[n] is the
-- state AT level n (pct = total reduction, price = cost to go from n-1 -> n).
-- Rescaled to 8 levels with a much steeper curve: maxing out now costs
-- ~$2.9M cumulative (vs. ~$180k before), so it's a long-term grind rather
-- than something a player finishes in one or two sessions.
EconomyBalance.UPGRADES = {
	GrowthReduction = {
		levels = {
			{ pct = 5,  price = 8000 },
			{ pct = 10, price = 25000 },
			{ pct = 15, price = 70000 },
			{ pct = 20, price = 160000 },
			{ pct = 25, price = 350000 },
			{ pct = 30, price = 650000 },
			{ pct = 35, price = 1100000 },
			{ pct = 40, price = 1800000 },
		},
	},
}

-- Rebirth: reset cash/seeds/crops/plots for a permanent sell multiplier.
EconomyBalance.REBIRTH = {
	baseCost = 250000,
	costMult = 4, -- rebirth N costs baseCost * costMult^N
	boostPerRebirth = 0.25, -- +25% permanent sell value per rebirth
}

-- Procedural gear (no .rbxl assets: tools are built in code like pet tools).
EconomyBalance.GEAR = {
	["Fertilizer"] = {
		price = 750,
		color = Color3.fromRGB(133, 97, 61),
		description = "Instantly finishes growing your nearest crop.",
	},
	["Mutation Spray"] = {
		price = 3500,
		color = Color3.fromRGB(120, 220, 255),
		description = "Sprays your nearest crop: guaranteed Golden, 25% Rainbow.",
	},
}

EconomyBalance.EGG_ORDER = {
	"Common Egg",
	"Uncommon Egg",
	"Godly Egg",
	"Galactic Egg",
	"Divine Egg",
}

-- Cash boost % range shown on egg cards (each pet rolls a fixed value inside the range).
EconomyBalance.PET_BOOST_RANGES = {
	["Common Egg"] = { min = 5, max = 8 },
	["Uncommon Egg"] = { min = 12, max = 18 },
	["Godly Egg"] = { min = 28, max = 38 },
	["Galactic Egg"] = { min = 50, max = 65 },
	["Divine Egg"] = { min = 85, max = 100 },
}

-- Per-pet cash boost % (must fall within PET_BOOST_RANGES for that egg).
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

-- Optional grow-time reduction % for specific pets (Godly / Galactic / Divine tiers).
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

-- Legendary tier (Divine) is premium: bought with Diamonds only, not cash,
-- and is excluded from the cash restock shop.
EconomyBalance.EGGS = {
	["Common Egg"] = { cost = 300, rarity = "Common" },
	["Uncommon Egg"] = { cost = 1800, rarity = "Uncommon" },
	["Godly Egg"] = { cost = 7500, rarity = "Rare" },
	["Galactic Egg"] = { cost = 30000, rarity = "Epic" },
	["Divine Egg"] = { cost = 120000, rarity = "Legendary", currency = "Diamonds", diamondCost = 100 },
}

-- BaseValue drives sell price via GetFruitValue (baseValue * weight^2 * mutations * rarity).
-- Price and GrowthTime increase per tier; ROI improves slowly to reward progression.
EconomyBalance.CROPS = {
	["Carrot Seed"] = { price = 30, baseValue = 2, growthTime = 5, rarity = "Common" },
	["Radish Seed"] = { price = 40, baseValue = 2, growthTime = 180, rarity = "Common" },
	["Wheat Seed"] = { price = 50, baseValue = 2, growthTime = 240, rarity = "Common" },
	["Lettuce Seed"] = { price = 60, baseValue = 3, growthTime = 270, rarity = "Common" },
	["Potato Seed"] = { price = 70, baseValue = 3, growthTime = 300, rarity = "Common" },
	["Beetroot Seed"] = { price = 80, baseValue = 3, growthTime = 330, rarity = "Common" },
	["Tomato Seed"] = { price = 110, baseValue = 4, growthTime = 360, rarity = "Uncommon" },
	["Garlic Seed"] = { price = 130, baseValue = 5, growthTime = 420, rarity = "Uncommon" },
	["Corn Seed"] = { price = 160, baseValue = 6, growthTime = 480, rarity = "Uncommon" },
	["Strawberry Seed"] = { price = 200, baseValue = 8, growthTime = 420, rarity = "Uncommon" },
	["Pepper Seed"] = { price = 260, baseValue = 10, growthTime = 540, rarity = "Uncommon" },
	["Pumpkin Seed"] = { price = 360, baseValue = 14, growthTime = 660, rarity = "Rare" },
	["Grape Seed"] = { price = 500, baseValue = 20, growthTime = 780, rarity = "Rare" },
	["Eggplant Seed"] = { price = 700, baseValue = 28, growthTime = 900, rarity = "Rare" },
	["Pineapple Seed"] = { price = 1000, baseValue = 40, growthTime = 1200, rarity = "Epic" },
	["Bubble Rash Seed"] = { price = 1200, baseValue = 48, growthTime = 1350, rarity = "Epic" },
	["Crystal Blooms Seed"] = { price = 1300, baseValue = 50, growthTime = 1400, rarity = "Epic" },
	["Mango Seed"] = {
		price = 1600,
		baseValue = 54,
		growthTime = 1500,
		rarity = "Epic",
		multiHarvest = true,
		harvestCount = 4,
		harvestInterval = 600,
	},
}

function EconomyBalance.pctToMultiplier(pct: number): number
	return 1 + pct / 100
end

function EconomyBalance.getEggBoostRange(eggName: string): { min: number, max: number }?
	return EconomyBalance.PET_BOOST_RANGES[eggName]
end

function EconomyBalance.formatEggBoostRange(eggName: string): string
	local range = EconomyBalance.getEggBoostRange(eggName)
	if not range then
		return ""
	end
	return string.format("+%d-%d%%", range.min, range.max)
end

function EconomyBalance.getEggBoostMidPct(eggName: string): number
	local range = EconomyBalance.getEggBoostRange(eggName)
	if not range then
		return 0
	end
	return math.floor((range.min + range.max) / 2)
end

function EconomyBalance.getPetBoostPct(eggName: string, petName: string): number?
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

function EconomyBalance.getPetBoostMultiplier(eggName: string, petName: string): number
	local pct = EconomyBalance.getPetBoostPct(eggName, petName)
	if pct then
		return EconomyBalance.pctToMultiplier(pct)
	end
	return 1
end

function EconomyBalance.getPetGrowthReductionPct(eggName: string, petName: string): number
	local eggPets = EconomyBalance.PET_GROWTH_REDUCTION[eggName]
	if eggPets and eggPets[petName] then
		return eggPets[petName]
	end
	return 0
end

function EconomyBalance.getEffectiveGrowthTime(baseSeconds: number, growthReductionPct: number): number
	local reduction = math.clamp(growthReductionPct or 0, 0, 90)
	return math.max(1, baseSeconds * (1 - reduction / 100))
end

-- Growth reductions from pets and the Upgrade Board stack additively, capped at 90%.
function EconomyBalance.getTotalGrowthReduction(petPct: number?, upgradePct: number?): number
	local pet = typeof(petPct) == "number" and petPct or 0
	local upgrade = typeof(upgradePct) == "number" and upgradePct or 0
	return math.clamp(pet + upgrade, 0, 90)
end

function EconomyBalance.getGrowthUpgradeMaxLevel(): number
	return #EconomyBalance.UPGRADES.GrowthReduction.levels
end

-- Total grow-time reduction % granted at a given upgrade level (0 = none).
function EconomyBalance.getGrowthUpgradePct(level: number): number
	local levels = EconomyBalance.UPGRADES.GrowthReduction.levels
	local lvl = math.clamp(math.floor(level or 0), 0, #levels)
	if lvl <= 0 then
		return 0
	end
	return levels[lvl].pct
end

-- Cost to purchase the given level (nil if out of range / already maxed).
function EconomyBalance.getGrowthUpgradePrice(level: number): number?
	local levels = EconomyBalance.UPGRADES.GrowthReduction.levels
	local entry = levels[math.floor(level or 0)]
	return entry and entry.price or nil
end

function EconomyBalance.getEggData(): { [string]: { cost: number, rarity: string } }
	return EconomyBalance.EGGS
end

-- True for premium eggs paid in Diamonds (excluded from the cash restock shop).
function EconomyBalance.isDiamondEgg(eggName: string): boolean
	local egg = EconomyBalance.EGGS[eggName]
	return egg ~= nil and egg.currency == "Diamonds"
end

function EconomyBalance.getEggOrder(): { string }
	return EconomyBalance.EGG_ORDER
end

return EconomyBalance
