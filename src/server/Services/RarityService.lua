local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeedData = require(ReplicatedStorage:WaitForChild("Modules").SeedData)
local HarvestRarityConfig = require(ReplicatedStorage:WaitForChild("Modules").HarvestRarityConfig)

local Service = {}
local random = Random.new()

local function rollFromBias(biasTable: { [string]: number }): string
	local total = 0
	for _, tier in HarvestRarityConfig.TIERS do
		total += biasTable[tier] or 0
	end
	if total <= 0 then
		return "Common"
	end

	local roll = random:NextNumber(0, total)
	local cumulative = 0
	for _, tier in HarvestRarityConfig.TIERS do
		cumulative += biasTable[tier] or 0
		if roll <= cumulative then
			return tier
		end
	end

	return "Common"
end

function Service.rollHarvestRarity(cropName: string): string
	local seedData = SeedData.getData(cropName .. " Seed")
	local seedTier = "Common"
	if seedData and seedData:FindFirstChild("Rarity") then
		seedTier = seedData.Rarity.Value
	end

	local bias = HarvestRarityConfig.CROP_BIAS[seedTier] or HarvestRarityConfig.CROP_BIAS.Common
	return rollFromBias(bias)
end

function Service.init() end

return Service
