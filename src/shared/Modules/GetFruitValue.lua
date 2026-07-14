local replicatedStorage = game:GetService("ReplicatedStorage")

local modules = replicatedStorage:WaitForChild("Modules")
local seedModule = require(modules.SeedData)
local HarvestRarityConfig = require(modules.HarvestRarityConfig)

local growthMutations = {
	["None"] = 1,
	["Golden"] = 20,
	["Rainbow"] = 50,
}

local environmentalMutations = {
	["None"] = 1,
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
		local environmentalMultipler: number = 1
		return baseValue * weight ^ 2 * growthMutationMultiplier * rarityMultiplier * (1 + environmentalMultipler)
	end
	return 10
end
