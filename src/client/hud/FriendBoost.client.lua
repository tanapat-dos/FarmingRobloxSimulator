local Players = game:GetService("Players")
local player = Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local remotes = replicatedStorage:WaitForChild("RemoteEvents")

local function updateFriendBoostLabel(boostPercentage: number)
	local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local friendBoostLabel = mainGui:WaitForChild("FriendBoost")

	friendBoostLabel.Visible = true
	friendBoostLabel.Text = `Friend Boost: +{boostPercentage}%`
end

remotes.UpdateFriendBoost.OnClientEvent:Connect(updateFriendBoostLabel)

local initialBoost = player:GetAttribute("FriendBoost")
if typeof(initialBoost) == "number" and initialBoost >= 1 then
	updateFriendBoostLabel(math.max(0, math.floor((initialBoost - 1) * 100)))
end

player:GetAttributeChangedSignal("FriendBoost"):Connect(function()
	local boost = player:GetAttribute("FriendBoost")
	if typeof(boost) == "number" then
		updateFriendBoostLabel(math.max(0, math.floor((boost - 1) * 100)))
	end
end)
