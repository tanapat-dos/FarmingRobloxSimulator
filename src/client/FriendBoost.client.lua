local Players = game:GetService("Players")
local player = Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local remotes = replicatedStorage:WaitForChild("RemoteEvents")

remotes.UpdateFriendBoost.OnClientEvent:Connect(function(boostPercentage)
	local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local friendBoostLabel = mainGui:WaitForChild("FriendBoost")

	if not friendBoostLabel.Visible then
		friendBoostLabel.Visible = true
	end

	friendBoostLabel.Text = `Friend Boost: +{boostPercentage}%`
end)
