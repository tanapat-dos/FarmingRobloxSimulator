# Implementation Plan: Economy Rebalance

## Overview

Makes farming profitable and gives the crop tier ladder real progression teeth. Work order is
constrained by two facts about this codebase:

1. **`SeedData` (a Studio instance tree) is the runtime source of truth**, not
   `EconomyBalance.lua`. Editing the Lua file alone changes nothing in game, so the migration
   in task 4 is load-bearing for everything after it.
2. **The arithmetic is the correctness check.** There is no test framework here, and a bad
   number silently ships. Task 1 validates every value before anything is written, so a
   mistake is caught in a script rather than in the place file.

Tasks 5–8 are independent of each other once the config and module exist, so they can be done
in any order or in parallel.

## Task Dependency Graph

```
1 (verify math)
└── 2.1 (CropTierConfig) ──┬── 2.2 (register module)
    │                      │
    └──────────────────────┴── 3.1 (CROPS) ── 4 (SeedData migration) ──┬── 5.1 (carrot weight)
                               3.2 (sinks) ───┘                        ├── 5.2 (gating/stock view)
                                                                       │   └── 5.3 (BuyCrop recheck)
                                                                       ├── 6 (OrderService)
                                                                       ├── 7 (FishCoinShopService)
                                                                       └── 8 (shop UI locked rows)
                                                                             │
                                                                             └── 9 (Studio verify)
```

- **1** gates everything. Do not write data until its assertions pass.
- **2.1** must precede 5.2, 5.3, 6, 7 and 8 — all of them read `CropTierConfig`.
- **4** must precede 9, and realistically precedes any in-game check, since nothing takes
  effect until `SeedData` is migrated.
- **5.3** depends on 5.2 only for shared helpers; the gate re-check is independent logic.
- **9** is last and validates the whole chain.

```json
{
  "waves": [
    {
      "wave": 1,
      "tasks": ["1"],
      "rationale": "Arithmetic gate. Every proposed value is validated against the profitability, monotonicity and tier-coverage properties before any data is written."
    },
    {
      "wave": 2,
      "tasks": ["2.1", "3.1", "3.2"],
      "rationale": "Authoring layer. CropTierConfig and the EconomyBalance tables are independent files and can be written in parallel once the numbers are confirmed."
    },
    {
      "wave": 3,
      "tasks": ["2.2", "4"],
      "rationale": "Wiring and migration. Registering the module in the Rojo tree and pushing EconomyBalance values into the Studio SeedData instance tree, which is what actually takes effect in game."
    },
    {
      "wave": 4,
      "tasks": ["5.1", "5.2", "6", "7", "8"],
      "rationale": "Consumers. All read CropTierConfig and migrated SeedData but touch different files, so they are mutually independent."
    },
    {
      "wave": 5,
      "tasks": ["5.3"],
      "rationale": "Server-side gate re-check in the BuyCrop handler, layered onto the stock-view work from 5.2."
    },
    {
      "wave": 6,
      "tasks": ["9"],
      "rationale": "End-to-end Studio verification of the whole chain."
    }
  ]
}
```

## Tasks

- [x] 1. Verify the rebalance arithmetic before changing any data
  - Write a throwaway Luau script under `tools/VerifyEconomyMath.lua` that recomputes, for all
    18 crops, `revenue = baseValue × E[weight²] × E[mutation] × rarityAvg(tier)` using the
    proposed values
  - Assert Property 1 (every crop `revenue ≥ 1.9 × price`), Property 2 (profit per slot-hour
    strictly increasing across tiers for cash crops), Property 6 (each crop in exactly one
    tier, no empty tiers)
  - Handle Mango separately with the perennial formula
    (`fruits/hr = harvestCount × 3600/harvestInterval`) and its reduced weight roll
    (E[weight²] = 1.302)
  - Print a table of price / baseValue / growth / profit-per-slot-hour per crop for review
  - Do not proceed to any later task until all three properties pass
  - _Design: Correctness Properties 1, 2, 6; Testing Strategy_

