# CLAUDE.md — AI Development Guide

Read this first. It is the map + rulebook for working on this repo with an AI
agent (Claude Code, Cursor, etc.). `AGENTS.md` points here; `PROJECT.md` has
the game-design overview; `README.md` has the Rojo/Studio workflow.

## What this is

A multiplayer Roblox "Grow a Garden" simulator (Lua/Luau, synced to Studio via
**Rojo 7**). Core loop: buy seeds → plant on your plot → wait for growth →
harvest (mutation RNG) → sell for cash → pets/gear/rebirth multipliers → repeat.

**There are no automated tests.** Verification = `rojo serve` + Roblox Studio
play-test. Be extra careful with pure-logic edits; they ship unverified.

## Repo map

```
default.project.json   Rojo tree: maps every file below to a Roblox instance
src/
├── server/            → ServerScriptService
│   ├── Server.server.lua        Bootstrap: requires + init()s every service
│   ├── Server/CachedModules.lua Service locator (breaks require cycles)
│   └── Services/                One service per concern:
│       ├── DataService/         ProfileStore profiles, Template.lua = data schema
│       ├── PlotService.lua      Plot assignment, plant spawning, growth loop
│       ├── SeedShopService.lua  Global shop stock (MemoryStore), BuyCrop
│       ├── InventoryService/    Items + tool activators (Seed/Gear/GearUse)
│       ├── HarvestService.lua   Server-validated harvesting
│       ├── MoneyService.lua     Cash/diamonds, selling, boosts
│       ├── ProductService.lua   Robux dev-products (ProcessReceipt)
│       ├── PetService.lua       Pet gacha, equip, boosts
│       └── ...                  Orders, Rebirth, Weather, DayNight, Gear,
│                                Achievements, DailyLogin, GardenUpgrade, etc.
├── client/            → StarterPlayerScripts (LocalScripts)
│   ├── hud/           Persistent HUD: MenuBar, Toasts, boosts, theming, teleports
│   ├── panels/        Openable UI panels: pets, orders, achievements, daily login…
│   └── world/         World-facing: CropReplicator (plant visuals), prompts,
│                      NPCs, weather/day-night effects, GetMouseCF
└── shared/Modules/    → ReplicatedStorage.Modules (used by BOTH sides)
    ├── EconomyBalance.lua   ⭐ single source of truth for all tuning numbers
    ├── FruitNameParse.lua   Parses fruit display strings (see Item identity)
    ├── GetFruitValue.lua    Sell-price formula
    └── ...                  Rarity config/effects, shop stock rules, Mutations/
tools/                 One-off Studio command-bar scripts (NOT synced by Rojo)
```

The **on-disk folders under `src/client/` are organization only** — Rojo flattens
them back to the same instance names in `StarterPlayerScripts`. Moving a file on
disk requires updating its `$path` in `default.project.json`; the instance name
(the JSON key) must NOT change.

## Critical gotcha: the .rbxl owns instances the repo can't see

`Latest Farming Simulator.rbxl` contains things that exist **only in the place
file**, preserved by `$ignoreUnknownInstances` in `default.project.json`:

- `DataService/ProfileStore` — loleris's ProfileStore library (ModuleScript)
- `Modules/SeedData`, `Modules/ToolData` — config as Folder/Value instances
- `Modules/FormatNumber`, `StarterPlayerScripts/Satchel` — third-party libs
- Baked *children* of synced scripts: `ProximityPrompts.Highlight`,
  `Mutations/Golden.Part`, `Mutations/Rainbow.Part`
- World content: `workspace.Plots`, `workspace.Shops`, `workspace.World.Map`,
  `ReplicatedStorage.Assets` (crop/plant models), `RemoteEvents` folder,
  `ServerStorage.CropSeeds` / `Tools`

Consequences:
- **Never rename or move instances in `default.project.json`** without checking
  the .rbxl — renaming a key orphans its baked children and breaks references.
- Code like `require(...Modules.SeedData)` or `script.Highlight` resolves to
  .rbxl-only instances. `grep` finding nothing does NOT mean it's unused.
- A source-only `rojo build` will not produce a runnable game. Always work
  against the existing place file.

## Architecture rules

**Service pattern.** Every server system is a ModuleScript in `Services/` with
an `init()`. `Server.server.lua` requires them all into
`CachedModules.Cache[name]`, then calls every `init()`. Services reference each
other via `cachedModules.Cache.X` (lazily, inside functions — not at module
top-level) to avoid require cycles.

**Remote flow.** `Client UI → RemoteEvent/Function → Server service → DataService
→ response`. The client NEVER decides prices, amounts, ownership, or inventory.
Remotes live in `ReplicatedStorage.RemoteEvents` (created in the .rbxl).

**Player data.** `DataService.getData(player)` returns the profile data table or
nil. It's nil until the `DataLoaded` player attribute is true — every remote
handler must gate on `player:GetAttribute("DataLoaded") == true`. The data
schema is `DataService/Template.lua`; add new fields there (ProfileStore
`Reconcile()` backfills existing profiles). In Studio, profiles are in-memory
mocks (no ProfileStore/MemoryStore) — check `IS_STUDIO` branches when a system
behaves differently in Studio vs live.

