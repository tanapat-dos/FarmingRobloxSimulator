--!strict
--[[
	MiningClient — purely cosmetic pickaxe swing. Plays a quick tween on the equipped
	Pickaxe's Grip whenever the player triggers an ore node's "Mine" ProximityPrompt.

	No server communication here at all: ProximityPromptService.PromptTriggered already fires
	the server-side Triggered connection built in MiningService independently (that's how
	Roblox ProximityPrompts replicate), so this script only has to react locally to make the
	swing feel immediate instead of waiting on a round trip. The reward, node state, and
	respawn timing are 100% server-decided — this never sends or trusts any payload.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local MiningConfig = require(ReplicatedStorage:WaitForChild("Modules").MiningConfig)

local player = Players.LocalPlayer

local isSwinging = false

local function getEquippedPickaxe(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildWhichIsA("Tool")
	if tool and tool.Name == MiningConfig.PICKAXE_NAME then
		return tool
	end
	return nil
end

local function playSwing()
	if isSwinging then
		return
	end
	local tool = getEquippedPickaxe()
	if not tool then
		return
	end

	isSwinging = true
	local baseGrip = tool.Grip
	local swingGrip = baseGrip * CFrame.Angles(math.rad(-35), 0, 0)

	local half = MiningConfig.SWING_DURATION / 2
	local outTween = TweenService:Create(tool, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Grip = swingGrip })
	local backTween = TweenService:Create(tool, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Grip = baseGrip })

	outTween:Play()
	outTween.Completed:Once(function()
		backTween:Play()
	end)
	backTween.Completed:Once(function()
		isSwinging = false
	end)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player then
		return
	end
	if prompt.Name ~= MiningConfig.MINE_PROMPT_NAME then
		return
	end
	playSwing()
end)
