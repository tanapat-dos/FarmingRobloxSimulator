--[[
	RebirthService — permanent progression reset loop.

	Rebirthing costs cash (escalating per rebirth) and resets cash, seeds,
	fruits, crops, and plots — in exchange for a permanent sell-value
	multiplier (EconomyBalance.REBIRTH.boostPerRebirth per rebirth).
	Pets and order history are kept.

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

local function performRebirth(player: Player)
	local dataService = cachedModules.Cache.DataService
	local moneyService = cachedModules.Cache.MoneyService
	local plotService = cachedModules.Cache.PlotService

	local data = dataService.getData(player)
	if not data then
		return
	end

	local cost = Service.getRebirthCost(data.Rebirths or 0)
	if data.Cash < cost then
		notify(player, ("You need $%d to rebirth."):format(cost), "error")
		return
	end

	-- Wipe the run
	for _, plant in workspace.World.Map.PlantedSeeds.Server:GetChildren() do
		if plant:GetAttribute("Owner") == player.UserId then
			plant:Destroy()
		end
	end
	data.PlotData = {}
	data.Inventory = {}
	data.PlotsOwned = EconomyBalance.PLOTS.startOwned
	data.Cash = EconomyBalance.STARTING_CASH
	clearPlayerTools(player)

	-- Permanent gain
	data.Rebirths = (data.Rebirths or 0) + 1
	player:SetAttribute("Rebirths", data.Rebirths)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Rebirths") then
		leaderstats.Rebirths.Value = data.Rebirths
	end
	moneyService.updateCashCount(player)

	local plot = plotService.getPlot(player)
	if plot then
		plotService.setupBeds(player, plot)
	end

	local totalBoost = math.floor(data.Rebirths * REBIRTH.boostPerRebirth * 100)
	notify(player, ("🌟 Rebirth %d! You now earn +%d%% on every sale, forever."):format(
		data.Rebirths, totalBoost), "success")

	-- Track rebirth achievement stat
	local achieveService = cachedModules.Cache.AchievementService
	if achieveService and achieveService.syncRebirths then
		achieveService.syncRebirths(player)
	end
end

local function onAltarTriggered(player: Player)
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
	local nextBoost = math.floor((data.Rebirths + 1) * REBIRTH.boostPerRebirth * 100)
	notify(player, ("Rebirth costs <b>$%d</b>: resets cash, seeds, fruits, crops and plots "
		.. "(pets are kept) for a permanent <b>+%d%%</b> sell boost. "
		.. "Use the altar again within %d seconds to confirm!"):format(cost, nextBoost, CONFIRM_WINDOW),
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

function Service.init()
	buildAltar()

	Players.PlayerRemoving:Connect(function(player)
		pendingConfirm[player] = nil
	end)
end

return Service
