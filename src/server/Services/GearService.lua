--[[
	GearService — supply kiosk selling procedural consumable gear.

	Gear is defined in EconomyBalance.GEAR; tools are built entirely in
	code (InventoryService's procedural-gear branch), so no .rbxl assets
	are needed. The kiosk is one crate per gear item, each with its own
	buy prompt — feedback flows through the Notify toasts.

	Reposition by adding a Part named "GearKioskAnchor".
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

	if not moneyService.removeCash(player, config.price) then
		notify(player, ("You need $%d for %s."):format(config.price, gearName), "error")
		return
	end

	local entry = data.Inventory[gearName]
	if entry and entry.Count then
		entry.Count += 1
	else
		data.Inventory[gearName] = { Count = 1 }
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

	local counter = Instance.new("Part")
	counter.Name = "Counter"
	counter.Size = Vector3.new(6, 1, 3)
	counter.CFrame = baseCFrame * CFrame.new(0, 0.5, 0)
	counter.Material = Enum.Material.WoodPlanks
	counter.Color = Color3.fromRGB(124, 92, 60)
	counter.Anchored = true
	counter.Parent = model

	local index = 0
	local gearNames = {}
	for gearName in EconomyBalance.GEAR do
		table.insert(gearNames, gearName)
	end
	table.sort(gearNames, function(a, b)
		return EconomyBalance.GEAR[a].price < EconomyBalance.GEAR[b].price
	end)

	for _, gearName in gearNames do
		local config = EconomyBalance.GEAR[gearName]
		local crate = Instance.new("Part")
		crate.Name = gearName
		crate.Size = Vector3.new(1.6, 1.6, 1.6)
		crate.CFrame = baseCFrame * CFrame.new(-1.6 + index * 3.2, 1.8, 0)
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
		label.Text = ("%s\n$%d"):format(gearName, config.price)
		label.TextColor3 = Color3.fromRGB(235, 240, 250)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = billboard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = ("Buy — $%d"):format(config.price)
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
end

return Service