- [x] 2. Create the shared tier config module
- [x] 2.1 Write `src/shared/Modules/CropTierConfig.lua`
  - `TIER_ORDER` = Common, Uncommon, Rare, Epic, Legendary, Mythical
  - `TIERS[tier] = { label, gates = { { stat, goal }, ... } }` with the thresholds from the
    design (Rare `TotalEarned ≥ 25000`; Epic `TotalEarned ≥ 250000` + `PlotsOwned ≥ 3`;
    Legendary `TotalEarned ≥ 2000000` + `FruitsHarvested ≥ 500`; Mythical
    `TotalEarned ≥ 15000000` + `MutationsFound ≥ 10`)
  - `SEED_TIER[seedName] = tier` for all 18 crops
  - `isUnlocked(stats, tier)` — all gates must pass; empty gate list returns true
  - `getUnlockProgress(stats, tier)` — returns `{ { stat, have, goal, met } }` for tooltips
  - `getTierForSeed(seedName)` — returns `nil` for unknown seeds (fail closed)
  - Treat any missing stat field as `0` so pre-existing profiles gate correctly
  - _Design: Components and Interfaces (CropTierConfig); Error Handling_

- [x] 2.2 Register the module in `default.project.json`
  - Add `CropTierConfig` under `ReplicatedStorage.Modules`
  - _Design: Files affected_

- [x] 3. Rewrite the economy config
- [x] 3.1 Replace `EconomyBalance.CROPS` with the rebalanced table
  - Set `price`, `baseValue`, `growthTime` and `rarity` (tier) per the design's crop table
  - Mango: `baseValue = 147`, `price = 60000`; leave `multiHarvest`, `harvestCount = 4` and
    `harvestInterval = 600` exactly as they are
  - Crystal Blooms: `baseValue = 1000`, `growthTime = 1200`, single-harvest; its price is in
    Fish Coins and lives in `FishCoinShopService`, not here
  - _Design: Data Models (EconomyBalance.CROPS); Correctness Property 7_

- [x] 3.2 Rescale `PLOTS.prices` and `UPGRADES.GrowthReduction.levels`
  - Plots: 0, 5000, 20000, 75000, 200000, 500000, 1200000, 2500000
  - Growth upgrades: 8000, 25000, 80000, 200000, 450000, 900000, 1600000, 2800000
  - Fix the stale cumulative-cost comment above `UPGRADES`
  - _Design: Data Models (PLOTS, UPGRADES)_

- [ ] 4. Migrate values into the Studio `SeedData` instance tree
  - Write `tools/MigrateSeedDataEconomy.lua` following the `setValue` pattern from
    `tools/IntegrateCrystalBlooms.lua`
  - For each entry in `EconomyBalance.CROPS`, write `Price`, `BaseValue` and `GrowthTime` into
    `ReplicatedStorage.Modules.SeedData[seedName]`
  - Must **not** write `HarvestCount`, `HarvestInterval` or `MultiHarvest` (mesh-bound)
  - Warn and skip on any seed with no `SeedData` folder rather than creating one
  - Print a before/after line per crop so the diff is reviewable
  - Run it in Studio, then spot-check several crops across tiers via MCP to confirm
    Property 5 (config and instance tree agree)
  - _Design: Architecture (Source-of-truth constraint); Correctness Properties 5, 7_

- [x] 5. Update `SeedShopService`
- [x] 5.1 Remove the Carrot fixed-weight special case
  - Delete the `if name == "Carrot Seed" then return 1 end` early return in
    `getRandomFruitSize` so Carrot uses the standard roll
  - _Design: Architecture decision 5_

- [x] 5.2 Add per-player tier gating
  - Keep `GenerateStock` global (all tiers rolled) so the MemoryStore restock cycle is shared
  - Add `buildPlayerStockView(player, stock)` returning `{ stock, lockedTiers }`, filtering out
    crops whose tier fails `CropTierConfig.isUnlocked` and describing each locked tier with
    `getUnlockProgress`
  - Use that view wherever `ResetSeedShop` is fired to a specific player (`PlayerAdded` retry
    loop) and on broadcast (fire per player rather than `FireAllClients`)
  - If `DataLoaded ~= true`, treat all gated tiers as locked and skip pushing; the existing
    retry loop will push once data is ready
  - _Design: Architecture (Gating enforcement); Error Handling_

