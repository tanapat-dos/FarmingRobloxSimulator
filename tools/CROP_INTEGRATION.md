# Crop Integration Guide

How to add or remodel a crop with `tools/IntegrateCropFromSelection.lua`, and the
gotchas we hit doing Carrot / Wheat / Tomato / Potato / Candy Vine. Read this before
wiring a new crop — it will save you the hour we spent debugging.

## The workflow (do it in this exact order)

1. **Be in EDIT mode.** Stop any playtest first (Shift+F5). See gotcha #1.
2. Place the crop's **4 stage models** in the Workspace, left → right:
   `seed/sprout → growing → mature → harvested fruit`.
   Only the first three become growth stages; the 4th builds the pickup Tool.
3. Make sure `EconomyBalance.CROPS["<Crop> Seed"]` exists (price / baseValue /
   growthTime / rarity) and Rojo has synced.
4. Select all 4 models. Set `CROP_NAME` at the top of the tool.
5. Run once with `DRY_RUN = true`. **Read the printed left-to-right order** — heights and
   mesh counts should climb from seed to mature; the 4th is the harvest fruit.
6. If the order is right, set `DRY_RUN = false` and run again.
7. Confirm the report: `=== <Crop> wired ===` with `seed / growing / mature` all > 0 and
   **no "Parent property is locked" errors**. The `[SelfCheck +2s]` line should report
   `ClientModel=true (N children) ServerModel=true fruitTool=true`.
8. Add the crop to `CropTierConfig.SEED_TIER`.
9. **Ctrl+S to SAVE.** See gotcha #4.
10. Play to verify it grows sprout → growing → mature and appears in the shop.

## Gotchas (all learned the hard way)

1. **Edit mode only.** If you run the Command Bar during a playtest, every instance fails
   with `The Parent property of X is locked, current parent: NULL`. Nothing is written.
   Stop the test and re-run.

2. **Wire in Edit → SAVE → then Play.** Command Bar changes made *during* a playtest are
   discarded when you Stop. Several "successful" wires vanished because they happened in a
   play session and were never saved. Always wire in Edit mode and Ctrl+S before playing.

3. **Full per-stage geometry, no MeshId dedup.** The original bug: the tool de-duplicated
   meshes by `MeshId` across stages and excluded harvest meshes. A growing plant reuses the
   same mesh assets each stage, so dedup collapsed seed/growing/mature into one ("all use the
   same mesh") or dropped meshes (missing purple ball, invisible carrot). Fixed via
   `PlantStageIntegrate.addStageMeshesFull` — each stage clones its model's FULL geometry.
   Do not reintroduce dedup.

4. **`SeedData` instance tree is the runtime source of truth, not `EconomyBalance.lua`.**
   `PlotService`'s growth tick and `SeedShopService` read the `SeedData` value folders live.
   Editing the Lua config alone changes nothing in-game until `tools/MigrateSeedDataEconomy.lua`
   (or the integration tool) pushes values into the tree.

5. **A seed only shows in the shop when it is fully playable.** `SeedData.isPlayable` requires
   `Assets.Plants.<Crop>` to have BOTH `ClientModel` AND `ServerModel`, plus the seed folder
   under `SeedData`, plus a Tool in `ServerStorage.CropSeeds`, plus an entry in
   `SeedData.seedOrder`. If a wire half-completes, the crop silently drops out of the shop.
   Carrot & Wheat are in `GUARANTEED_SEEDS` (always stocked); others appear on the random
   restock rotation, so "not in shop" can just be RNG — use `GiveTestSeeds.lua` to grab them.

6. **Studio caches required ModuleScripts for the whole Edit session.** After Rojo syncs a
   module mid-session, a plain `require()` in the Command Bar returns the STALE table. The tool
   uses `requireFresh` (require a throwaway clone) for both `EconomyBalance` and
   `PlantStageIntegrate` to dodge this. A stale `PlantStageIntegrate` was why an early run hit
   `attempt to call a nil value` on `addStageMeshesFull`.

7. **One Studio window, one place file.** If two Studio windows (or `Farming Simulator.rbxl`
   vs `Latest Farming Simulator.rbxl`) are open, MCP/Command Bar can land in a different session
   than the one you're looking at — the wire "disappears." Keep a single window open.

8. **MCP read lag on freshly created folders.** Right after a wire, MCP `children` queries
   sometimes reported the new `ClientModel` as missing for a while even though it was there.
   The `[SelfCheck +2s]` print inside the tool reads the tree from *inside* Studio and is the
   authoritative check — trust it over an immediate external query, or poll with `wait_for_child`.

## Testing helpers

- `tools/GiveTestSeeds.lua` — run in a playtest with the Command Bar context set to **Server**.
  Grants seeds + sets cash + shrinks grow time. All session-only (reverts on Stop).
- To test a single crop's grow quickly without the tool, set its
  `SeedData.<Crop> Seed.GrowthTime` value directly (e.g. 10), then set it back (or run
  `MigrateSeedDataEconomy.lua`). Don't Ctrl+S with the test value or it becomes permanent.
- `STARTING_CASH` in `EconomyBalance.lua` only applies to a brand-new player profile; an
  existing saved profile keeps its balance.
