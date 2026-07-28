local replicatedStorage = game:GetService("ReplicatedStorage")

local modules = replicatedStorage:WaitForChild("Modules")
local seedModule = require(modules.SeedData)
local HarvestRarityConfig = require(modules.HarvestRarityConfig)

local growthMutations = {
	["None"] = 1,
	["Golden"] = 3,
	["Rainbow"] = 8,
}

-- Applied by WeatherService while Rain / Thunderstorm is active. Wet and Shocked are
-- mutually exclusive (Shocked takes priority) rather than stacking multiplicatively — a fruit
-- can carry both mutation strings (Thunderstorm can roll either), but only the stronger one
-- counts toward sell value.
local environmentalMutations = {
	["None"] = 1,
	["Wet"] = 1.25,
	["Shocked"] = 2.00,
}

return function(fruitData: any)
	local mutations = fruitData.Mutations
	local weight = fruitData.Weight
	local fruitName = fruitData.FruitName
	local rarity = fruitData.Rarity or "Common"

	local seedData = seedModule.getData(fruitName .. " Seed")
	if seedData and mutations and weight and fruitName then
		local baseValue = seedData.BaseValue.Value

		local growthMutationMultiplier: number = growthMutations.None
		if #mutations > 0 then
			for mut: string, number: number in growthMutations do
				if table.find(mutations, mut) then
					growthMutationMultiplier = number
				end
			end
		end

		local rarityMultiplier = HarvestRarityConfig.getMultiplier(rarity)

		-- Environmental mutations are mutually exclusive: a fruit can carry both "Wet" and
		-- "Shocked" mutation strings (Thunderstorm rolls either independently), but only the
		-- stronger one (Shocked) counts toward sell value.
		local environmentalMultipler: number = environmentalMutations.None
		if #mutations > 0 then
			if table.find(mutations, "Shocked") then
				environmentalMultipler = environmentalMutations.Shocked
			elseif table.find(mutations, "Wet") then
				environmentalMultipler = environmentalMutations.Wet
			end
		end

		return baseValue * weight ^ 1.5 * growthMutationMultiplier * rarityMultiplier * environmentalMultipler
	end
	return 10
end
