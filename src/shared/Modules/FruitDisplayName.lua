local fruitNameParser = require(script.Parent.FruitNameParse)

local FruitDisplayName = {}

function FruitDisplayName.getHotbarName(displayString: string): string
	local rarity, mutations, weight, fruitName = fruitNameParser(displayString)
	local weightText = string.format("%.1fkg", weight)

	local detailParts = {}
	if rarity ~= "Common" then
		table.insert(detailParts, rarity)
	end
	if #mutations > 0 then
		table.insert(detailParts, table.concat(mutations, "+"))
	end
	table.insert(detailParts, weightText)

	return fruitName .. "\n" .. table.concat(detailParts, " • ")
end

function FruitDisplayName.getToolTip(displayString: string): string
	return displayString
end

return FruitDisplayName
