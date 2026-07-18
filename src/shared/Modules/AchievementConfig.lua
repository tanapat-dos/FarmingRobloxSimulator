--[[
	AchievementConfig — single source of truth for all achievements.

	Each achievement has:
	  id        — unique string key (saved in data)
	  title     — display name
	  desc      — short description shown in the book
	  icon      — emoji icon
	  category  — "Farmer" | "Merchant" | "Collector" | "Harvester" | "Trader" | "Prestige"
	  stat      — which data counter to check (server-side)
	  goal      — numeric target
	  cashReward    — cash paid on completion (pre-multiplier)
	  diamondReward — diamonds paid on completion (flat, 0 = none)
]]

local AchievementConfig = {}

AchievementConfig.CATEGORIES = {
	{ id = "Farmer",    icon = "🌱", color = { r = 88,  g = 202, b = 110 } },
	{ id = "Merchant",  icon = "💰", color = { r = 255, g = 210, b = 80  } },
	{ id = "Collector", icon = "🥚", color = { r = 150, g = 120, b = 255 } },
	{ id = "Harvester", icon = "🌟", color = { r = 255, g = 170, b = 60  } },
	{ id = "Trader",    icon = "📋", color = { r = 120, g = 200, b = 255 } },
	{ id = "Prestige",  icon = "🌟", color = { r = 230, g = 100, b = 255 } },
}

