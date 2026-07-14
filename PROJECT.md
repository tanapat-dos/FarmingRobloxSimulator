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
| Plots | `PlotService` | Plot assignment, plant spawning on player farms |
| Seeds & shop | `SeedShopService` | Shop stock, restock, seed purchases |
| Inventory | `InventoryService` | Tools, seeds, gear activators |
| Harvesting | `HarvestService` | Server-side fruit harvest validation |
| Mutations | `MutationService` | Golden / Rainbow mutation logic |
| Pets | `PetService` | Gacha rolls, equip, pet cash boost |
| Monetization | `ProductService` | DevProduct purchases |

**Client scripts (controllers):**

- `ProximityPrompts` — NPC dialogue, shop/sell interactions
- `TeleportManager` — HUD teleport buttons (garden, seeds, sell, pets)
- `PetClient` — Pet shop UI, equip, pet follow
- `CropReplicator` — Plant growth visuals, harvest prompts
- `UIEffects`, `FriendBoost`, `OwnerIcon`, `ClientEffects`

**Shared modules:**

- `SeedRarity`, `FruitNameParse`, `GetFruitValue`, `Monetization`
- `Mutations/Golden`, `Mutations/Rainbow`

---

# Project Layout (Rojo)

```
src/
├── server/          → ServerScriptService
├── client/          → StarterPlayerScripts
└── shared/Modules/  → ReplicatedStorage.Modules
```

Open `GrowGardenKit.rbxl` in Studio. Run `rojo serve` and connect the Rojo plugin for live sync.

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
