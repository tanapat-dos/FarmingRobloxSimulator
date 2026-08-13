# Farming Roblox Simulator - Rojo Project

This project uses **Rojo** for live-sync between your `.lua` files and Roblox Studio.

> 🤖 **Developing with an AI agent?** Read **[CLAUDE.md](CLAUDE.md)** first —
> it's the full map: architecture rules, security conventions, .rbxl gotchas,
> and workflows. `PROJECT.md` has the game-design overview.

## Project Structure

```
FarmingRobloxSimulator/
├── default.project.json           ← Rojo config (file → instance mapping)
├── Latest Farming Simulator.rbxl  ← Roblox place file (open this in Studio)
├── CLAUDE.md / AGENTS.md          ← AI development guide
├── tools/                         ← One-off Studio command-bar scripts (not synced)
└── src/
    ├── server/                    → ServerScriptService
    │   ├── Server.server.lua      ← Bootstrap: requires + init()s all services
    │   ├── Server/CachedModules.lua ← Service locator
    │   └── Services/              ← One service per concern (Data, Plot, Shop,
    │                                Inventory, Harvest, Money, Product, Pet,
    │                                Weather, Order, Rebirth, Gear, …)
    ├── client/                    → StarterPlayerScripts
    │   ├── hud/                   ← Persistent HUD (menu bar, toasts, boosts, theme)
    │   ├── panels/                ← Openable panels (pets, orders, achievements, …)
    │   └── world/                 ← World-facing (crop visuals, prompts, NPCs, weather)
    └── shared/Modules/            → ReplicatedStorage.Modules (both sides)
                                     EconomyBalance (all tuning), fruit parsing,
                                     rarity config, Mutations/
```

The client subfolders are **disk organization only** — Rojo maps every script
back to the same flat instance names in `StarterPlayerScripts`, so nothing in
the place file changes.

## Scripts NOT managed by Rojo (stay in .rbxl)
These are third-party or instance-data scripts that live only in the `.rbxl` file:
- `DataService/ProfileStore` — loleris's ProfileStore library (1685 lines)
- `Modules/SeedData` — has child Folder instances with seed config values
- `Modules/ToolData` — has child Folder instances with tool config values
- `Modules/FormatNumber` — third-party number formatting library
- `StarterPlayerScripts/Satchel` — third-party backpack system

## How to use Rojo

### 1. Install Rojo (if not already installed)
```powershell
# Via rokit (recommended)
rokit add rojo

# Or via cargo
cargo install rojo
```

### 2. Start the Rojo server
Open a terminal in this folder and run:
```powershell
rojo serve
```
You should see: `Rojo server listening on port 34872`

### 3. Connect Studio
1. Open `Latest Farming Simulator.rbxl` in Roblox Studio
2. Make sure the **Rojo** plugin is installed in Studio
3. Click **Connect** in the Rojo plugin panel
4. Rojo will sync your `.lua` files → Studio instantly

### 4. Edit scripts
- Edit any `.lua` file in Cursor
- Changes sync to Studio automatically
- **No need to manually save in Studio anymore**

### 5. Save the place
When you want to save the full place (including non-Lua assets):
- Press `Ctrl+S` in Roblox Studio to save the `.rbxl` file

## Important Notes

- **Always open the `.rbxl` file in Studio before running `rojo serve`** — Rojo needs the existing instances (SeedData, FormatNumber, ProfileStore, etc.)
- The `$ignoreUnknownInstances: true` flags in `default.project.json` tell Rojo to leave existing Studio instances alone (like ProfileStore, SeedData children, PlotService config folders)
- If you see a Rojo port conflict, kill the old process: `taskkill /f /im rojo.exe`
