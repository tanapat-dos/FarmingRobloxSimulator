local EconomyBalance = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules").EconomyBalance)

local template = {
	Cash = EconomyBalance.STARTING_CASH,
	Diamonds = 0, -- premium currency (bought with Robux, spent on Legendary eggs)
	Inventory = {},
	PlotData = {},
	OwnedPets = {},
	EquippedPet = nil,
	OrderStats = { Completed = 0 },
	FishingStats = { TotalCaught = 0, PerfectCasts = 0 },
	PlotsOwned = EconomyBalance.PLOTS.startOwned,
	GrowthUpgradeLevel = 0,
	DailyLogin = {
		LastClaimDay = 0,
		Streak = 0,
	},
	AchievementStats = {   -- running totals tracked server-side
		CropsPlanted    = 0,
		TotalEarned     = 0,
		PetsOwned       = 0,
		FruitsHarvested = 0,
		MutationsFound  = 0,
		OrdersDelivered = 0,
		Rebirths        = 0,
	},
	AchievementsClaimed = {}, -- set of claimed achievement ids { [id] = true }
	Rebirths = 0,
}

return template
