local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local function getLabel(): TextLabel?
	local mainGui = player:WaitForChild("PlayerGui"):FindFirstChild("Main")
	if not mainGui then
		return nil
	end
	local label = mainGui:FindFirstChild("PetBoost")
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

local function updateLabel(boostPercentage: number)
	local label = getLabel()
	if not label then
		return
	end
	if boostPercentage > 0 then
		label.Visible = true
		label.Text = `Pet Boost: +{boostPercentage}%`
	else
		label.Visible = false
	end
end

local updateRemote = remotes:WaitForChild("UpdatePetBoost", 60)
if updateRemote then
	updateRemote.OnClientEvent:Connect(updateLabel)
end

local initialBoost = player:GetAttribute("PetBoost")
if typeof(initialBoost) == "number" and initialBoost > 1 then
	updateLabel(math.floor((initialBoost - 1) * 100))
end

player:GetAttributeChangedSignal("PetBoost"):Connect(function()
	local boost = player:GetAttribute("PetBoost")
	if typeof(boost) == "number" then
		updateLabel(math.max(0, math.floor((boost - 1) * 100)))
	end
end)
