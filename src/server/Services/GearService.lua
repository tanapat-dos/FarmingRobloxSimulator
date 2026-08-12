--[[
	GearService — sells procedural gear (Fertilizer, Mutation Spray, Pickaxe) through two
	entry points that share the same catalog and purchase logic:

	  1. A physical crate kiosk near the Seed Shop (buildKiosk) — walk up, hold E on a crate.
	  2. Maddy the Gear NPC's "OpenGearShop" prompt (GearShopClient.client.lua panel) — the
	     client reads EconomyBalance.GEAR directly (no catalog push needed, unlike the
	     seed/fish-coin shops with rolling stock) and fires the BuyGear remote below.

	Tools are built entirely in code (InventoryService's procedural-gear branch), so no .rbxl
	assets are needed. Feedback for both entry points flows through the Notify toasts.

	Reposition the crate kiosk by adding a Part named "GearKioskAnchor".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyBalance = require(modules.EconomyBalance)
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

local function notify(player: Player, message: string, kind: string?)
	local remote = remotes:FindFirstChild("Notify")
	if remote then
		remote:FireClient(player, message, kind or "info")
	end
end

local function buyGear(player: Player, gearName: string)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	local config = EconomyBalance.GEAR[gearName]
	if not config then
		return
	end

	local dataService = cachedModules.Cache.DataService
	local moneyService = cachedModules.Cache.MoneyService
	local inventoryService = cachedModules.Cache.InventoryService

	local data = dataService.getData(player)
	if not data then
		return
	end

	-- nonConsumable gear (e.g. Pickaxe): a flat one-time purchase, not a stacking charge
	-- count — block re-buying once already owned instead of letting Count climb pointlessly.
	if config.nonConsumable and data.Inventory[gearName] then
		notify(player, ("You already own a %s!"):format(gearName), "info")
		return
	end

	-- config.price is the floor only for consumables; the crop-scaled remainder is charged on
	-- use. nonConsumable gear has no remainder — price is the full, final cost.
	if not moneyService.removeCash(player, config.price) then
		notify(player, ("You need $%d for %s."):format(config.price, gearName), "error")
		return
	end

	if config.nonConsumable then
		data.Inventory[gearName] = { Count = 1 }
	else
		local entry = data.Inventory[gearName]
		if entry and entry.Count then
			entry.Count += 1
		else
			data.Inventory[gearName] = { Count = 1 }
		end
	end

	inventoryService.inventoryUpdated(player, gearName)
	notify(player, ("Bought 1x %s!"):format(gearName), "success")
end

local function buildKiosk()
	if workspace:FindFirstChild("GearKiosk") then
		return
	end

	local anchor = workspace:FindFirstChild("GearKioskAnchor", true)
	local baseCFrame
	if anchor and anchor:IsA("BasePart") then
		baseCFrame = anchor.CFrame
	else
		local shops = workspace:FindFirstChild("Shops")
		local seedShop = shops and shops:FindFirstChild("SeedShop")
		local pad = seedShop and seedShop:FindFirstChild("TPPart", true)
		if not (pad and pad:IsA("BasePart")) then
			warn("[GearService] No GearKioskAnchor or Shops.SeedShop.TPPart — kiosk not spawned.")
			return
		end
		baseCFrame = pad.CFrame * CFrame.new(8, pad.Size.Y / 2, 0)
	end

	local model = Instance.new("Model")
	model.Name = "GearKiosk"

	local gearNames = {}
	for gearName in EconomyBalance.GEAR do
		table.insert(gearNames, gearName)
	end
	table.sort(gearNames, function(a, b)
		return EconomyBalance.GEAR[a].price < EconomyBalance.GEAR[b].price
	end)

	-- Market-stall proportions: counter/awning width scales with crate count so the
	-- stall always fits however many gear items exist (was hardcoded for exactly 2).
	local CRATE_SIZE = 1.6
	local CRATE_SPACING = 2.5
	local COUNTER_MARGIN = 1.1 -- clearance beyond the outermost crate edges
	local numGear = math.max(#gearNames, 1)
	local counterWidth = (numGear - 1) * CRATE_SPACING + CRATE_SIZE + COUNTER_MARGIN
	local awningWidth = counterWidth + 0.6
	local postSideX = counterWidth / 2 - 0.3

	local counter = Instance.new("Part")
	counter.Name = "Counter"
	counter.Size = Vector3.new(counterWidth, 1, 2.4)
	counter.CFrame = baseCFrame * CFrame.new(0, 0.5, 0)
	counter.Material = Enum.Material.WoodPlanks
	counter.Color = Color3.fromRGB(124, 92, 60)
	counter.Anchored = true
	counter.Parent = model

	for _, sideX in { -postSideX, postSideX } do
		local awningPost = Instance.new("Part")
		awningPost.Name = "AwningPost"
		awningPost.Size = Vector3.new(0.4, 4.6, 0.4)
		awningPost.CFrame = baseCFrame * CFrame.new(sideX, 2.3, -0.9)
		awningPost.Material = Enum.Material.Wood
		awningPost.Color = Color3.fromRGB(105, 78, 52)
		awningPost.Anchored = true
		awningPost.Parent = model
	end

	local awning = Instance.new("Part")
	awning.Name = "Awning"
	awning.Size = Vector3.new(awningWidth, 0.25, 3.4)
	awning.CFrame = baseCFrame * CFrame.new(0, 4.75, 0.1) * CFrame.Angles(math.rad(-10), 0, 0)
	awning.Material = Enum.Material.Fabric
	awning.Color = Color3.fromRGB(178, 90, 74)
	awning.Anchored = true
	awning.CanCollide = false
	awning.Parent = model

	-- Crates are centered as a group instead of assuming exactly 2 (old: -1.25 + index*2.5).
	local index = 0
	local groupOffset = -((numGear - 1) * CRATE_SPACING) / 2

	for _, gearName in gearNames do
		local config = EconomyBalance.GEAR[gearName]
		local crate = Instance.new("Part")
		crate.Name = gearName
		crate.Size = Vector3.new(1.6, 1.6, 1.6)
		crate.CFrame = baseCFrame * CFrame.new(groupOffset + index * CRATE_SPACING, 1.8, 0)
		crate.Material = Enum.Material.Wood
		crate.Color = config.color or Color3.fromRGB(124, 92, 60)
		crate.Anchored = true
		crate.Parent = model

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(150, 40)
		billboard.StudsOffset = Vector3.new(0, 1.8, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 50
		billboard.Parent = crate

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
		label.BackgroundTransparency = 0.3
		-- nonConsumable gear (Pickaxe) has a flat, final price — no "from" wording since there
		-- is no crop-scaled remainder charged later, unlike Fertilizer/Mutation Spray.
		label.Text = config.nonConsumable
			and ("%s\n$%d"):format(gearName, config.price)
			or ("%s\nfrom $%d"):format(gearName, config.price)
		label.TextColor3 = Color3.fromRGB(235, 240, 250)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = billboard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = config.nonConsumable
			and ("Buy — $%d"):format(config.price)
			or ("Buy — from $%d"):format(config.price)
		prompt.ObjectText = gearName
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = crate

		prompt.Triggered:Connect(function(player)
			buyGear(player, gearName)
		end)

		index += 1
	end

	model.Parent = workspace
end

function Service.init()
	buildKiosk()

	-- Maddy the Gear NPC (Workspace.Shops.Characters.Gear, "OpenGearShop" prompt) opens
	-- GearShopClient.client.lua's panel; the panel reads EconomyBalance.GEAR directly (shared
	-- ReplicatedStorage module, no catalog push needed) and fires this remote to buy.
	local buyGearRemote = remotes:FindFirstChild("BuyGear")
	if buyGearRemote then
		buyGearRemote.OnServerEvent:Connect(function(player, gearName)
			if typeof(gearName) ~= "string" then
				return
			end
			buyGear(player, gearName)
		end)
	end
end

return Service
