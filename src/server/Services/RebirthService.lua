--[[
	RebirthService — permanent progression reset loop.

	Rebirthing costs cash (escalating per rebirth) and resets cash, seeds, and fruits — in
	exchange for a permanent sell-value multiplier (linear boostPerRebirth + one-time
	milestone bonuses at rebirth 5/10/25, see EconomyBalance.REBIRTH_MILESTONES) plus a
	cosmetic aura tier visible to other players (EconomyBalance.REBIRTH_AURA_TIERS).
	Plots, pets, and order history are all kept — only currency/inventory reset.

	The altar is procedural (stone pedestal + crystal beside the sell shop;
	reposition by adding a Part named "RebirthAltarAnchor"). Confirmation is
	two-step: trigger once to see the terms, trigger again within the
	window to rebirth.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyBalance = require(modules.EconomyBalance)
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local REBIRTH = EconomyBalance.REBIRTH
local CONFIRM_WINDOW = 12 -- seconds to confirm after the first trigger

local Service = {}

local pendingConfirm: { [Player]: number } = {}

local function notify(player: Player, message: string, kind: string?)
	local remote = remotes:FindFirstChild("Notify")
	if remote then
		remote:FireClient(player, message, kind or "info")
	end
end

function Service.getRebirthCost(rebirths: number): number
	return math.floor(REBIRTH.baseCost * REBIRTH.costMult ^ rebirths)
end

local function clearPlayerTools(player: Player)
	local containers = { player.Backpack, player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("isPet") ~= true then
					child:Destroy()
				end
			end
		end
	end
end

local function totalRebirthBoostPct(rebirths: number): number
	local linear = rebirths * REBIRTH.boostPerRebirth
	local milestone = EconomyBalance.getRebirthMilestoneBonus(rebirths)
	return math.floor((linear + milestone) * 100)
end

local function performRebirth(player: Player)
	local dataService = cachedModules.Cache.DataService
	local moneyService = cachedModules.Cache.MoneyService

	local data = dataService.getData(player)
	if not data then
		return
	end

	local cost = Service.getRebirthCost(data.Rebirths or 0)
	if data.Cash < cost then
		notify(player, ("You need $%d to rebirth."):format(cost), "error")
		return
	end

	-- Reset the run's currency/items only. PLOTS ARE KEPT — data.PlotData (currently growing
	-- crops) and data.PlotsOwned (unlocked beds) are deliberately left untouched, unlike the
	-- original version of this system. Losing all bed progress on every rebirth punished the
	-- exact high-earning players this system is meant to reward, turning the reset into a
	-- penalty instead of a genuine choice.
	data.Inventory = {}
	data.Cash = EconomyBalance.STARTING_CASH
	clearPlayerTools(player)

	local previousRebirths = data.Rebirths or 0

	-- Permanent gain
	data.Rebirths = previousRebirths + 1
	player:SetAttribute("Rebirths", data.Rebirths)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Rebirths") then
		leaderstats.Rebirths.Value = data.Rebirths
	end
	moneyService.updateCashCount(player)

	local rebirthLeaderboardService = cachedModules.Cache.RebirthLeaderboardService
	if rebirthLeaderboardService and rebirthLeaderboardService.reportRebirths then
		rebirthLeaderboardService.reportRebirths(player.UserId, player.Name, data.Rebirths)
	end

	Service.refreshAura(player)

	local totalBoostPct = totalRebirthBoostPct(data.Rebirths)
	local hitNewMilestone = false
	for _, milestone in EconomyBalance.REBIRTH_MILESTONES do
		if milestone.atRebirth == data.Rebirths then
			hitNewMilestone = true
		end
	end

	if hitNewMilestone then
		notify(player, ("🌟 Rebirth %d! MILESTONE REACHED — you now earn +%d%% on every sale, forever."):format(
			data.Rebirths, totalBoostPct), "success")
	else
		notify(player, ("🌟 Rebirth %d! You now earn +%d%% on every sale, forever."):format(
			data.Rebirths, totalBoostPct), "success")
	end

	-- Track rebirth achievement stat
	local achieveService = cachedModules.Cache.AchievementService
	if achieveService and achieveService.syncRebirths then
		achieveService.syncRebirths(player)
	end
end

--[[
	Cosmetic aura rig — a colored particle ring anchored to the character's HumanoidRootPart,
	visible to EVERY player (server-owned Attachment on a replicated character part, not a
	client-local effect), so a heavily-rebirthed player visibly stands out to others. Purely
	decorative: never touches PetBoost/FriendBoost/Cash or any other gameplay attribute.
]]
local AURA_ATTACHMENT_NAME = "RebirthAuraEffect"

local function buildAuraAttachment(color: Color3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = AURA_ATTACHMENT_NAME

	local ring = Instance.new("ParticleEmitter")
	ring.Name = "Ring"
	ring.Color = ColorSequence.new(color)
	ring.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	ring.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	ring.Lifetime = NumberRange.new(1.1, 1.6)
	ring.Speed = NumberRange.new(0.5, 1)
	ring.SpreadAngle = Vector2.new(180, 180)
	ring.Rate = 14
	ring.LightEmission = 0.9
	ring.Parent = attachment

	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = color
	light.Brightness = 0.8
	light.Range = 8
	light.Parent = attachment

	return attachment
end

local function applyAuraToCharacter(character: Model, rebirths: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local existing = root:FindFirstChild(AURA_ATTACHMENT_NAME)
	if existing then
		existing:Destroy()
	end

	local tier = EconomyBalance.getRebirthAuraTier(rebirths)
	if not tier then
		return -- rebirth 0: no aura, nothing to attach
	end

	buildAuraAttachment(tier.color).Parent = root
end

-- Re-applies the aura for the player's CURRENT character right now, and wires it to
-- re-apply automatically on every future respawn (auras don't persist across CharacterAdded
-- since the whole character, including HumanoidRootPart, is replaced on respawn).
function Service.refreshAura(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	local rebirths = (data and data.Rebirths) or 0

	if player.Character then
		applyAuraToCharacter(player.Character, rebirths)
	end

	if not player:GetAttribute("RebirthAuraHooked") then
		player:SetAttribute("RebirthAuraHooked", true)
		player.CharacterAdded:Connect(function(character)
			local currentData = dataService.getData(player)
			applyAuraToCharacter(character, (currentData and currentData.Rebirths) or 0)
		end)
	end
end

local function onAltarTriggered(player: Player)
	if not EconomyBalance.REBIRTH_ENABLED then
		notify(player, "Rebirth is currently disabled.", "info")
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data then
		return
	end

	local now = os.clock()
	local pending = pendingConfirm[player]

	if pending and now - pending <= CONFIRM_WINDOW then
		pendingConfirm[player] = nil
		performRebirth(player)
		return
	end

	pendingConfirm[player] = now
	local cost = Service.getRebirthCost(data.Rebirths or 0)
	local nextRebirths = (data.Rebirths or 0) + 1
	local nextBoostPct = totalRebirthBoostPct(nextRebirths)

	local extraNote = ""
	for _, milestone in EconomyBalance.REBIRTH_MILESTONES do
		if milestone.atRebirth == nextRebirths then
			extraNote = (" This hits a <b>milestone</b> for an extra one-time +%d%%!"):format(
				math.floor(milestone.bonusPct * 100))
		end
	end

	local currentAura = EconomyBalance.getRebirthAuraTier(data.Rebirths or 0)
	local nextAura = EconomyBalance.getRebirthAuraTier(nextRebirths)
	local auraNote = ""
	if nextAura and (not currentAura or currentAura.name ~= nextAura.name) then
		auraNote = (" You'll unlock the <b>%s Aura</b>!"):format(nextAura.name)
	end

	notify(player, ("Rebirth costs <b>$%d</b>: resets cash, seeds and fruits "
		.. "(plots and pets are kept!) for a permanent <b>+%d%%</b> sell boost.%s%s "
		.. "Use the altar again within %d seconds to confirm!"):format(
			cost, nextBoostPct, extraNote, auraNote, CONFIRM_WINDOW),
		"info")
end

local function buildAltar()
	if workspace:FindFirstChild("RebirthAltar") then
		return
	end

	local anchor = workspace:FindFirstChild("RebirthAltarAnchor", true)
	local baseCFrame
	if anchor and anchor:IsA("BasePart") then
		baseCFrame = anchor.CFrame
	else
		local shops = workspace:FindFirstChild("Shops")
		local sell = shops and shops:FindFirstChild("SellStuff")
		local pad = sell and sell:FindFirstChild("TPPart", true)
		if not (pad and pad:IsA("BasePart")) then
			warn("[RebirthService] No RebirthAltarAnchor or Shops.SellStuff.TPPart — altar not spawned.")
			return
		end
		baseCFrame = pad.CFrame * CFrame.new(-8, pad.Size.Y / 2, 0)
	end

	local model = Instance.new("Model")
	model.Name = "RebirthAltar"

	-- Tapered two-tier pedestal so the base doesn't dwarf the crystal
	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Size = Vector3.new(3.2, 0.9, 3.2)
	pedestal.CFrame = baseCFrame * CFrame.new(0, 0.45, 0)
	pedestal.Material = Enum.Material.Slate
	pedestal.Color = Color3.fromRGB(90, 94, 105)
	pedestal.Anchored = true
	pedestal.Parent = model

	local tier = Instance.new("Part")
	tier.Name = "PedestalTier"
	tier.Size = Vector3.new(2.2, 0.7, 2.2)
	tier.CFrame = baseCFrame * CFrame.new(0, 1.25, 0)
	tier.Material = Enum.Material.Slate
	tier.Color = Color3.fromRGB(104, 108, 120)
	tier.Anchored = true
	tier.Parent = model

	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Shape = Enum.PartType.Wedge
	crystal.Size = Vector3.new(1.4, 2.6, 1.4)
	crystal.CFrame = baseCFrame * CFrame.new(0, 2.9, 0) * CFrame.Angles(0, math.rad(35), 0)
	crystal.Material = Enum.Material.Neon
	crystal.Color = Color3.fromRGB(190, 140, 255)
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.Parent = model

	local light = Instance.new("PointLight")
	light.Color = crystal.Color
	light.Brightness = 1.2
	light.Range = 12
	light.Parent = crystal

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(crystal.Color)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	sparkle.Transparency = NumberSequence.new(0.35)
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(0.8, 1.6)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 6
	sparkle.LightEmission = 1
	sparkle.Parent = crystal

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 32)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = crystal

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
	label.BackgroundTransparency = 0.3
	label.Text = "🌟 Rebirth"
	label.TextColor3 = Color3.fromRGB(220, 190, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "Rebirth Altar"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pedestal

	prompt.Triggered:Connect(onAltarTriggered)

	model.Parent = workspace
end

-- Called once a player's data has loaded (mirrors the dataLoaded hook pattern used by
-- PlotService/AchievementService/etc.) so a returning player with existing Rebirths gets
-- their aura tier re-attached, not just newly-rebirthing players in this session.
function Service.dataLoaded(player: Player)
	if not EconomyBalance.REBIRTH_ENABLED then
		return
	end
	task.spawn(function()
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		Service.refreshAura(player)
	end)
end

function Service.init()
	-- If REBIRTH_ENABLED is ever flipped back to false, the altar is torn down (not just
	-- hidden) so there's no dangling UI/prompt to interact with; onAltarTriggered also fails
	-- closed as defense-in-depth in case an altar already exists in the saved place file.
	if EconomyBalance.REBIRTH_ENABLED then
		buildAltar()
	else
		local existingAltar = workspace:FindFirstChild("RebirthAltar")
		if existingAltar then
			existingAltar:Destroy()
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		pendingConfirm[player] = nil
	end)
end

return Service
