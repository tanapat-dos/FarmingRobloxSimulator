# Farming Roblox Simulator - Rojo Project

This project uses **Rojo** for live-sync between your `.lua` files and Roblox Studio.

## Project Structure

```
FarmingRobloxSimulator/
├── default.project.json      ← Rojo config
├── Latest Farming Simulator.rbxl  ← Roblox place file (open this in Studio)
└── src/
    ├── server/
    │   ├── Server.server.lua           ← Bootstrap all services
    │   ├── Server/
    │   │   └── CachedModules.lua       ← Shared service cache
    │   └── Services/
    │       ├── DataService/
    │       │   ├── init.lua            ← Player data / profile management
    │       │   └── Template.lua        ← Default player data template
    │       ├── SeedShopService.lua     ← Shop stock, buying, planting seeds
    │       ├── ProductService.lua      ← DevProduct purchase handling
    │       ├── InventoryService/
    │       │   ├── init.lua            ← Inventory management
    │       │   ├── SeedActivator.lua   ← Activated when planting a seed tool
    │       │   └── GearActivator.lua   ← Activated when using a gear tool
    │       ├── HarvestService.lua      ← Handles fruit harvesting
    │       ├── MutationService.lua     ← Plant mutation logic
    │       ├── PlotService.lua         ← Player plot assignment & plant spawning
    │       └── MoneyService.lua        ← Cash, selling fruits, friend boost
    ├── client/
    │   ├── UIEffects.client.lua        ← Click sounds, hover effects, cash HUD
    │   ├── ProximityPrompts.client.lua ← Shop interactions, NPC dialogue, selling
    │   ├── NPCHandler.client.lua       ← NPC head tracking
    │   ├── GetMouseCF.client.lua       ← Mouse position remote
    │   ├── ClientEffects.client.lua    ← Client-side visual effects
    │   ├── OwnerIcon.client.lua        ← Plot owner avatar visibility
    │   ├── FriendBoost.client.lua      ← Friend boost HUD label
    │   ├── CmdrClient.client.lua       ← Admin command client (F4)
    │   └── CropReplicator/
    │       └── Main.client.lua         ← Plant growth visuals & harvest prompts
    └── shared/
        └── Modules/
            ├── Monetization.lua        ← DevProduct/Gamepass IDs
            ├── SeedRarity.lua          ← Rarity color definitions
            ├── FruitNameParse.lua      ← Parse fruit name strings
            ├── GetFruitValue.lua       ← Calculate fruit sell value
            ├── ClientEffects/
            │   └── PlantEffect.lua     ← Plant spawn visual effect
            └── Mutations/
                ├── Golden.lua          ← Golden mutation visual
                └── Rainbow.lua         ← Rainbow mutation visual
```

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
