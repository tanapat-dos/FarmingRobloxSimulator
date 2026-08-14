# AGENTS.md

All agent-facing guidance for this repo lives in **[CLAUDE.md](CLAUDE.md)** —
repo map, architecture rules, security conventions, .rbxl gotchas, and
workflows. Read it before making changes.

Quick facts:
- Roblox game, Lua/Luau, synced with Rojo 7 (`rojo serve` + Studio plugin).
- No automated tests — verify by play-testing in Studio.
- The place file `Latest Farming Simulator.rbxl` contains instances the repo
  does not (ProfileStore, SeedData/ToolData config, world content). Never
  rename instance keys in `default.project.json`.
- Server-authoritative: the client never decides cash, prices, inventory, or
  ownership. Validate every remote argument.
- All economy tuning lives in `src/shared/Modules/EconomyBalance.lua`.
