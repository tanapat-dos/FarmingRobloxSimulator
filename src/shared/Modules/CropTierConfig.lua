--!strict
--[[
	CropTierConfig — crop tier ladder and unlock gates.

	Shared so the server (SeedShopService, FishCoinShopService) and the client (shop UI
	tooltips) evaluate identical rules. The server is always the authority: a locked crop is
	excluded from generated stock AND re-checked in the purchase handler.

	Gates read stats the game already tracks, so no new persistence is needed:
	  TotalEarned / FruitsHarvested / MutationsFound / CropsPlanted / OrdersDelivered
	      from data.AchievementStats
	  PlotsOwned  from data.PlotsOwned
	  FishCaught  from data.FishingStats.TotalCaught

	Deliberately does NOT gate on Rebirths. The rebirth loop is unbalanced (exponential cost
	against a linear boost, and it resets PlotsOwned), so tier access must not depend on it.
]]

local CropTierConfig = {}

export type Gate = {
	stat: string,
	goal: number,
	label: string,
}

export type Tier = {
	label: string,
	gates: { Gate },
}

-- Ascending order. Also the display order for locked rows in the shop.
CropTierConfig.TIER_ORDER = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythical",
}

--[[
	All gates removed: every tier is visible to every player from the start. Progression is
	gated entirely by price and shop stock RNG instead (see ShopStock.APPEAR_CHANCE_BY_RARITY
	and SEED_STOCK_RANGE) — a Mythical crop can show up and be bought by anyone who can afford
	it, they just won't see it every restock and won't have many units to buy when they do.

	Originally gated on TotalEarned/PlotsOwned/FruitsHarvested/MutationsFound (via
	AchievementStats), which stacked with the RNG stock wall: a $15M-earned requirement meant
	Mythical crops were invisible for hours of normal play even though the RNG alone would
	have surfaced them. Removed rather than tuned down, since ANY earned-based gate re-creates
	the same problem at a different threshold.

	isUnlocked/getUnlockProgress/buildStats are kept (all tiers just return unlocked=true) so
	SeedShopService and the shop UI don't need to change — the gating hook still exists for a
	future feature that actually needs it (e.g. a rebirth-gated tier), it is just unused today.
]]
CropTierConfig.TIERS = {
	Common = { label = "Common", gates = {} },
	Uncommon = { label = "Uncommon", gates = {} },
	Rare = { label = "Rare", gates = {} },
	Epic = { label = "Epic", gates = {} },
	Legendary = { label = "Legendary", gates = {} },
	Mythical = { label = "Mythical", gates = {} },
} :: { [string]: Tier }

-- Every crop belongs to exactly one tier (design Correctness Property 6).
CropTierConfig.SEED_TIER = {
	["Carrot Seed"] = "Common",
	["Wheat Seed"] = "Common",

	["Lettuce Seed"] = "Uncommon",
	["Potato Seed"] = "Uncommon",
	["Beetroot Seed"] = "Uncommon",

	["Tomato Seed"] = "Rare",
	["Garlic Seed"] = "Rare",
	["Corn Seed"] = "Rare",

	["Strawberry Seed"] = "Epic",
	["Pepper Seed"] = "Epic",
	["Pumpkin Seed"] = "Epic",

	["Grape Seed"] = "Legendary",
	["Eggplant Seed"] = "Legendary",
	["Pineapple Seed"] = "Legendary",

	["Candy Vine Seed"] = "Mythical",
	["Red Mushroom Seed"] = "Mythical",
	["Bubble Rash Seed"] = "Mythical",
	["Mango Seed"] = "Mythical",
	["Crystal Blooms Seed"] = "Mythical",
}

-- ------------------------------------------------------------------ stats

--[[
	Flattens a player's profile data into the stat table the gates read.
	Missing fields resolve to 0 so profiles saved before a stat existed gate correctly
	rather than erroring.
]]
function CropTierConfig.buildStats(data: any): { [string]: number }
	local achievementStats = (data and data.AchievementStats) or {}
	local fishingStats = (data and data.FishingStats) or {}

	return {
		TotalEarned = achievementStats.TotalEarned or 0,
		CropsPlanted = achievementStats.CropsPlanted or 0,
		FruitsHarvested = achievementStats.FruitsHarvested or 0,
		MutationsFound = achievementStats.MutationsFound or 0,
		OrdersDelivered = achievementStats.OrdersDelivered or 0,
		PlotsOwned = (data and data.PlotsOwned) or 0,
		FishCaught = fishingStats.TotalCaught or 0,
	}
end

-- ------------------------------------------------------------------ queries

-- Returns nil for unknown seeds so callers fail closed rather than defaulting to Common.
function CropTierConfig.getTierForSeed(seedName: string): string?
	return CropTierConfig.SEED_TIER[seedName]
end

function CropTierConfig.getTierIndex(tierName: string): number?
	return table.find(CropTierConfig.TIER_ORDER, tierName)
end

--[[
	Per-gate progress, for locked-row tooltips in the shop.
	Returns an empty list for an ungated tier, and nil for an unknown tier.
]]
function CropTierConfig.getUnlockProgress(
	stats: { [string]: number },
	tierName: string
): { { stat: string, label: string, have: number, goal: number, met: boolean } }?
	local tier = CropTierConfig.TIERS[tierName]
	if not tier then
		return nil
	end

	local progress = {}
	for _, gate in tier.gates do
		local have = stats[gate.stat] or 0
		table.insert(progress, {
			stat = gate.stat,
			label = gate.label,
			have = have,
			goal = gate.goal,
			met = have >= gate.goal,
		})
	end
	return progress
end

-- All gates must pass. Unknown tiers are locked (fail closed).
function CropTierConfig.isUnlocked(stats: { [string]: number }, tierName: string): boolean
	local tier = CropTierConfig.TIERS[tierName]
	if not tier then
		return false
	end
	for _, gate in tier.gates do
		if (stats[gate.stat] or 0) < gate.goal then
			return false
		end
	end
	return true
end

-- Convenience: gate check straight from a seed name. Unknown seeds are locked.
function CropTierConfig.isSeedUnlocked(stats: { [string]: number }, seedName: string): boolean
	local tier = CropTierConfig.getTierForSeed(seedName)
	if not tier then
		return false
	end
	return CropTierConfig.isUnlocked(stats, tier)
end

return CropTierConfig
