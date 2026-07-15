# Game Overview

**Genre:** Grow a Garden simulator (Roblox)

**Core Gameplay Loop:**

1. Buy seeds from the seed shop
2. Plant seeds on your plot
3. Plants grow over time
4. Harvest crops (with possible mutations)
5. Sell crops for cash
6. Upgrade tools, unlock new seeds, roll pets for cash boosts
7. Repeat

---

# Core Systems

| System | Module | Role |
|--------|--------|------|
| Player data | `DataService` | Profile load/save, player template, `OwnedPets`, `EquippedPet` |
| Economy | `MoneyService` | Cash, selling, friend boost, pet boost |
| Plots | `PlotService` | Plot assignment, plant spawning, bed progression (start 1 bed, buy up to 6 in-garden, 10 crops per bed) |
| Seeds & shop | `SeedShopService` | Shop stock, restock, seed purchases |
| Inventory | `InventoryService` | Tools, seeds, gear activators |
| Harvesting | `HarvestService` | Server-side fruit harvest validation |
| Mutations | `MutationService` | Golden / Rainbow mutation logic |
| Pets | `PetService` | Gacha rolls, equip, pet cash boost |
| Weather | `WeatherService` | Sunny/Rain/Thunderstorm cycle; applies Wet (x2) / Shocked (x8) environmental mutations to fruits |
| Orders | `OrderService` | NPC order board: rotating deliver-N-crops orders at a premium; board spawns procedurally by the sell shop |
| Rebirth | `RebirthService` | Prestige loop: escalating cost resets cash/seeds/crops/plots (pets kept) for +25% permanent sell boost per rebirth; procedural altar by the sell shop |
| Gear | `GearService` | Supply kiosk by the seed shop: Fertilizer (instant grow/ripen) and Mutation Spray (guaranteed Golden, 25% Rainbow) — procedural consumable tools |
| Monetization | `ProductService` | DevProduct purchases |

**Client scripts (controllers):**

- `ProximityPrompts` — NPC dialogue, shop/sell interactions
- `TeleportManager` — HUD teleport buttons (garden, seeds, sell, pets)
- `WeatherClient` — rain particles, storm lightning, lighting mood, weather HUD banner
- `UITheme` — runtime theme pass (rounded corners, strokes, Gotham fonts, button hover/press feedback)
- `OrderBoardClient` — procedural order-board panel (open via the board's ProximityPrompt)
- `Toasts` — top-center notification popups for the `Notify` remote (plot purchases, capacity warnings)
- `PetClient` — Pet shop UI, pet follow
- `PetMenuClient` — 🐾 HUD button + "My Pets" panel (pets are profile data, not backpack tools)
- `CropReplicator` — Plant growth visuals, harvest prompts
- `UIEffects`, `FriendBoost`, `OwnerIcon`, `ClientEffects`

**Shared modules:**

- `SeedRarity`, `FruitNameParse`, `GetFruitValue`, `Monetization`
- `Mutations/Golden`, `Mutations/Rainbow` (growth, rolled at plant time: 5% / 1%)
- `Mutations/Wet`, `Mutations/Shocked` (environmental, applied by weather)

---

# Project Layout (Rojo)

```
src/
├── server/          → ServerScriptService
├── client/          → StarterPlayerScripts
└── shared/Modules/  → ReplicatedStorage.Modules
```

Open `Latest Farming Simulator.rbxl` in Studio. Run `rojo serve` and connect the Rojo plugin for live sync.

Scripts **not** managed by Rojo (live in `.rbxl` only): ProfileStore, SeedData, ToolData, FormatNumber, Satchel.

---

# Design Principles

- **Multiplayer first** — many players, server-authoritative
- **Modular code** — one service per concern, cached via `CachedModules`
- **Reusable systems** — extend existing modules before adding new ones
- **Data-driven config** — seed/tool data in ReplicatedStorage instances
- **Easy to extend** — new plants, pets, shops should plug into existing services

---

# Remote Flow Pattern

```
Client (UI / input) → RemoteEvent/Function → Server Service → DataService / validation → response
```

Never let the client set cash, inventory, or ownership directly.

---

# Current Features

- Personal plots with plant growth
- Seed shop with restock timer
- Sell shop (single item, bulk, price check)
- Crop mutations (Golden, Rainbow)
- Friend boost on earnings
- Pet gacha (5 egg tiers) with equip and cash boost
- Physical pet shop + NPC + HUD teleport

---

# Future Features

- Seasons
- Weather system
- Trading between players
- Quests
- Prestige
- Daily rewards
- Live events

---

# AI Workflow (Cursor Pro)

| Model | Role |
|-------|------|
| **Composer** | Repo-wide understanding, multi-file changes |
| **Grok 4.5** | Implement features, iterate quickly (best credit-to-quality) |
| **GPT-5.6 Sol** | Architecture, hard debugging, final review before merge |

Pipeline: Composer (map) → GPT-5.6 Sol (design) → Grok 4.5 (build) → Composer (repo-wide) → GPT-5.6 Sol (review)

Rules: `.cursor/rules/ai-model-usage.mdc` · `.cursor/rules/roblox-development.mdc`
