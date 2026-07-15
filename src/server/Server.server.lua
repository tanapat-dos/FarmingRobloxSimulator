--[[
📦 Grow A Garden - Server Initialization Script
🔧 Author: TwinPlayzDev
🎥 YouTube: https://www.youtube.com/@TwinPlayz
🎥 Special Thanks: https://www.youtube.com/@senko2107 for inspiration and support

🧠 Description:
This script is responsible for bootstrapping all server-side services in the Grow A Garden Roblox experience. 
It dynamically loads and initializes each module within the `Services` folder and connects shared dependencies 
between them using a `cachedModules` system.

🧰 What are `cachedModules`?

The `cachedModules` table is a way to:
✅ Preload all service modules once.
✅ Avoid repeated `require()` calls across the codebase.
✅ Allow any service (e.g. DataService, MoneyService, InventoryService) to access other services directly and safely.

Think of it as an internal **service container** — each service module can reach others through `.cachedModules` injected at runtime.

📦 Example:
DataService can call functions from MoneyService via:
```lua
local moneyService = Service.cachedModules.MoneyService
moneyService.giveCash(player, 100)

--]]

local servicesFolder = script.Parent.Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StartTime = os.clock()

local remotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local function ensureRemoteEvent(name: string)
	if not remotesFolder:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
end

for _, remoteName in { "PetUse", "PetFollowUpdate", "UpdatePetBoost", "UpdateFriendBoost" } do
	ensureRemoteEvent(remoteName)
end

local cachedModules = {}

for _, moduleScript: ModuleScript in servicesFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		cachedModules[moduleScript.Name] = require(moduleScript)
	end
end

local requiredModule = require(script.CachedModules) 
requiredModule.Cache = cachedModules

for moduleName, moduleScript in cachedModules do
	
	moduleScript.cachedModules = cachedModules
	if typeof(moduleScript.init) == "function" then
		moduleScript.init()
	end
end

-- NOTE: the old RemoteEvents.Teleport server handler was removed on purpose.
-- TeleportManager.client.lua moves the character locally (the client owns its
-- character CFrame), so a server handler that trusts a client-sent position
-- was pure exploit surface (teleport-anywhere for free).
