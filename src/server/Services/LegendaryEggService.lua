--!strict
--[[
	LegendaryEggService — premium (Diamond-only) egg stand.

	The Legendary tier egg (Divine Egg) is bought with Diamonds only, so it
	lives on its own stand instead of the cash pet shop. This service builds
	an editable stand in the Workspace (respecting a hand-placed model), opens
	the client panel on prompt, and delegates the actual roll to PetService so
	the pet-grant / roll animation stays identical to the cash eggs.

	Remote protocol (RemoteEvent "LegendaryEgg"):
	  server -> client: ("open")            show the diamond egg panel
	  client -> server: ("roll")            roll the Legendary egg for Diamonds
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyBalance = require(ReplicatedStorage:WaitForChild("Modules").EconomyBalance)
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local LEGENDARY_EGG = "Divine Egg"

local Service = {}

local function ensureRemote(name: string): RemoteEvent
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote :: RemoteEvent
end

local legendaryRemote = ensureRemote("LegendaryEgg")

-- --------------------------------------------------------------- stand build
local function findStandPart(model: Model): BasePart?
	local named = model:FindFirstChild("Egg")
	if named and named:IsA("BasePart") then
		return named
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function buildStandModel(): Model?
	local anchor = workspace:FindFirstChild("LegendaryEggAnchor", true)
	local baseCFrame
	if anchor and anchor:IsA("BasePart") then
		baseCFrame = anchor.CFrame
	else
		local shops = workspace:FindFirstChild("Shops")
		local sell = shops and shops:FindFirstChild("SellStuff")
		local pad = sell and sell:FindFirstChild("TPPart", true)
		if not (pad and pad:IsA("BasePart")) then
			warn("[LegendaryEggService] No LegendaryEggStand model, LegendaryEggAnchor or Shops.SellStuff.TPPart — stand not spawned.")
			return nil
		end
		baseCFrame = pad.CFrame * CFrame.new(16, pad.Size.Y / 2, 0)
	end

	local model = Instance.new("Model")
	model.Name = "LegendaryEggStand"

	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.Size = Vector3.new(3, 4, 4)
	pedestal.CFrame = baseCFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Material = Enum.Material.Marble
	pedestal.Color = Color3.fromRGB(60, 66, 92)
	pedestal.Anchored = true
	pedestal.Parent = model

	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(3, 3.8, 3)
	egg.CFrame = baseCFrame * CFrame.new(0, 5.4, 0)
	egg.Material = Enum.Material.Neon
	egg.Color = Color3.fromRGB(150, 120, 255)
	egg.Anchored = true
	egg.CanCollide = false
	egg.Parent = model
	model.PrimaryPart = egg

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 150, 255)
	light.Brightness = 3
	light.Range = 14
	light.Parent = egg

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(220, 64)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Parent = egg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Text = "✨ LEGENDARY EGG"
	title.TextColor3 = Color3.fromRGB(230, 210, 255)
	title.TextStrokeTransparency = 0.4
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = billboard

	local price = Instance.new("TextLabel")
	price.Position = UDim2.fromScale(0, 0.55)
	price.Size = UDim2.fromScale(1, 0.45)
	price.BackgroundTransparency = 1
	price.Text = ("💎 %d per roll"):format(EconomyBalance.EGGS[LEGENDARY_EGG].diamondCost or 0)
	price.TextColor3 = Color3.fromRGB(150, 220, 255)
	price.Font = Enum.Font.GothamBold
	price.TextScaled = true
	price.Parent = billboard

	model.Parent = workspace
	return model
end

local function setupStand()
	local stand = workspace:FindFirstChild("LegendaryEggStand", true)
	if not (stand and stand:IsA("Model")) then
		stand = buildStandModel()
	end
	if not stand then
		return
	end

	local part = findStandPart(stand)
	if not part then
		warn("[LegendaryEggService] LegendaryEggStand has no part — cannot attach prompt.")
		return
	end
	if not stand.PrimaryPart then
		stand.PrimaryPart = part
	end

	-- Add billboard sign if not already present
	if not stand:FindFirstChildWhichIsA("BillboardGui", true) then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Sign"
		billboard.Size = UDim2.fromOffset(220, 64)
		billboard.StudsOffset = Vector3.new(0, 4.2, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 80
		billboard.Parent = part

		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 0.55)
		title.BackgroundTransparency = 1
		title.Text = "✨ LEGENDARY EGG"
		title.TextColor3 = Color3.fromRGB(230, 210, 255)
		title.TextStrokeTransparency = 0.4
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.Parent = billboard

		local price = Instance.new("TextLabel")
		price.Position = UDim2.fromScale(0, 0.55)
		price.Size = UDim2.fromScale(1, 0.45)
		price.BackgroundTransparency = 1
		price.Text = ("💎 %d per roll"):format(EconomyBalance.EGGS[LEGENDARY_EGG].diamondCost or 0)
		price.TextColor3 = Color3.fromRGB(150, 220, 255)
		price.Font = Enum.Font.GothamBold
		price.TextScaled = true
		price.Parent = billboard
	end

	local prompt = stand:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.ActionText = "Legendary Egg"
		newPrompt.ObjectText = "Diamond Shop"
		newPrompt.HoldDuration = 0
		newPrompt.MaxActivationDistance = 14
		newPrompt.RequiresLineOfSight = false
		newPrompt.Parent = part
		prompt = newPrompt
	end

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		legendaryRemote:FireClient(player, "open")
	end)
end

-- --------------------------------------------------------------------- init
function Service.init()
	setupStand()

	legendaryRemote.OnServerEvent:Connect(function(player, action)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if action == "roll" then
			local petService = cachedModules.Cache.PetService
			if petService and petService.rollEgg then
				petService.rollEgg(player, LEGENDARY_EGG)
			end
		end
	end)
end

return Service
