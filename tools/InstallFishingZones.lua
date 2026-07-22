--[[
	Optional: bake fishing-stand attributes into the place (Edit mode).
	Runtime: server auto-registers via FishingStandRegistry.ensureRegistered().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local oldZones = workspace:FindFirstChild("FishingZones")
if oldZones then
	oldZones:Destroy()
	print("[InstallFishingZones] Removed legacy Workspace.FishingZones volumes.")
end

workspace:SetAttribute("FishingStandsRegistered", nil)

local registry = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FishingStandRegistry"))
registry.ensureRegistered()

print("[InstallFishingZones] Done — save the place (Ctrl+S).")
