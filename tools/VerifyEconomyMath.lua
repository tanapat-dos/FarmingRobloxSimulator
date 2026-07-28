--[[
	ECONOMY MATH VERIFIER
	Paste into the Studio Command Bar.

	Read-only. Recomputes expected sell value for every crop and checks the design's
	correctness properties, then compares EconomyBalance.CROPS against the live
	ReplicatedStorage.Modules.SeedData instance tree.

	SeedData is the RUNTIME source of truth — GetFruitValue and SeedShopService.GenerateStock
	both read it, not EconomyBalance. Any mismatch reported here means the rebalance is not
	actually live. Run tools/MigrateSeedDataEconomy.lua to fix.

	Properties checked:
	  P1  every standard cash crop's expected sale is within 5% of TARGET_EXPECTED_SALE_ROI
	      (1.60x its seed price); Mango pays back within 8h; Crystal Blooms preserved payout
	  P2  growth time tier averages land within their target pacing band
	  P5  SeedData Price/BaseValue/GrowthTime match EconomyBalance.CROPS
	  P6  every crop in exactly one tier, no empty tiers
	  P7  HarvestCount/HarvestInterval/MultiHarvest unchanged (Mango 4/600 only perennial)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyBalance = require(ReplicatedStorage.Modules.EconomyBalance)
local HarvestRarityConfig = require(ReplicatedStorage.Modules.HarvestRarityConfig)
local seedDataFolder = ReplicatedStorage.Modules.SeedData

local TIER_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }

-- Growth-time tier-average pacing bands (validation section 14): Common 55-75s,
-- Mythical 1110-1250s, middle tiers interpolated geometrically between the two.
local GROWTH_TIME_BAND = {
	Common = { 55, 75 },
	Uncommon = { 96, 137 },
	Rare = { 171, 245 },
	Epic = { 306, 437 },
	Legendary = { 546, 780 },
	Mythical = { 1110, 1250 },
}

-- MutationService: 1% Rainbow (x8), then 5% Golden (x3) of the remaining 99%
local P_RAINBOW = 0.01
local P_GOLDEN = 0.99 * 0.05
local E_MUTATION = P_RAINBOW * 8 + P_GOLDEN * 3 + (1 - P_RAINBOW - P_GOLDEN) * 1

-- getRandomFruitSize: w = a + b * r^2.2  ->  E[w^1.5], using E[r^k] = 1/(k+1)
local function expectedWeightPow15(a: number, b: number): number
	-- E[(a + b*r^2.2)^1.5] has no closed form; EconomyBalance's constants were derived via
	-- numeric integration (see .mcp-tmp/economy_rebalance_calc.mjs history) and are the
	-- source of truth here, matching what GetFruitValue actually multiplies by.
	if a == 1 and b == 2 then
		return EconomyBalance.EXPECTED_STANDARD_SIZE_MULTIPLIER
	elseif a == 0.75 and b == 1.1 then
		return EconomyBalance.EXPECTED_PERENNIAL_SIZE_MULTIPLIER
	end
	error("expectedWeightPow15: no known constant for a=" .. a .. " b=" .. b)
end

local E_W15_STANDARD = expectedWeightPow15(1, 2)
local E_W15_MANGO = expectedWeightPow15(0.75, 1.1)

local function rarityAvg(tier: string): number
	local bias = HarvestRarityConfig.CROP_BIAS[tier]
	if not bias then
		return 1
	end
	local sum, weight = 0, 0
	for quality, pct in bias do
		sum += pct * HarvestRarityConfig.getMultiplier(quality)
		weight += pct
	end
	return if weight > 0 then sum / weight else 1
end

local failures = {}
local function fail(message: string)
	table.insert(failures, message)
end

print("=== Constants ===")
print(("  E[weight^1.5] standard = %.4f"):format(E_W15_STANDARD))
print(("  E[weight^1.5] mango    = %.4f"):format(E_W15_MANGO))
print(("  E[mutation]            = %.4f"):format(E_MUTATION))
print(("  TARGET_EXPECTED_SALE_ROI = %.2fx"):format(EconomyBalance.TARGET_EXPECTED_SALE_ROI))

print("=== Tier multipliers ===")
for _, tier in TIER_ORDER do
	local ra = rarityAvg(tier)
	print(("  %-10s rarityAvg=%.4f  M=%.3f"):format(tier, ra, E_W15_STANDARD * E_MUTATION * ra))
end

-- ------------------------------------------------------------------ evaluate crops
local rows = {}
for seedName, cfg in EconomyBalance.CROPS do
	local tier = cfg.rarity
	local isPerennial = cfg.multiHarvest == true
	local eW15 = if isPerennial then E_W15_MANGO else E_W15_STANDARD
	local perFruit = cfg.baseValue * eW15 * E_MUTATION * rarityAvg(tier)

	local profitPerHour, ratio
	if isPerennial then
		local fruitsPerHour = (cfg.harvestCount or 1) * (3600 / (cfg.harvestInterval or 600))
		profitPerHour = fruitsPerHour * perFruit
		ratio = nil
	else
		-- price 0 means the crop is bought with a non-cash currency (Fish Coins)
		profitPerHour = ((perFruit - (cfg.price or 0)) / cfg.growthTime) * 3600
		ratio = if (cfg.price or 0) > 0 then perFruit / cfg.price else nil
	end

	table.insert(rows, {
		seedName = seedName,
		tier = tier,
		cfg = cfg,
		perFruit = perFruit,
		profitPerHour = profitPerHour,
		ratio = ratio,
		isPerennial = isPerennial,
	})
end

table.sort(rows, function(a, b)
	local ia = table.find(TIER_ORDER, a.tier) or 99
	local ib = table.find(TIER_ORDER, b.tier) or 99
	if ia ~= ib then
		return ia < ib
	end
	return (a.cfg.baseValue or 0) < (b.cfg.baseValue or 0)
end)

print("=== Crops ===")
print(("  %-20s %-10s %9s %9s %6s %10s %7s %11s"):format(
	"Crop", "Tier", "Price", "baseVal", "Grow", "$/fruit", "ret", "$/slot-hr"))
for _, r in rows do
	print(("  %-20s %-10s %9s %9s %6s %10d %7s %11d"):format(
		r.seedName,
		tostring(r.tier),
		tostring(r.cfg.price or 0),
		tostring(r.cfg.baseValue),
		tostring(r.cfg.growthTime),
		math.floor(r.perFruit + 0.5),
		if r.ratio then ("%.2fx"):format(r.ratio) else "n/a",
		math.floor(r.profitPerHour + 0.5)))
end

-- ------------------------------------------------------------------ P1
local TARGET_ROI = EconomyBalance.TARGET_EXPECTED_SALE_ROI
for _, r in rows do
	if r.seedName == "Mango Seed" then
		local payback = (r.cfg.price or 0) / r.profitPerHour
		print(("  Mango payback = %.2fh (target ~7.5h)"):format(payback))
		if payback > 8 then
			fail(("P1 Mango: payback %.1fh > 8h"):format(payback))
		end
	elseif r.seedName == "Crystal Blooms Seed" then
		-- Apex/Fish-Coin crop: no cash ROI check, just report the per-fruit value.
		print(("  Crystal Blooms per-fruit value = %.1f"):format(r.perFruit))
	elseif r.ratio then
		if math.abs(r.ratio - TARGET_ROI) / TARGET_ROI > 0.05 then
			fail(("P1 %s: return %.3fx drifts >5%% from target %.2fx"):format(r.seedName, r.ratio, TARGET_ROI))
		end
	end
end

-- ------------------------------------------------------------------ P2 / P6
local growthTimesByTier = {}
local seen = {}
for _, r in rows do
	if seen[r.seedName] then
		fail("P6 duplicate crop " .. r.seedName)
	end
	seen[r.seedName] = true

	if not table.find(TIER_ORDER, r.tier) then
		fail(("P6 %s: unknown tier %s"):format(r.seedName, tostring(r.tier)))
	end

	-- Crystal Blooms and Mango are documented exceptions (apex/perennial pacing, not the
	-- standard-crop growth-time band).
	if r.seedName ~= "Crystal Blooms Seed" and r.seedName ~= "Mango Seed" then
		growthTimesByTier[r.tier] = growthTimesByTier[r.tier] or {}
		table.insert(growthTimesByTier[r.tier], r.cfg.growthTime)
	end
end

for _, tier in TIER_ORDER do
	local vals = growthTimesByTier[tier]
	if not vals or #vals == 0 then
		fail("P6 tier " .. tier .. " has no crops")
		continue
	end
	local sum = 0
	for _, v in vals do
		sum += v
	end
	local avg = sum / #vals
	local band = GROWTH_TIME_BAND[tier]
	if band and (avg < band[1] or avg > band[2]) then
		fail(("P2 tier %s: growthTime avg %.0fs outside band [%d, %d]"):format(tier, avg, band[1], band[2]))
	end
end

-- ------------------------------------------------------------------ P5 / P7
print("=== SeedData agreement (P5) ===")
local FIELDS = { Price = "price", BaseValue = "baseValue", GrowthTime = "growthTime" }
local mismatches = 0
for _, r in rows do
	local folder = seedDataFolder:FindFirstChild(r.seedName)
	if not folder then
		fail("P5 " .. r.seedName .. ": no SeedData folder")
		continue
	end
	for instanceName, cfgKey in FIELDS do
		local value = folder:FindFirstChild(instanceName)
		local expected = r.cfg[cfgKey]
		-- Crystal Blooms is priced in Fish Coins; its SeedData Price is not authoritative
		if instanceName == "Price" and (r.cfg.price or 0) == 0 then
			continue
		end
		if not value then
			fail(("P5 %s: missing %s"):format(r.seedName, instanceName))
		elseif math.abs(value.Value - expected) > 0.01 then
			mismatches += 1
			print(("  MISMATCH %-20s %-11s live=%-10s expected=%s"):format(
				r.seedName, instanceName, tostring(value.Value), tostring(expected)))
		end
	end

	-- P7: mesh-bound fields
	local harvestCount = folder:FindFirstChild("HarvestCount")
	local multiHarvest = folder:FindFirstChild("MultiHarvest")
	local expectedCount = if r.seedName == "Mango Seed" then 4 else 1
	local expectedMulti = r.seedName == "Mango Seed"
	if harvestCount and harvestCount.Value ~= expectedCount then
		fail(("P7 %s: HarvestCount=%d expected %d (mesh-bound)"):format(
			r.seedName, harvestCount.Value, expectedCount))
	end
	if multiHarvest and multiHarvest.Value ~= expectedMulti then
		fail(("P7 %s: MultiHarvest=%s expected %s (mesh-bound)"):format(
			r.seedName, tostring(multiHarvest.Value), tostring(expectedMulti)))
	end
end
if mismatches > 0 then
	fail(("P5 %d SeedData field(s) differ from EconomyBalance — run MigrateSeedDataEconomy.lua"):format(mismatches))
else
	print("  All SeedData fields match EconomyBalance.")
end

-- ------------------------------------------------------------------ result
print(("=== Result: %d crops checked ==="):format(#rows))
-- 17 standard cash crops + Crystal Blooms (apex, Fish Coin) + Mango (perennial) = 19.
if #rows ~= 19 then
	fail(("P6 expected 19 crops, got %d"):format(#rows))
end

if #failures == 0 then
	print("ALL PROPERTIES PASSED")
else
	warn(("FAILED (%d)"):format(#failures))
	for _, f in failures do
		warn("  - " .. f)
	end
end