AchievementConfig.LIST = {
	-- ── Farmer (crops planted) ──────────────────────────────────────────
	{ id = "farmer_1",   title = "First Sprout",    desc = "Plant your first 10 crops.",       icon = "🌱", category = "Farmer",    stat = "CropsPlanted", goal = 10,       cashReward = 500,     diamondReward = 0  },
	{ id = "farmer_2",   title = "Green Thumb",     desc = "Plant 50 crops.",                   icon = "🌿", category = "Farmer",    stat = "CropsPlanted", goal = 50,       cashReward = 2000,    diamondReward = 0  },
	{ id = "farmer_3",   title = "Crop Master",     desc = "Plant 200 crops.",                  icon = "🍃", category = "Farmer",    stat = "CropsPlanted", goal = 200,      cashReward = 8000,    diamondReward = 0  },
	{ id = "farmer_4",   title = "Harvest Legend",  desc = "Plant 500 crops.",                  icon = "🌾", category = "Farmer",    stat = "CropsPlanted", goal = 500,      cashReward = 25000,   diamondReward = 5  },
	{ id = "farmer_5",   title = "Field Baron",     desc = "Plant 1,500 crops.",                icon = "🌻", category = "Farmer",    stat = "CropsPlanted", goal = 1500,     cashReward = 60000,   diamondReward = 10 },
	{ id = "farmer_6",   title = "Agricultural God", desc = "Plant 5,000 crops.",               icon = "🌳", category = "Farmer",    stat = "CropsPlanted", goal = 5000,     cashReward = 200000,  diamondReward = 25 },

	-- ── Merchant (total cash earned) ─────────────────────────────────────
	{ id = "merchant_1", title = "First Sale",      desc = "Earn your first $1,000.",           icon = "💵", category = "Merchant",  stat = "TotalEarned",  goal = 1000,     cashReward = 500,     diamondReward = 0  },
	{ id = "merchant_2", title = "Market Regular",  desc = "Earn $10,000 total.",               icon = "💰", category = "Merchant",  stat = "TotalEarned",  goal = 10000,    cashReward = 3000,    diamondReward = 0  },
	{ id = "merchant_3", title = "Tycoon",          desc = "Earn $100,000 total.",              icon = "💎", category = "Merchant",  stat = "TotalEarned",  goal = 100000,   cashReward = 15000,   diamondReward = 5  },
	{ id = "merchant_4", title = "Millionaire",     desc = "Earn $1,000,000 total.",            icon = "🏦", category = "Merchant",  stat = "TotalEarned",  goal = 1000000,  cashReward = 50000,   diamondReward = 20 },
	{ id = "merchant_5", title = "Multi-Millionaire", desc = "Earn $10,000,000 total.",         icon = "🏛️", category = "Merchant",  stat = "TotalEarned",  goal = 10000000, cashReward = 250000,  diamondReward = 40 },
	{ id = "merchant_6", title = "Economy Breaker", desc = "Earn $100,000,000 total.",          icon = "👑", category = "Merchant",  stat = "TotalEarned",  goal = 100000000,cashReward = 1000000, diamondReward = 100 },

	-- ── Collector (pets owned) ───────────────────────────────────────────
	{ id = "collector_1", title = "Pet Owner",      desc = "Own your first pet.",               icon = "🐾", category = "Collector", stat = "PetsOwned",    goal = 1,        cashReward = 1000,    diamondReward = 0  },
	{ id = "collector_2", title = "Pet Lover",      desc = "Own 5 pets.",                       icon = "🐶", category = "Collector", stat = "PetsOwned",    goal = 5,        cashReward = 4000,    diamondReward = 0  },
	{ id = "collector_3", title = "Menagerie",      desc = "Own 10 pets.",                      icon = "🦁", category = "Collector", stat = "PetsOwned",    goal = 10,       cashReward = 12000,   diamondReward = 5  },
	{ id = "collector_4", title = "Noah's Farm",    desc = "Own 25 pets.",                      icon = "🐉", category = "Collector", stat = "PetsOwned",    goal = 25,       cashReward = 40000,   diamondReward = 15 },
	{ id = "collector_5", title = "Zookeeper",      desc = "Own 50 pets.",                      icon = "🦄", category = "Collector", stat = "PetsOwned",    goal = 50,       cashReward = 100000,  diamondReward = 30 },

	-- ── Harvester (fruits harvested / rare finds) ───────────────────────
	{ id = "harvester_1", title = "First Harvest",  desc = "Harvest 25 fruits.",                icon = "🌟", category = "Harvester", stat = "FruitsHarvested", goal = 25,      cashReward = 750,     diamondReward = 0  },
	{ id = "harvester_2", title = "Steady Hands",   desc = "Harvest 150 fruits.",                icon = "✨", category = "Harvester", stat = "FruitsHarvested", goal = 150,     cashReward = 3500,    diamondReward = 0  },
	{ id = "harvester_3", title = "Bountiful",      desc = "Harvest 750 fruits.",                icon = "🌠", category = "Harvester", stat = "FruitsHarvested", goal = 750,     cashReward = 18000,   diamondReward = 5  },
	{ id = "harvester_4", title = "Endless Bounty", desc = "Harvest 3,000 fruits.",              icon = "💫", category = "Harvester", stat = "FruitsHarvested", goal = 3000,    cashReward = 80000,   diamondReward = 15 },
	{ id = "harvester_5", title = "Lucky Find",     desc = "Harvest your first Golden or Rainbow crop.", icon = "🍀", category = "Harvester", stat = "MutationsFound", goal = 1, cashReward = 5000,   diamondReward = 5  },
	{ id = "harvester_6", title = "Mutation Hunter", desc = "Harvest 25 Golden or Rainbow crops.", icon = "🌈", category = "Harvester", stat = "MutationsFound", goal = 25,    cashReward = 60000,   diamondReward = 20 },

	-- ── Trader (orders delivered) ────────────────────────────────────────
	{ id = "trader_1",   title = "Delivery Boy",    desc = "Deliver 5 orders.",                  icon = "📋", category = "Trader",    stat = "OrdersDelivered", goal = 5,       cashReward = 1500,    diamondReward = 0  },
	{ id = "trader_2",   title = "Reliable Courier", desc = "Deliver 25 orders.",                icon = "📦", category = "Trader",    stat = "OrdersDelivered", goal = 25,      cashReward = 8000,    diamondReward = 0  },
	{ id = "trader_3",   title = "Supply Chain Pro", desc = "Deliver 100 orders.",               icon = "🚚", category = "Trader",    stat = "OrdersDelivered", goal = 100,     cashReward = 35000,   diamondReward = 10 },
	{ id = "trader_4",   title = "Logistics Legend", desc = "Deliver 300 orders.",               icon = "🏆", category = "Trader",    stat = "OrdersDelivered", goal = 300,     cashReward = 120000,  diamondReward = 25 },

	-- ── Prestige (rebirths) ──────────────────────────────────────────────
	{ id = "prestige_1", title = "New Beginning",   desc = "Rebirth for the first time.",       icon = "🌟", category = "Prestige",  stat = "Rebirths",        goal = 1,       cashReward = 2000,    diamondReward = 10 },
	{ id = "prestige_2", title = "Reborn Thrice",   desc = "Reach 3 rebirths.",                  icon = "🔥", category = "Prestige",  stat = "Rebirths",        goal = 3,       cashReward = 15000,   diamondReward = 20 },
	{ id = "prestige_3", title = "Cycle Breaker",   desc = "Reach 5 rebirths.",                  icon = "⚡", category = "Prestige",  stat = "Rebirths",        goal = 5,       cashReward = 50000,   diamondReward = 35 },
	{ id = "prestige_4", title = "Eternal Farmer",  desc = "Reach 10 rebirths.",                 icon = "👑", category = "Prestige",  stat = "Rebirths",        goal = 10,      cashReward = 200000,  diamondReward = 75 },
}

-- Fast lookup by id
AchievementConfig.BY_ID = {}
for _, a in AchievementConfig.LIST do
	AchievementConfig.BY_ID[a.id] = a
end

return AchievementConfig
