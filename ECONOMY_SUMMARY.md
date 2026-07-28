# Farming Simulator — Economy & Game Loop Summary

Snapshot of the current live economy design, for discussing price/retention design with
an outside collaborator (e.g. GPT). Pulled directly from the source of truth
(`src/shared/Modules/EconomyBalance.lua` and related services) as of this session.

## Core Loop

```
Buy Seed -> Plant -> Wait (grow timer) -> Harvest -> Sell / Fulfill Order -> Buy more
                                                    -> Roll Pet Eggs (cash multiplier)
                                                    -> Buy Plots / Growth Upgrades (sinks)
                                                    -> Rebirth (reset + permanent boost)
```

Currency: **Cash** (primary), **Diamonds** (premium, from daily login streak day 7 + real
money), **Fish Coins** (earned by fishing, spent on the apex crop only).

## Crop Sell Value Formula

```
sellPrice = baseValue * weight^2 * growthMutationMult * harvestRarityMult * environmentalMult
```

- `weight` — random per-fruit size, `1 + r^2.2 * 2` for standard crops (E[weight²] ≈ 2.99),
  reduced to `0.75 + r^2.2 * 1.1` for perennials (E[weight²] ≈ 1.30 — used only by Mango).
- `growthMutationMult` — None ×1, Golden ×20 (~4.95% chance), Rainbow ×50 (~1% chance).
  E[mutation] ≈ 2.43.
- `harvestRarityMult` — Common ×1 up to Divine ×3, rolled per-harvest with odds biased by the
  crop's shop tier (`HarvestRarityConfig.CROP_BIAS`) — higher-tier crops roll better harvest
  quality on average.
- `environmentalMult` — Wet ×2 / Shocked ×8 during rain/thunderstorms, stacks multiplicatively.

**Design intent (from code comments):** every crop's `baseValue` is derived so that
`baseValue * tierAvgMultiplier = 2 * price` — i.e. one harvest cycle nets ~2x the seed cost on
average, and profit-per-slot-hour roughly **doubles per tier**.

## Crop Tier Ladder (19 crops, 6 tiers)

| Tier | Crops | Price | BaseValue | Grow Time | ~$/slot-hr (design target) |
|---|---|---|---|---|---|
| Common | Carrot, Wheat | $25–35 | 6.4–8.9 | 150–210s | ~$600 |
| Uncommon | Lettuce, Potato, Beetroot | $90–110 | 21.3–26 | 270–330s | ~$1.2K |
| Rare | Tomato, Garlic, Corn | $270–315 | 57.3–66.9 | 390–450s | ~$2.5K |
| Epic | Strawberry, Pepper, Pumpkin | $750–920 | 145.2–178.1 | 540–660s | ~$5K |
| Legendary | Grape, Eggplant, Pineapple | $2,350–2,670 | 398–452.2 | 840–960s | ~$10K |
| Mythical | Candy Vine, Red Mushroom, Bubble Rash | $5,650–6,350 | 869.7–977.7 | 1020–1140s | ~$20K |

**Apex outliers (also Mythical tier, priced outside the normal curve):**
- **Crystal Blooms** — `price = 0` cash, costs **150 Fish Coins** instead. `baseValue = 1000`
  (highest in the game), 1200s grow. Entire sale is profit; throttled by how much fishing the
  player does (design note: "steady fishing sustains only ~2-3 slots").
- **Mango** — the ONLY perennial (`multiHarvest`, 4 fruit slots re-ripening every 600s forever
  once planted). `price = $60,000`, `baseValue = 147`. Nets ~$20K/hr in perpetuity once
  planted; ~3-hour payback on the $60K seed cost, then free money forever from that slot.

## Tier Gating — currently NONE (deliberately removed)

