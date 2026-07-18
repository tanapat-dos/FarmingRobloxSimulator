local Monetization = {}

-- Developer Product IDs
Monetization.DevProducts = {
	RestockShop = 3308220846, -- 💰 Replace with your real ID
	RestockTools = 3308220846, -- 💰 Replace with your real ID

	-- Diamond packs (premium currency). Create these Developer Products in
	-- Roblox (Creator Dashboard → your experience → Monetization → Developer
	-- Products) and paste the real IDs here. 100💎 should be priced ~$0.99.
	Diamonds100 = 3610342683, -- 💎 100 diamonds ($0.99)
}

-- Diamond packs sold for Robux. ProductService reads this to grant diamonds
-- in ProcessReceipt. Entries with id == 0 are ignored (not yet configured).
Monetization.DiamondPacks = {
	{ id = Monetization.DevProducts.Diamonds100, diamonds = 100, usd = 0.99 },
}

-- Gamepass IDs
Monetization.Gamepasses = {
	-- Here
}

-- Badge IDs
Monetization.Badges = {
	-- Here
}

return Monetization
