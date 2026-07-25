# Economy Rebalance — Design

## Overview

Verified against live Studio `SeedData` (which matches `EconomyBalance.lua`): **17 of the 18
crops return less cash than their seed cost.** Farming is a money sink rather than a money
source, so there is no economic engine and normal progression is impossible except via
one-time achievement and daily-login payouts.

The single exception is **Mango**, which is broken in the opposite direction — see
"Perennial crops" below. It is currently the only viable income source in the game.

`GetFruitValue` = `baseValue × weight² × mutation × rarity × environment`

Expected values with current config:

- `weight` rolls `1 + r^2.2 × 2` → **E[weight²] = 2.99**
- Mutations: 1% Rainbow (50x), ~4.95% Golden (20x) → **E[mutation] = 2.43**
- Rarity averages from `HarvestRarityConfig.CROP_BIAS`: Common 1.08, Uncommon 1.16,
  Rare 1.30, Epic 1.42

| Crop | Seed cost | Expected revenue | Return |
|---|---|---|---|
| Carrot | $30 | $5.25 | 0.18x |
| Wheat | $50 | $15.70 | 0.31x |
| Tomato | $110 | $33.80 | 0.31x |
| Grape | $500 | $188 | 0.38x |
| Pineapple | $1,000 | $413 | 0.41x |

Secondary problem: the tier ladder has no teeth. Seed price climbs 53x across the ladder
but time-normalized income only climbs 6.4x, because `growthTime` scales nearly
proportionally with price. Climbing tiers barely pays.

### Perennial crops (the Mango problem)

`MultiHarvest` plants are **perennial and regrow indefinitely** — this is easy to misread
from the config, so it is worth stating precisely.

`HarvestCount` is the number of fruit *slots* on a plant, not a lifetime total. In
`HarvestService.Harvest`, the single-harvest branch destroys the plant
(`ownerPlotData[foundPlant.Name] = nil`), while the multi-harvest branch only sets
`CanHarvest = false` and `LastHarvest = os.time()`. `PlotService` then re-ripens each slot
once `os.time() - LastHarvest >= HarvestInterval`, rerolling size and rarity, with **no cap
on repetitions**.

So Mango is a permanent tree with 4 slots re-ripening every 600s:

```
fruits/hour = harvestCount × (3600 / harvestInterval) = 4 × 6 = 24
```

At its current `baseValue = 54` and per-fruit multiplier of 5.657 (Mango uses the reduced
weight roll `0.75 + r^2.2 × 1.1`, E[weight²] = 1.302), that is **~$5,830/hour from a single
slot, forever, for a one-time $1,600 seed** — payback in about 17 minutes. Mango both
invalidates the "farming is unprofitable" framing and trivially dominates every other crop.

Perennials therefore need their own math. Seed cost amortises to zero, so the meaningful
figures are steady-state hourly rate and payback period:

```
fruits/hour  = harvestCount × (3600 / harvestInterval)
profit/hour  = fruits/hour × baseValue × M(tier)     -- perpetual, no replant cost
payback      = price / profit-per-hour
```

Perennials are priced for a **~3 hour payback** so they read as a real investment decision,
and tuned to sit at their tier's hourly rate — the premium being that they never need
replanting.

### Hard constraint: `HarvestCount` is fixed by the mesh

`HarvestCount` corresponds to real fruit attachment points on the plant model, so it is **not
a tunable number.** It cannot be raised or lowered without new art.

Consequences for this spec:

- **Mango stays at `harvestCount = 4`, `harvestInterval = 600`, `MultiHarvest = true`.** Only
  its `baseValue` and `price` may change.
- **Mango is the only multi-harvest crop.** No other crop may be converted to perennial.
- **Crystal Blooms is single-harvest** (`harvestCount = 1`, `MultiHarvest = false`), like the
  other 16 crops.

### Goals

