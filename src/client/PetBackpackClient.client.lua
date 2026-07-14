local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local petUse = remotes:WaitForChild("PetUse", 60)

-- Track which petId is currently active so Activated can toggle it off
local activePetId: string? = nil

local hookedTools = {}

if not petUse then
	warn("[PetBackpackClient] PetUse remote missing — pet equip from backpack disabled")
	return
end

local petFollowUpdate = remotes:WaitForChild("PetFollowUpdate", 60)
if petFollowUpdate then
	petFollowUpdate.OnClientEvent:Connect(function(state)
		if state.equipped then
			-- server confirmed equip; record which pet is active
		else
			activePetId = nil
		end
	end)
else
	warn("[PetBackpackClient] PetFollowUpdate remote missing")
end

local function hookPetTool(tool: Tool)
	if not tool:IsA("Tool") or tool:GetAttribute("isPet") ~= true then
		return
	end
	if hookedTools[tool] then
		return
	end
	hookedTools[tool] = true

	local petId = tool:GetAttribute("petId")
	if not petId then
		return
	end

	-- Selecting the pet slot equips/spawns it
	tool.Equipped:Connect(function()
		activePetId = petId
		petUse:FireServer("equip", petId)
	end)

	-- Clicking Use while pet is selected toggles it off
	tool.Activated:Connect(function()
		if activePetId == petId then
			activePetId = nil
			petUse:FireServer("unequip", petId)
		else
			activePetId = petId
			petUse:FireServer("equip", petId)
		end
	end)

	-- Switching away from the pet tool (another tool selected) must NOT despawn the pet.
	-- The pet persists until the player explicitly deactivates it.
	-- tool.Unequipped is intentionally NOT wired to unequip.

	tool.Destroying:Connect(function()
		hookedTools[tool] = nil
		if activePetId == petId then
			activePetId = nil
		end
	end)
end

local function watchContainer(container: Instance?)
	if not container then
		return
	end
	container.ChildAdded:Connect(function(child)
		hookPetTool(child)
	end)
	for _, child in container:GetChildren() do
		hookPetTool(child)
	end
end

local function onCharacterAdded(character: Model)
	watchContainer(player:WaitForChild("Backpack"))
	watchContainer(character)
end

player:WaitForChild("Backpack")
watchContainer(player.Backpack)
if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
