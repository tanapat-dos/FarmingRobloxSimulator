-- Shared shop stock helpers for seed and pet shops.

local ShopStock = {}

ShopStock.RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythical = 6,
	Divine = 7,
	Prismatic = 8,
}

ShopStock.APPEAR_CHANCE_BY_RARITY = {
	Common = 65,
	Uncommon = 50,
	Rare = 35,
	Epic = 22,
	Legendary = 12,
	Mythical = 6,
	Divine = 3,
	Prismatic = 1,
}

ShopStock.SEED_STOCK_RANGE = {
	Common = { Min = 15, Max = 25 },
	Uncommon = { Min = 10, Max = 20 },
	Rare = { Min = 5, Max = 15 },
	Epic = { Min = 3, Max = 8 },
	Legendary = { Min = 1, Max = 3 },
	Mythical = { Min = 1, Max = 2 },
	Divine = { Min = 1, Max = 1 },
	Prismatic = { Min = 1, Max = 1 },
}

ShopStock.EGG_STOCK_RANGE = {
	Common = { Min = 4, Max = 5 },
	Uncommon = { Min = 3, Max = 4 },
	Rare = { Min = 2, Max = 3 },
	Epic = { Min = 1, Max = 2 },
	Legendary = { Min = 1, Max = 1 },
}

function ShopStock.computePriceRatio(baseValue: number, price: number): number
	if price <= 0 then
		return 0
	end
	return baseValue / price
end

function ShopStock.rollAppearance(rarity: string): boolean
	local chance = ShopStock.APPEAR_CHANCE_BY_RARITY[rarity] or 40
	return math.random() * 100 <= chance
end

function ShopStock.getStockRange(rarity: string, rangeTable: { [string]: { Min: number, Max: number } })
	return rangeTable[rarity] or { Min = 3, Max = 8 }
end

function ShopStock.assignLayoutOrder(entries)
	table.sort(entries, function(a, b)
		local rarityA = ShopStock.RARITY_ORDER[a.Rarity] or 99
		local rarityB = ShopStock.RARITY_ORDER[b.Rarity] or 99
		if rarityA ~= rarityB then
			return rarityA < rarityB
		end
		if a.Price ~= b.Price then
			return a.Price < b.Price
		end
		return a.PriceRatio > b.PriceRatio
	end)

	for index, entry in entries do
		entry.LayoutOrder = index
	end
end

function ShopStock.entriesToMap(entries)
	local stockMap = {}
	for _, entry in entries do
		local key = entry.Key
		entry.Key = nil
		stockMap[key] = entry
	end
	return stockMap
end

function ShopStock.formatCountdown(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local minutes = math.floor(total / 60)
	local remainder = total % 60
	return string.format("%d:%02d", minutes, remainder)
end

return ShopStock