1. Farming is profitable at every tier (target return ratio **R = 2.0**).
2. Higher tiers pay meaningfully more per unit time, so climbing is the core motivation.
3. Tier access is gated by escalating requirements plus stock RNG at the top.
4. No dependency on the rebirth system, which is unfixed and out of scope.

### Non-goals

- Rebirth rework (deferred — see Deferred Work).
- Pet endgame, weighted roll odds, fusion (separate spec).
- Onboarding "Next Goal" tracker (belongs with onboarding work once gates exist).

## Architecture

### Design decisions

**1. Fix ROI by raising `baseValue`, not by cutting seed prices.** Keeps seeds feeling like
a meaningful investment and keeps `DevProduct` pricing sensible.

**2. Six tiers × three crops, redistributed from the existing 18.** There are exactly 18
crop art folders in `ReplicatedStorage.Assets.Plants` and no spares, so new tiers cannot
mean new crops. Divine and Prismatic remain defined in `ShopStock` as future slots.

**3. Reward escalation comes from the price/time ratio.** `growthTime` grows slower than
value, so profit per slot-hour roughly doubles per tier.

**4. Unlock gates read already-tracked stats.** `AchievementStats` tracks `TotalEarned`,
`CropsPlanted`, `FruitsHarvested`, `MutationsFound`, `OrdersDelivered`; plus `PlotsOwned`
and `FishingStats`. No new persistence needed.

**5. Remove the Carrot fixed-weight special case.** `SeedShopService.getRandomFruitSize`
hard-returns `1` for `"Carrot Seed"`, deleting the `weight²` term and making the tutorial
crop the single worst in the game.

### Gating enforcement

Gates are enforced **server-side** in `SeedShopService.GenerateStock`: a locked crop is
excluded from generated stock. Since `RemoteEvents.BuyCrop` already rejects any crop absent
from stock, no new validation path is required — the existing check becomes the gate.

Locked tiers must still be *visible* for legibility, so the server additionally pushes a
`lockedTiers` payload describing each locked tier's requirement and the player's progress.
That payload is display-only; it grants nothing.

### Source-of-truth constraint

`SeedData` (a Studio instance tree under `ReplicatedStorage.Modules`) is the **runtime**
source of truth, not `EconomyBalance.lua`. Both `GetFruitValue` and `GenerateStock` read the
instance tree. Editing `EconomyBalance.lua` alone changes nothing in game.

Therefore a migration script under `tools/` must write `EconomyBalance.CROPS` values into
the `SeedData` folders, following the `setValue` pattern in
`tools/IntegrateCrystalBlooms.lua`. `EconomyBalance.lua` remains the authored source;
the script is the sync mechanism.

## Components and Interfaces

### New: `src/shared/Modules/CropTierConfig.lua`

Shared module so client and server evaluate identical rules.

```lua
CropTierConfig.TIER_ORDER: { string }        -- Common .. Mythical

CropTierConfig.TIERS: {
    [tierName]: {
        gates: { { stat: string, goal: number } },  -- empty = always unlocked
        label: string,                              -- "Legendary"
    }
}

-- stats: flat table of { TotalEarned, PlotsOwned, FruitsHarvested, MutationsFound, ... }
CropTierConfig.isUnlocked(stats, tierName): boolean

-- Returns per-gate progress for tooltip rendering.
CropTierConfig.getUnlockProgress(stats, tierName):
    { { stat: string, have: number, goal: number, met: boolean } }

CropTierConfig.getTierForSeed(seedName): string?
```

`gates` is a list so a tier can require multiple conditions (Epic needs both earnings and
plot count). All gates must be met.

### Modified: `SeedShopService`

- `getRandomFruitSize` — drop the `"Carrot Seed"` early return.
- `GenerateStock` — takes no player argument today and produces one global stock map. Gates
  are per-player, so stock generation stays global (all tiers rolled) and **filtering moves
  to the point of delivery**: `ResetSeedShop`/`PlayerAdded` push a filtered view per player,
  and the `BuyCrop` handler re-checks the gate before selling.

  This preserves the existing MemoryStore-backed global stock (so all players see the same
  restock cycle) while making visibility and purchase per-player.