- [x] 5.3 Re-check the gate inside the `BuyCrop` handler
  - Before charging, verify `CropTierConfig.isUnlocked` for the crop's tier and reject if not
  - Reject crops whose `getTierForSeed` returns `nil`
  - _Design: Correctness Property 3_

- [x] 6. Correct the `OrderService` reward formula
  - Replace `EXPECTED_WEIGHT_SQ × ORDER_BONUS` with
    `E[weight²] × E[mutation] × rarityAvg(tier) × 0.85`
  - Read the crop's tier via `CropTierConfig` to pick the right `rarityAvg`
  - Use Mango's reduced `E[weight²]` when generating a Mango order
  - Confirm order rewards land just below the expected sell value for the same fruits
  - _Design: Components and Interfaces (OrderService)_

- [x] 7. Update `FishCoinShopService`
  - Crystal Blooms price → `150` Fish Coins
  - Apply the Mythical gate to the offer listing so it cannot be bought before the tier unlocks
  - Re-check the gate server-side in the `BuyFishCoinItem` handler, matching task 5.3
  - _Design: Components and Interfaces (FishCoinShopService); Correctness Property 3_

- [x] 8. Render locked tiers in the seed shop UI
  - Update `tools/ShopScript.lua` (the reference copy of Studio `StarterGui.Shop`) to read the
    `lockedTiers` payload from `ResetSeedShop`
  - Render a locked row per locked tier showing label and progress, e.g.
    `Legendary — $340K / $2M earned`
  - Locked rows must be visually distinct and non-purchasable
  - Push the updated source into Studio and verify line count matches the local file
  - _Design: Architecture (Gating enforcement); Components and Interfaces (seed shop UI)_

- [ ] 9. Verify in Studio
  - Confirm `SeedData` matches `EconomyBalance.CROPS` for a sample across all six tiers
  - Fresh profile: buy a Carrot, harvest, confirm sell value exceeds the $25 seed cost — the
    core smoke test that farming is profitable
  - Fresh profile: seed shop shows only Common and Uncommon as purchasable; Rare renders as a
    locked row with progress
  - Grant `TotalEarned` past a gate threshold and confirm the tier becomes purchasable (note
    whether a restock is required)
  - Fire `BuyCrop` for a locked crop from the client and confirm rejection
  - Plant a Mango, confirm it still regrows on its 600s interval after harvesting
  - Deliver an order and confirm the reward sits just below selling the same fruits
  - Check `manage_logs` for errors after each step
  - _Design: Testing Strategy_

## Notes

**Studio sync.** Per project steering, every Studio script write uses `manage_scripts`
`set_source` with the full file, never partial edits, and line count is verified against the
Rojo file afterwards. Rojo also syncs `src/` in parallel.

**`HarvestCount` is mesh-bound.** `HarvestCount`, `HarvestInterval` and `MultiHarvest`
correspond to fruit attachment points on the plant models and must never be written by the
migration script (Correctness Property 7). Mango stays `4 / 600` perennial; every other crop
including Crystal Blooms is single-harvest.

**Mango is currently the only profitable crop** because perennial regrowth is uncapped. Its
price rises 37x ($1,600 → $60,000) and `baseValue` drops to 147. Existing Studio mock profiles
holding cheap Mangos will be sitting on a distorted asset and may want resetting before
verification.

**Unmeasured assumption.** The 150 Fish Coin price for Crystal Blooms rests on an estimated
~1,100 coins/hour fishing rate (2.5s cast cooldown, ~4.4 coins average catch). If task 9
suggests real throughput differs materially, revisit the price rather than the crop's stats.

**Out of scope.** Rebirth rework (inverted cost curve, plot wipe), the pet endgame (weighted
roll odds, `Evolved` models, fusion), achievement retuning, and the "Next Goal" onboarding
tracker. See Deferred Work in the design.
