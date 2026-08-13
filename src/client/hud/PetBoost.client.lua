local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local function ensureLabel(): TextLabel?
	local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("Main")
	local existing = mainGui:FindFirstChild("PetBoost")
	if existing and existing:IsA("TextLabel") then
		return existing
	end

	local friendLabel = mainGui:FindFirstChild("FriendBoost")
	if not friendLabel or not friendLabel:IsA("TextLabel") then
		return nil
	end

	local label = friendLabel:Clone()
	label.Name = "PetBoost"
	label.Text = "Pet Boost: +0%"
	label.Visible = false
	label.Position = UDim2.new(
		friendLabel.Position.X.Scale,
		friendLabel.Position.X.Offset,
		friendLabel.Position.Y.Scale - 0.06,
		friendLabel.Position.Y.Offset
	)
	label.Parent = mainGui
	return label
end

local function updateLabel(cashPct: number, growthReductionPct: number?)
	local label = ensureLabel()
	if not label then
		return
	end

	local growPct = growthReductionPct
	if growPct == nil then
		local attr = player:GetAttribute("PetGrowthReduction")
		if typeof(attr) == "number" then
			growPct = attr
		else
			growPct = 0
		end
	end

	if cashPct > 0 or growPct > 0 then
		label.Visible = true
		local text = `Pet Boost: +{cashPct}%`
		if growPct > 0 then
			text ..= ` · -{growPct}% grow`
		end
		label.Text = text
	else
		label.Visible = false
	end
end

local updateRemote = remotes:WaitForChild("UpdatePetBoost", 60)
if updateRemote then
	updateRemote.OnClientEvent:Connect(function(cashPct: number, growthReductionPct: number?)
		updateLabel(cashPct, growthReductionPct)
	end)
end

local function syncFromAttribute()
	local boost = player:GetAttribute("PetBoost")
	local cashPct = 0
	if typeof(boost) == "number" then
		cashPct = math.max(0, math.floor((boost - 1) * 100))
	end
	updateLabel(cashPct)
end

syncFromAttribute()
player:GetAttributeChangedSignal("PetBoost"):Connect(syncFromAttribute)
player:GetAttributeChangedSignal("PetGrowthReduction"):Connect(syncFromAttribute)