- New helper `buildPlayerStockView(player, stock)` returning `{ stock, lockedTiers }`.

### Modified: `OrderService`

Reward formula currently omits the mutation expectation, making orders pay ~5.1x `baseValue`
per fruit while average selling pays ~7.85x — orders are *worse* than selling despite being
framed as a premium.

```
reward = baseValue × E[weight²] × E[mutation] × rarityAvg(tier) × count × 0.85 × askMult
```

`0.85` replaces `ORDER_BONUS`. Orders become the reliable low-variance floor; selling stays
the high-variance play where mutations pay off.

### Modified: `FishCoinShopService`

Crystal Blooms price → **150 Fish Coins**, with the Mythical gate applied to the offer
listing. Because it is the apex crop, the offer must remain gated — ungated, a fresh player
could skip the entire ladder by fishing.

Crystal Blooms stays single-harvest, so no multi-harvest plumbing is involved and no
`HarvestService` changes are needed.

### Modified: seed shop UI

The shop LocalScript lives in Studio at `StarterGui.Shop` with a reference copy at
`tools/ShopScript.lua`. It gains rendering for locked tier rows showing requirement and live
progress (e.g. `Legendary — $340K / $2M earned`).

## Data Models

### Tier definitions

Rarity averages derived from `CROP_BIAS`; per-`baseValue` revenue multiplier
`M = 2.99 × 2.43 × rarityAvg`.

| Tier | rarityAvg | M | Target profit/slot-hr | Stock chance | Gate |
|---|---|---|---|---|---|
| Common | 1.080 | 7.85 | $600 | 65% | none |
| Uncommon | 1.164 | 8.46 | $1,200 | 50% | none |
| Rare | 1.297 | 9.42 | $2,500 | 35% | `TotalEarned ≥ 25,000` |
| Epic | 1.422 | 10.33 | $5,000 | 22% | `TotalEarned ≥ 250,000`, `PlotsOwned ≥ 3` |
| Legendary | 1.625 | 11.81 | $10,000 | 12% | `TotalEarned ≥ 2,000,000`, `FruitsHarvested ≥ 500` |
| Mythical | 1.788 | 12.99 | $20,000 | 6% | `TotalEarned ≥ 15,000,000`, `MutationsFound ≥ 10` |

Stock chances are the existing `ShopStock.APPEAR_CHANCE_BY_RARITY` values, unchanged. On a
5-minute restock (~12 rolls/hour) a Mythical crop surfaces roughly once per 1.4 hours of
play — the RNG gate at the top of the ladder.

### `EconomyBalance.CROPS`

All values satisfy `baseValue × M = 2 × price`. Growth times in seconds.

| Crop | Tier | Price | baseValue | Growth | Profit/slot-hr |
|---|---|---|---|---|---|
| Carrot | Common | 25 | 6.4 | 150 | $600 |
| Radish | Common | 30 | 7.6 | 180 | $600 |
| Wheat | Common | 35 | 8.9 | 210 | $600 |
| Lettuce | Uncommon | 90 | 21.3 | 270 | $1,200 |
| Potato | Uncommon | 100 | 23.6 | 300 | $1,200 |
| Beetroot | Uncommon | 110 | 26.0 | 330 | $1,200 |
| Tomato | Rare | 270 | 57.3 | 390 | $2,492 |
| Garlic | Rare | 290 | 61.6 | 420 | $2,486 |
| Corn | Rare | 315 | 66.9 | 450 | $2,520 |
| Strawberry | Epic | 750 | 145.2 | 540 | $5,000 |
| Pepper | Epic | 840 | 162.6 | 600 | $5,040 |
| Pumpkin | Epic | 920 | 178.1 | 660 | $5,018 |
| Grape | Legendary | 2,350 | 398.0 | 840 | $10,071 |
| Eggplant | Legendary | 2,500 | 423.4 | 900 | $10,000 |
| Pineapple | Legendary | 2,670 | 452.2 | 960 | $10,013 |
| Bubble Rash | Mythical | 6,350 | 977.7 | 1,140 | $20,053 |

