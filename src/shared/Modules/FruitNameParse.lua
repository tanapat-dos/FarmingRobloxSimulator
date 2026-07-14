local HarvestRarityConfig = require(script.Parent.HarvestRarityConfig)

local function trim(s: string): string
	return s:match("^%s*(.-)%s*$") :: string
end

local function parseFruitInfo(fruitName: string)
	local rarity = "Common"
	local remaining = fruitName

	local firstBracket = remaining:match("^%[([^%]]+)%]%s*")
	while firstBracket do
		if HarvestRarityConfig.isTier(firstBracket) then
			rarity = firstBracket
			remaining = remaining:gsub("^%[[^%]]+%]%s*", "", 1)
			firstBracket = remaining:match("^%[([^%]]+)%]%s*")
		else
			break
		end
	end

	local mutationStr = remaining:match("^%[(.-)%]%s*") or ""
	if mutationStr ~= "" then
		remaining = remaining:gsub("^%[[^%]]+%]%s*", "", 1)
	end

	local weightStr = remaining:match("%[(%d+%.?%d*)kg%]") or "0"
	local weight = tonumber(weightStr) or 0

	local mutations = {}
	for mutation in mutationStr:gmatch("[^,%s]+") do
		if not HarvestRarityConfig.isTier(mutation) then
			table.insert(mutations, mutation)
		end
	end

	local nameCleaned = remaining
		:gsub("^%[.-%]%s*", "")
		:gsub("%[%d+%.?%d*kg%]%s*", "")

	local fruitNameOnly = trim(nameCleaned)

	return rarity, mutations, weight, fruitNameOnly
end

return parseFruitInfo
