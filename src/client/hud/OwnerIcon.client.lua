local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local M_D = 10 -- Avatar invisible when closer than this (in studs)

local function updateAvatarVisibility()
	local character = localPlayer.Character
	if not character or not character.PrimaryPart then
		return
	end

	local playerPosition = character.PrimaryPart.Position

	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local ownerTag = plot:FindFirstChild("Owner_Tag")
		if ownerTag and ownerTag:IsDescendantOf(workspace) then
			local billboardGui = ownerTag:FindFirstChild("AvatarGui")
			if billboardGui and billboardGui:IsA("BillboardGui") then
				local imageLabel = billboardGui:FindFirstChildOfClass("ImageLabel")

				if imageLabel 
					and imageLabel:IsDescendantOf(workspace) 
					and imageLabel.Image ~= "" 
					and imageLabel.ImageTransparency < 1 
				then
					local distance = (playerPosition - ownerTag.Position).Magnitude
					billboardGui.Enabled = distance >= M_D
				else
					billboardGui.Enabled = false
				end
			end
		end
	end
end


-- 5 Hz is visually indistinguishable for a show/hide-at-distance check and
-- avoids walking every plot's children each rendered frame.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator >= 0.2 then
		accumulator = 0
		updateAvatarVisibility()
	end
end)
