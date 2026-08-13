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

	-- No [<n>kg] token → weight is nil, NOT 0. Defaulting to 0 made every
	-- malformed string "parse" successfully with a 0-value fruit, so sell
	-- paths destroyed the item and paid nothing. Callers must nil-check.
	local weightStr = remaining:match("%[(%d+%.?%d*)kg%]")
	local weight = weightStr and tonumber(weightStr) or nil

	local mutations = {}
	for mutation in mutationStr:gmatch("[^,%s]+") do
		if not HarvestRarityConfig.isTier(mutation) then
			table.insert(mutations, mutation)
		end
	end

	local nameCleaned = remaining
		:gsub("^%[.-%]%s*", "")
		:gsub("%[%d+%.?%d*kg%]%s*", "")

	-- Empty name → nil, so `if fruitNameOnly then` guards actually fail
	-- (empty string is truthy in Lua).
	local fruitNameOnly = trim(nameCleaned)
	if fruitNameOnly == "" then
		fruitNameOnly = nil
	end

	return rarity, mutations, weight, fruitNameOnly
end

return parseFruitInfo
