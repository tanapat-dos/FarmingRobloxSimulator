-- Central economy tuning for the buy → grow → sell → pet loop.
-- Target pacing (solo, ~8 active plots):
--   Common Egg ~6–8 min | Uncommon ~15–20 min | Godly ~60–75 min
--   Galactic ~2–3 hrs | Divine ~8–10 hrs (multi-session retention)

local EconomyBalance = {}

EconomyBalance.STARTING_CASH = 100

-- Global seed shop restock (also shown on the seed shop HUD timer).
EconomyBalance.SEED_SHOP = {
	restockIntervalSeconds = 300,
}

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
-- Cumulative cost of all 7 purchasable beds: $4.5M. Together with the growth upgrades
-- (~$6.06M) that is ~$10.6M of sinks, tuned to complete in roughly 2-3 days of engaged play
-- and to land just before the $15M-earned Mythical unlock — so permanent upgrades finish as
-- the top crop tier opens rather than leaving the player with nothing to buy.
-- Bed 2 stays cheap so the first expansion is still a first-session goal.
EconomyBalance.PLOTS = {
	startOwned = 1,
	maxOwned = 8,
	cropsPerPlot = 10,
	-- prices[n] = cost of the nth bed (index 1 is the free starter bed)
	prices = { 0, 5000, 20000, 75000, 200000, 500000, 1200000, 2500000 },
}

-- Mature crop height in the garden (studs at plantSize 1), after per-crop mesh normalization.
EconomyBalance.PLANT_DISPLAY = {
	targetMatureHeightStuds = 6.75,
	minNormalizeFactor = 0.2,
	maxNormalizeFactor = 2.25,
	-- Optional per-crop mature height target (studs at plantSize 1).
	cropTargetHeightStuds = {
		Carrot = 3.8,
		Wheat = 4.2,
		Lettuce = 3.6,
	},
	-- Fine-tune outliers (multiplies height normalize factor after clamp).
	cropHeightMultiplier = {
		Carrot = 0.55,
		Mango = 1.65,
	},
	-- Multi-harvest fruit clones (asset template × world scale × this).
	cropFruitDisplayScale = {
		Mango = 1.08,
	},
	-- Hotbar / hand tool size (harvest weight × base × crop override × fruit display).
	heldToolBaseScale = 0.48,
	cropHeldToolScale = {
		Mango = 0.58,
		Pineapple = 0.72,
		Pumpkin = 0.78,
	},
}