`CropTierConfig.TIERS` has every tier's `gates = {}` — **all crops are visible/purchasable by
anyone from session 1**, gated only by:
1. **Price** (Mythical crops cost $5.6K–$6.35K; a fresh player can't afford them yet).
2. **Shop stock RNG** — `ShopStock.APPEAR_CHANCE_BY_RARITY`: Common 65%, Uncommon 50%, Rare
   35%, Epic 22%, Legendary 12%, **Mythical 6%** chance to appear per 5-minute restock.
3. **Stock quantity when it does appear** — Legendary/Mythical: 5–10 units per restock.

History: tiers used to also gate on `TotalEarned`/`FruitsHarvested`/`MutationsFound`/
`PlotsOwned` stats (e.g. Mythical required $15M earned + 10 mutations). This was removed
because it stacked with the RNG wall and made Mythical crops invisible for hours of normal
play even for players who could otherwise afford them. **Design question for discussion:**
was removing gates entirely the right call, or does the ladder now lack a sense of
"unlocking" progression?

## Permanent Sinks (Plots + Growth Upgrades)

**Plots** — 8 physical soil beds per garden, bed 1 free, `cropsPerPlot = 10`:

| Bed # | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|
| Price | $5,000 | $20,000 | $75,000 | $200,000 | $500,000 | $1,200,000 | $2,500,000 |

Cumulative: **$4.5M**. Max capacity: 80 simultaneous crops.

**Growth Speed upgrade** — 8 levels, stacks additively with pet growth-reduction (capped 90%
total):

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Reduction | 5% | 10% | 15% | 20% | 25% | 30% | 35% | 40% |
| Price | $8,000 | $25,000 | $80,000 | $200,000 | $450,000 | $900,000 | $1,600,000 | $2,800,000 |

Cumulative: **$6.06M**. Combined with plots: **~$10.6M total sink**, tuned (per design
comment) to complete in **roughly 2-3 days of engaged play**, landing near when a player
would naturally have enough cash flow for Mythical crops.

## Pets & Eggs (multiplicative cash boost + optional grow-time reduction)

| Egg | Cost | Rarity | Cash Boost Range | Grow-Time Reduction (top pets) |
|---|---|---|---|---|
| Common | $300 | Common | +5–8% | — |
| Uncommon | $1,800 | Uncommon | +12–18% | — |
| Godly | $7,500 | Rare | +28–38% | up to 15% (Aether) |
| Galactic | $30,000 | Epic | +50–65% | up to 18% (Galactic Lord) |
| Divine | 100 💎 (Diamonds only) | Legendary | +85–100% | up to 12% (Divine Sun) |

Pet cash boost and Growth Speed upgrade **stack** (both apply to the same crop). Divine egg is
excluded from the cash shop entirely — Diamonds-only, meant as a monetization/premium-currency
sink. Diamonds are earned slowly via daily login (10 💎 on day 7 only) or purchased.

## Order Board (NPC "premium sell" alternative)

- 3 rotating orders per player, refreshing every 5 minutes.
- Reward = `expectedFruitValue * count * 0.85 (ORDER_PAYOUT_RATIO) * rarityAskMultiplier`.
- Rarity asks: 60% no minimum (×1 reward), 30% Uncommon+ (×1.3), 10% Rare+ (×1.8).
- Deliberately pays **below** average sell value (0.85x) in exchange for zero variance —
  design intent is "reliable floor income" vs. selling's "high-variance, mutations pay off."
  (Corrected mid-project: an earlier formula omitted the mutation-expectation term and
  accidentally made orders pay *less* than average selling — now fixed.)

## Rebirth (prestige reset)

- Cost: `$250,000 * 4^rebirthCount` (steep exponential: 1st = $250K, 2nd = $1M, 3rd = $4M...).
- Resets: Cash → $100 starting, all Inventory, all PlotData, PlotsOwned → 1 (loses all bought
  plots). **Keeps:** pets, order-completion history, achievements.
- Reward: permanent **+25% sell value per rebirth**, stacks (rebirth 3 = +75% forever).
- **Known design tension (flagged in code comments):** the growth curve is "unbalanced —
  exponential cost against a linear boost, and it resets PlotsOwned" — this is explicitly why
  crop-tier unlocks do NOT gate on rebirth count. The team's stated current end-game stance
  (from earlier discussion) is: *no rebirth-centric endgame yet* — a Legendary + unique pet is
  the intended near-term end-game instead, until rebirth itself is redesigned/polished.

## Daily Login (7-day streak, resets on missed day)

| Day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Cash | $50 | $100 | $200 | $350 | $600 | $1,000 | $2,000 |
| Diamonds | 0 | 0 | 0 | 0 | 0 | 0 | 10 |

## Fishing (secondary currency loop)

- Mash/reel minigame at fishing zones, rewards Fish Coins.
- Fish Coins have exactly one sink today: **Crystal Blooms Seed (150 🐟)** — the apex crop.
- No other Fish Coin sinks currently exist (single-purpose currency).

## Mutations

- **Growth mutations** (rolled at plant time, visible while growing): None (~94%), Golden
  (~4.95%, ×20 value), Rainbow (~1%, ×50 value).
- **Environmental mutations** (server-applied during weather): Wet (×2) during Rain, Shocked
  (×8) during Thunderstorm — stack multiplicatively with each other and with growth mutations.
- **Mutation Spray** gear ($3,500): guarantees Golden, 25% chance to also roll Rainbow, on the
  nearest crop — a cash sink that buys guaranteed value, not RNG-only.
- **Fertilizer** gear ($750): instantly finishes growing the nearest crop — a time-skip sink.

## Multiplayer / Social Systems

- **Crop Sell Leaderboard** — tracks single best-ever sale per crop across all servers
  (DataStore + cross-server MessagingService sync), displayed on a physical sign + UI panel.
  Bragging-rights only, no reward currently tied to it.
- **Pets are visible to other players** (recently fixed — was previously visible only to the
  owner due to a networking bug).

## Known Issues / Open Design Questions (for the price-system discussion)

1. **No tier-unlock progression feel.** Every crop is technically available from minute one;
   the only "unlock" is affording it and getting lucky with restock RNG. Is a sense of
   *earned* progression (beyond price) worth reintroducing in a way that doesn't create the
   old "invisible for hours" problem?
2. **Rebirth is not currently part of the endgame plan** and is mathematically punishing
   (exponential cost, linear reward, loses purchased plots). Needs a decision: redesign it,
   gate content behind it once redesigned, or deprecate/replace it with something else.
3. **Mango is a singular "solved" strategy** — one $60K purchase and a slot is permanently
   worth ~$20K/hr forever with no further decisions required. Is that intentional as an
   endgame "auto-income" reward, or does it undercut the rest of the crop-variety economy?
4. **Fish Coins are single-purpose** (only spend target is Crystal Blooms). Room for more Fish
   Coin sinks if fishing should feel like a fuller parallel economy rather than a side quest
   for one crop.
5. **Diamonds are scarce and mostly premium-currency-only** (10/week from login, else real
   money) — worth discussing whether Diamonds should have more free-to-earn paths if Divine
   pets (the strongest cash multiplier) should be attainable without spending.
6. **Retention pacing target from code comments:** Common egg session goal ~6-8 min, Uncommon
   ~15-20 min, Godly ~60-75 min, Galactic ~2-3 hrs, Divine ~8-10 hrs (multi-session). Plot +
   upgrade sinks target ~2-3 days of engaged play. No longer-term (week+) retention hook is
   explicitly designed yet beyond "more crops/eggs to save for."