**Robux purchases** (`ProductService.lua`): ProcessReceipt must (1) return
`NotProcessedYet` unless the profile is loaded, (2) verify the grant function
actually succeeded (grant functions return success), (3) record
`receiptInfo.PurchaseId` in `profileData.ProcessedReceipts` for idempotency,
(4) `profile:Save()` after granting. Keep this contract when adding products.

## Security & robustness conventions (hard-won — keep them)

1. **Validate every remote argument type** (`typeof(x) ~= "string" then return`)
   before using it in `FindFirstChild`/indexing — exploiters send tables.
2. **`InvokeClient` is hostile territory**: always `pcall` it AND type-check the
   result (`typeof(result) == "CFrame"`), like `SeedActivator.lua`. A client can
   hang, error, or return garbage.
3. **Rate-limit remotes that hit MemoryStore/DataStore** (see `BuyCrop`,
   `PetRoll`): per-player `os.clock()` debounce, cleaned up on PlayerRemoving.
4. **Charge/consume only after success**: check `removeCash`/`removeDiamonds`
   return values; consume gear/items only when the action actually happened.
5. **`player.Character` can be nil at any moment** (death/respawn). Guard before
   indexing, especially in code that runs after inventory mutations.
6. **Declare `local function`s before their callers.** A forward reference
   compiles as a nil global and only fails at runtime.
7. **Per-player state tables** must be cleaned in `PlayerRemoving`.
8. Client: never `WaitForChild` (timeout-less) inside RenderStepped or at
   module scope of shared code; disconnect connections whose lifetime outlives
   the UI they update; don't blanket-toggle workspace state you don't own
   (see `toggleAllPrompts` in `ProximityPrompts`).

## Item identity (fragile — handle with care)

Fruits are stored in `profileData.Inventory` as **display strings** keyed by
`"<FruitName>:<8-char-guid>"`, formatted as `[Rarity] [Mut1, Mut2] Name [<w>kg]`
(built by `FruitInventoryFormat.build`). `FruitNameParse` is the ONLY parser:
it returns `rarity, mutations, weight, name` where **weight and name are nil
when the string is malformed — always nil-check before using them.** Seeds are
stored as `{ Count = n }` keyed by seed name. Plant keys are
`"<SeedPrefix>:<5-char-guid>"` (`PlantKeyUtil`). If you add mutations or
rarities, they must not contain `,` `[` `]` `:` or match a rarity tier name.

## Economy tuning

`src/shared/Modules/EconomyBalance.lua` is the single source of truth (crops,
eggs, rebirth, plots, gear). Sell price = `baseValue × weight² × growthMutation
(Golden ×20 / Rainbow ×50) × rarity × environmental (Wet ×2 / Shocked ×8)`,
then cash multipliers (friends/pets/rebirths) on top. Baseline (non-mutated)
ROI is roughly break-even by design — profit comes from the mutation lottery.
**Do not fork tuning tables into `tools/`** (a stale fork previously masked a
carrot growthTime bug); `tools/RebalanceEconomy.lua` reads the live module.

## Workflows

```bash
rokit install       # once: installs pinned rojo + selene + stylua (rokit.toml)
rojo serve          # then connect the Rojo plugin in Studio
selene src tools    # lint — treat ERRORS as blockers (warnings are legacy debt)
stylua <file>       # format files you create/rewrite; don't mass-reformat
```

**CI**: the workflow lives at `.github/ci.yml.pending` — it could not be pushed
to `.github/workflows/` because the repo's access token lacks the `workflow`
scope. **To activate:** move it to `.github/workflows/ci.yml` (GitHub web UI, or
push with a `workflow`-scoped token). It runs on every push/PR: `rojo build`
from source is the hard gate (broken project.json, missing files, unparsable
sources); selene runs as an advisory job until legacy warnings are cleaned up.
Once active: after pushing, check that CI is green.
Open `Latest Farming Simulator.rbxl` FIRST, then serve/connect (Rojo needs the
existing instances). Play-test in Studio (F5). Studio mode = mock data: fresh
profile every run, instant in-memory shop stock, no MemoryStore/MessagingService.

- New crop: add to `EconomyBalance.CROPS` + SeedData folder (.rbxl, via
  `tools/AddSeedModels.lua`) + model in `ReplicatedStorage.Assets` + run
  `tools/IntegrateCrops.lua` in Studio. See `tools/` scripts for the pipeline.
- New service: create in `Services/`, add to `default.project.json`, register
  in `Server.server.lua` (require + init), follow the conventions above.
- New player-data field: add to `DataService/Template.lua` (Reconcile handles
  old profiles).

## Known debt / watch-outs (as of 2026-08)

- `Mutations/Golden|Rainbow.lua` depend on baked `script.Part` children in the
  .rbxl (they degrade gracefully if missing, but Wet/Shocked build effects
  procedurally — prefer that pattern for new mutations).
- Stock adjustments go through `TryAdjustStock` (MemoryStore `UpdateAsync`,
  atomic). Never revert to Get → mutate → Set for stock decrements.
- `GetMouseCF` RemoteFunction is client-served; treat every consumer like #2
  above.
- Baseline (non-mutated) crop ROI is ~break-even by design intent question:
  comments in EconomyBalance promise tier-progression ROI, but nearly all
  profit comes from mutation RNG. Retuning baseValue/price ratios is an open
  design decision — don't change unilaterally.
- Selene reports legacy warnings across the codebase; clean them
  opportunistically, then make the CI lint job blocking.