| **Crystal Blooms** † | **Mythical (apex)** | **150 †** | **1,000** | **1,200** | **$38,970** |

Mango is the sole perennial and is priced by the perennial formula instead, since its seed
cost amortises away and hourly rate is what matters:

| Crop | Slots / interval | Fruits/hr | baseValue | Price | Profit/hr | Payback |
|---|---|---|---|---|---|---|
| Mango ‡ | 4 / 600 | 24 | 147 | 60,000 | ~$20,000 | 3.0h |

† Priced in **Fish Coins** via `FishCoinShopService`, not cash. Single-harvest, like every
crop except Mango.

‡ Mango uses the reduced weight roll (`0.75 + r^2.2 × 1.1`, E[weight²] = 1.302), giving a
per-fruit multiplier of 5.657 rather than 12.99. `baseValue` is set so
`24 × 147 × 5.657 ≈ $20,000/hr`, matching the Mythical tier rate. Its price rises from
$1,600 to **$60,000** — from an impulse buy to a genuine investment with a 3-hour payback.
`harvestCount` and `harvestInterval` are unchanged (mesh-bound).

### Why Crystal Blooms is the apex

Crystal Blooms leads on both axes: the **highest `baseValue` in the game** (1,000 vs Bubble
Rash's 977.7, so the most valuable single fruit) and the **highest profit per slot-hour**
(~$38,970 vs the $20,000 Mythical baseline). It costs no cash, so its entire output is profit.

Fish Coin supply is the only throttle, which makes that price the critical number. Fish Coin
income is `ceil(fish.value / 10)` per catch; weighted across the `CanalFull` fish table the
average catch pays ~4.4 coins, and with a 2.5s cast cooldown plus minigame time a dedicated
hour yields roughly **1,100 coins**.

At **150 coins per seed** that is ~7 seeds per fishing hour. A slot consumes 3 seeds/hour on
a 1,200s cycle, so steady fishing sustains roughly **2–3 permanent Crystal Bloom slots**
(~$95,000/hr) against the ~$1.6M/hr a full 80-slot Mythical farm produces. A meaningful
reward for a second activity, never a dominant strategy.

**This supersedes the earlier 6,700-coin figure**, which was set while the crop was speced as
perennial. At 6,700 coins (~6 hours of fishing) for a *single* fruit worth ~$13,000 the trade
would be heavily negative, so removing the perennial assumption requires dropping the price
by a similar factor. The coin price remains the balancing lever: adjust it rather than
weakening the crop.

### `EconomyBalance.PLOTS.prices`

**Pacing target: both sink lines complete in roughly 2–3 days of engaged play** (~15–25
hours), landing at about the same point the player crosses the Mythical gate
(`TotalEarned ≥ $15M`). That ordering matters: permanent upgrades finish right as the top
crop tier opens, so there is always something to earn toward.

Current totals are close to correct for that target, so prices only need a mild bump at the
top rather than the order-of-magnitude rescale an income-ceiling reading would suggest.
Bed 2 stays cheap so the first upgrade remains a first-session goal. Index 1 is the free
starter bed.

| Bed | Current | Proposed |
|---|---|---|
| 2 | 5,000 | 5,000 |
| 3 | 20,000 | 20,000 |
| 4 | 60,000 | 75,000 |
| 5 | 150,000 | 200,000 |
| 6 | 350,000 | 500,000 |
| 7 | 750,000 | 1,200,000 |
| 8 | 1,500,000 | 2,500,000 |

Total: $2.835M → $4.5M.

### `EconomyBalance.UPGRADES.GrowthReduction.levels`

Same 8 levels and 5–40% reduction range. (The existing code comment claiming ~$2.9M
cumulative is stale — actual current total is $4.163M.)

| Level | Pct | Current | Proposed |
|---|---|---|---|
| 1 | 5 | 8,000 | 8,000 |
| 2 | 10 | 25,000 | 25,000 |
| 3 | 15 | 70,000 | 80,000 |
| 4 | 20 | 160,000 | 200,000 |
| 5 | 25 | 350,000 | 450,000 |
| 6 | 30 | 650,000 | 900,000 |
| 7 | 35 | 1,100,000 | 1,600,000 |
| 8 | 40 | 1,800,000 | 2,800,000 |

Total: $4.163M → $6.06M.

Combined sink total ≈ **$10.6M**, versus the ~$15M earned that opens Mythical. Upgrades
therefore trail slightly behind the tier ladder, which is the intended feel — you are always
mid-upgrade rather than fully maxed with nothing to buy.

### Projected income curve

Slots = `PlotsOwned × 10`, max 80. At 100% replant uptime (a ceiling — real play runs well
below):

| Stage | Slots | Best tier | Earnings/hr |
|---|---|---|---|
| Start | 10 | Common | $6,000 |
| 2 plots | 20 | Uncommon | $24,000 |
| 4 plots | 40 | Rare | $100,000 |
| 6 plots | 60 | Epic | $300,000 |
| 8 plots | 80 | Legendary | $800,000 |
| 8 plots | 80 | Mythical | $1,600,000 |

Total dynamic range 264x (33x tier × 8x slots). `merchant_6` ($100M earned) lands around
**300+ hours** at realistic mid-late rates, setting the intended game lifetime.

## Correctness Properties

### Property 1: Every crop is profitable

For every crop, `baseValue × M(tier) ≥ 1.9 × price`. Averaged over mutation and rarity
outcomes, no crop is a net loss. This is the property whose violation caused the original
problem.

### Property 2: Tier reward is monotonic

Profit per slot-hour is strictly increasing across `TIER_ORDER`. A higher tier is never a
worse earner per unit time than a lower one, so climbing is always correct.

Crystal Blooms is a deliberate exception that exceeds its tier band; it is throttled by Fish
Coin supply rather than by cash, so it cannot be spammed. No **cash-purchased** crop may
exceed its tier band.

### Property 7: `HarvestCount` and `HarvestInterval` are never modified

These map to fruit attachment points on the plant mesh. Mango remains `4 / 600` with
`MultiHarvest = true`; every other crop remains `harvestCount = 1` with
`MultiHarvest = false`. The migration script must not write these fields.

### Property 3: Gate authority is server-side

A player failing a tier gate can never obtain that tier's seed, via any remote, at any time.
`BuyCrop` re-checks the gate server-side rather than trusting the pushed stock view, so a
crafted client request cannot bypass a gate.

### Property 4: Price is never client-supplied

`BuyCrop` and `BuyFishCoinItem` derive price from server state only; a client-sent price is
never read. Already true in both handlers; must remain true.

### Property 5: Config and instance tree agree

For every seed, `SeedData.Price`, `.BaseValue` and `.GrowthTime` equal the corresponding
`EconomyBalance.CROPS` entry after migration. Divergence silently reverts the rebalance,
since `SeedData` is what runs.

### Property 6: No orphaned or duplicated crops

Every one of the 18 crops belongs to exactly one tier, and every tier in `TIER_ORDER` has at
least one crop. Prevents a crop becoming unobtainable or a tier rendering empty.

## Error Handling

- **Missing `SeedData` entry** — `GenerateStock` already skips seeds whose data folder is
  absent; unchanged. `CropTierConfig.getTierForSeed` returns `nil` for unknown seeds and
  such seeds are excluded from stock rather than defaulting to Common (fail closed, so a
  misconfigured crop can never be sold cheaply at the wrong tier).
- **Missing stat field** — `getUnlockProgress` treats an absent stat as `0`, so profiles
  saved before a stat existed gate correctly rather than erroring.
- **Migration script re-run** — the `setValue` pattern is idempotent (creates the value
  object if missing, else overwrites), so re-running is safe.
- **Gate evaluated before data load** — if `player:GetAttribute("DataLoaded") ~= true`,
  treat all gated tiers as locked and skip pushing a stock view; the existing
  `PlayerAdded` retry loop will push once data is ready.

## Testing Strategy

No test framework exists in this project, and the economy is validated by arithmetic rather
than runtime behaviour, so verification is split:

**Arithmetic verification (pre-implementation).** A throwaway script recomputes
`baseValue × M(tier)` for all 18 crops and asserts properties 1, 2 and 6 above. This is the
primary correctness check and should be run before touching `SeedData`.

**Studio verification (post-implementation).**

1. Confirm `SeedData` values match `EconomyBalance.CROPS` for a sample of crops across all
   six tiers (read via MCP `manage_properties`).
2. Fresh Studio profile starts with `STARTING_CASH = 100`, buys Carrot, and the sell price
   after harvest exceeds $25 — the smoke test that farming is profitable at all.
3. Seed shop shows only Common and Uncommon on a fresh profile; Rare rows render as locked
   with progress text.
4. Grant `TotalEarned` past a gate threshold and confirm the tier becomes purchasable
   without a rejoin (or document that a restock is required).
5. Attempt a `BuyCrop` fire for a locked crop from the client and confirm rejection.
6. Deliver an order and confirm the reward is in the expected band relative to selling the
   same fruits.

## Deferred Work

- **Rebirth rework.** `costMult = 4` (exponential) against `boostPerRebirth = 0.25`
  (linear) makes each rebirth strictly worse value than the last; `prestige_4` (10 rebirths
  = $65.5B) is unreachable. Rebirth also resets `PlotsOwned` to 1, destroying the plot sink.
  Untouched here; needs a ~2.2 cost multiplier and a multiplicative boost.
- **Pet endgame.** Weighted roll odds (currently uniform via
  `pets[math.random(1, #pets)]`), the unused `Evolved` pet models as an ultra-rare tier, and
  fusion. Separate spec.
- **Achievement retuning.** `merchant_6` and the `prestige_*` line should be revisited once
  the income curve is settled.

## Resolved Decisions

1. **Tier gate thresholds** — confirmed as $25K → $250K → $2M → $15M `TotalEarned`.
2. **Sink pacing** — target 2–3 days of engaged play (~15–25 hours) to complete plots and
   growth upgrades. Sinks stay near current values (combined $10.6M) rather than the
   aggressive rescale first proposed.
3. **Crystal Blooms** — becomes the **apex** of the ladder: highest `baseValue` (1,000) and
   highest profit per slot-hour (~$38,970), throttled by Fish Coin supply rather than cash.
   Single-harvest.
4. **`HarvestCount` is mesh-bound and not tunable.** Mango stays at `4 / 600` and remains the
   only perennial; every other crop including Crystal Blooms is single-harvest. Only Mango's
   `baseValue` (→147) and `price` (→$60,000) change.

## Remaining Risks

- **Mango's price increase is the largest single change** ($1,600 → $60,000, a 37x jump) and
  its `baseValue` drops 54 → 147 while its hourly output falls from ~$5,830 to ~$20,000/hr in
  a much later tier. Any existing test profile holding cheap Mangos will be sitting on a
  disproportionate asset. Worth checking whether Studio mock profiles need resetting.
- **Fish Coin economy has one sink.** Once a player has the Crystal Blooms they want there is
  nothing else to spend coins on. The pet spec should add a Fish Coin path to top eggs.
- **Fish Coin income rate is estimated, not measured.** The ~1,100 coins/hour figure assumes a
  2.5s cast cooldown plus minigame time and an average 4.4-coin catch. If real throughput
  differs materially the 150-coin price needs revisiting.
- **Achievement thresholds unretuned.** `merchant_6` at $100M now lands near the intended
  300h lifetime, but the `prestige_*` line is still unreachable pending the rebirth rework.
