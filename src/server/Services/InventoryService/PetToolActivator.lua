local Players = game:GetService("Players")

local cachedModules = require(game.ServerScriptService.Server.CachedModules)

local Activator = {}
local Tool: Tool = script.Parent

local function getOwner(): Player?
	local parent = Tool.Parent
	if parent:IsA("Backpack") then
		return parent.Parent
	end
	if parent:IsA("Model") then
		return Players:GetPlayerFromCharacter(parent)
	end
	return nil
end

local function tryEquip()
	local player = getOwner()
	if not player then
		return
	end
	local petService = cachedModules.Cache.PetService
	if petService and petService.equipPet then
		petService.equipPet(player, Tool:GetAttribute("petId"))
	end
end

Tool.Equipped:Connect(tryEquip)
Tool.Activated:Connect(tryEquip)

-- Unequipped is intentionally NOT wired here.
-- The pet persists until the player explicitly deactivates it via Activated.
-- Unequip is handled by PetBackpackClient firing PetUse "unequip" on the server.

return Activator
