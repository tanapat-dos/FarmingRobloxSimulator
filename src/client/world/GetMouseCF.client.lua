local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local remotes = replicatedStorage:WaitForChild("RemoteEvents")

local player = players.LocalPlayer
local mouse = player:GetMouse()

remotes.GetMouseCF.OnClientInvoke = function()
	return mouse.Hit
end
