local EconomyBalance = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules").EconomyBalance)

local template = {
	Cash = EconomyBalance.STARTING_CASH,
	Inventory = {},
	PlotData = {},
	OwnedPets = {},
	EquippedPet = nil,
	OrderStats = { Completed = 0 },
	PlotsOwned = EconomyBalance.PLOTS.startOwned,
}

return template
