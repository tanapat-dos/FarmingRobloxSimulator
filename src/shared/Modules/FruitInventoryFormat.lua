local HarvestRarityConfig = require(script.Parent.HarvestRarityConfig)

local FruitInventoryFormat = {}

function FruitInventoryFormat.build(fruitName: string, weight: number, mutations: string, rarity: string?): string
	local rarityTier = rarity or "Common"
	local parts = {}

	if rarityTier ~= "Common" and HarvestRarityConfig.isTier(rarityTier) then
		table.insert(parts, "[" .. rarityTier .. "]")
	end

	if mutations and mutations ~= "" then
		table.insert(parts, "[" .. mutations .. "]")
	end

	local prefix = #parts > 0 and (table.concat(parts, " ") .. " ") or ""
	return prefix .. fruitName .. " [" .. tostring(weight) .. "kg]"
end

return FruitInventoryFormat