-- Garden upgrades purchased from the Upgrade Board (server authoritative).
-- GrowthReduction: leveled, permanent % off crop grow time. levels[n] is the
-- state AT level n (pct = total reduction, price = cost to go from n-1 -> n).
-- Maxing all 8 levels costs $6.06M cumulative. Paired with the plot beds ($4.5M) this is
-- ~$10.6M of sinks, targeted at roughly 2-3 days of engaged play to complete.
EconomyBalance.UPGRADES = {
	GrowthReduction = {
		levels = {
			{ pct = 5,  price = 8000 },
			{ pct = 10, price = 25000 },
			{ pct = 15, price = 80000 },
			{ pct = 20, price = 200000 },
			{ pct = 25, price = 450000 },
			{ pct = 30, price = 900000 },
			{ pct = 35, price = 1600000 },
			{ pct = 40, price = 2800000 },
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

-- BaseValue drives sell price via GetFruitValue:
--   revenue = baseValue * weight^2 * mutations * rarity
--
-- Every value below is derived, not hand-picked. With E[weight^2] = 2.99 (from the
-- `1 + r^2.2 * 2` size roll), E[mutation] = 2.43 (1% Rainbow x50, ~4.95% Golden x20) and
-- the per-tier harvest-quality average from HarvestRarityConfig.CROP_BIAS, the expected
-- revenue per baseValue point is M(tier):
--
--   Common 7.85 | Uncommon 8.46 | Rare 9.42 | Epic 10.34 | Legendary 11.81 | Mythical 12.99
--
-- Each crop satisfies `baseValue * M = 2 * price`, so a cycle returns ~2x the seed cost, and
-- growthTime rises more slowly than value so profit per slot-hour roughly DOUBLES per tier:
--
--   Common $600 | Uncommon $1.2K | Rare $2.5K | Epic $5K | Legendary $10K | Mythical $20K
--
-- Verify with tools/VerifyEconomyMath.lua after any edit here.
--
-- `rarity` is both the shop-stock tier and the unlock tier (see CropTierConfig).
--
-- IMPORTANT: SeedData (ReplicatedStorage.Modules.SeedData, an instance tree) is what the
-- game actually reads at runtime. Editing this table alone changes nothing — run
-- tools/MigrateSeedDataEconomy.lua to push these values into SeedData.
EconomyBalance.CROPS = {
	-- Common — no unlock gate
	["Carrot Seed"] = { price = 25, baseValue = 6.4, growthTime = 150, rarity = "Common" },
	["Wheat Seed"] = { price = 35, baseValue = 8.9, growthTime = 210, rarity = "Common" },

	-- Uncommon — no unlock gate
	["Lettuce Seed"] = { price = 90, baseValue = 21.3, growthTime = 270, rarity = "Uncommon" },
	["Potato Seed"] = { price = 100, baseValue = 23.6, growthTime = 300, rarity = "Uncommon" },
	["Beetroot Seed"] = { price = 110, baseValue = 26, growthTime = 330, rarity = "Uncommon" },

	-- Rare — $25K earned
	["Tomato Seed"] = { price = 270, baseValue = 57.3, growthTime = 390, rarity = "Rare" },
	["Garlic Seed"] = { price = 290, baseValue = 61.6, growthTime = 420, rarity = "Rare" },
	["Corn Seed"] = { price = 315, baseValue = 66.9, growthTime = 450, rarity = "Rare" },

	-- Epic — $250K earned + 3 plots
	["Strawberry Seed"] = { price = 750, baseValue = 145.2, growthTime = 540, rarity = "Epic" },
	["Pepper Seed"] = { price = 840, baseValue = 162.6, growthTime = 600, rarity = "Epic" },
	["Pumpkin Seed"] = { price = 920, baseValue = 178.1, growthTime = 660, rarity = "Epic" },

	-- Legendary — $2M earned + 500 fruits harvested
	["Grape Seed"] = { price = 2350, baseValue = 398, growthTime = 840, rarity = "Legendary" },
	["Eggplant Seed"] = { price = 2500, baseValue = 423.4, growthTime = 900, rarity = "Legendary" },
	["Pineapple Seed"] = { price = 2670, baseValue = 452.2, growthTime = 960, rarity = "Legendary" },

	-- Mythical — $15M earned + 10 mutations found
	["Candy Vine Seed"] = { price = 5650, baseValue = 869.7, growthTime = 1020, rarity = "Mythical" },
	["Red Mushroom Seed"] = { price = 6000, baseValue = 923.6, growthTime = 1080, rarity = "Mythical" },
	["Bubble Rash Seed"] = { price = 6350, baseValue = 977.7, growthTime = 1140, rarity = "Mythical" },

	-- Apex crop. Bought with Fish Coins (see FishCoinShopService), so `price = 0` here:
	-- its entire output is profit, which is why it beats every cash crop at ~$39K/slot-hr.
	-- Fish Coin supply is the throttle — steady fishing sustains only ~2-3 slots.
	-- Highest baseValue in the game, so also the most valuable single fruit.
	["Crystal Blooms Seed"] = {
		price = 0,
		fishCoinPrice = 150,
		baseValue = 1000,
		growthTime = 1200,
		rarity = "Mythical",
	},

	-- The ONLY perennial. multiHarvest/harvestCount/harvestInterval are bound to fruit
	-- attachment points on the mesh and MUST NOT be changed without new art.
	-- 4 slots re-ripening every 600s = 24 fruits/hour forever, so seed cost amortises away
	-- and the meaningful figures are the perpetual hourly rate and the payback period.
	-- Mango also uses a reduced size roll (`0.75 + r^2.2 * 1.1`, E[weight^2] = 1.302), so its
	-- per-fruit multiplier is 5.66 rather than 12.99.
	-- baseValue 147 -> ~$20K/hr in perpetuity; $60K price -> ~3.0h payback.
	["Mango Seed"] = {
		price = 60000,
		baseValue = 147,
		growthTime = 1260,
		rarity = "Mythical",
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
