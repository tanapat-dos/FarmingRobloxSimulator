local replicatedStorage = game:GetService("ReplicatedStorage")

local modules = replicatedStorage:WaitForChild("Modules")
local seedModule = require(modules.SeedData)
local HarvestRarityConfig = require(modules.HarvestRarityConfig)

local growthMutations = {
	["None"] = 1,
	["Golden"] = 20,
	["Rainbow"] = 50,
}

-- Applied by WeatherService while Rain / Thunderstorm is active.
local environmentalMutations = {
	["None"] = 1,
	["Wet"] = 2,
	["Shocked"] = 8,
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

		-- Environmental mutations stack multiplicatively (Wet + Shocked is
		-- possible during a thunderstorm, and both are rare).
		local environmentalMultipler: number = 1
		if #mutations > 0 then
			for mut: string, multiplier: number in environmentalMutations do
				if mut ~= "None" and table.find(mutations, mut) then
					environmentalMultipler *= multiplier
				end
			end
		end

		return baseValue * weight ^ 2 * growthMutationMultiplier * rarityMultiplier * environmentalMultipler
	end
	return 10
end
