--[[
	OrderService — NPC order board.

	Each player gets ORDER_SLOTS rotating orders ("Deliver 3x Tomato,
	Uncommon or better") paying a premium over expected sell value.
	Delivering consumes matching fruits from the inventory (lowest weight
	first, so players keep their giants) and pays through MoneyService
	(friend/pet boosts apply, same as selling).

	The physical board is built procedurally next to the sell shop —
	no .rbxl asset required. To reposition it, add a Part named
	"OrderBoardAnchor" anywhere in workspace and re-join.

	Remote protocol (RemoteEvent "OrderBoard"):
	  server -> client: ("state", { orders, completed })   full refresh
	  server -> client: ("open")                            show the panel
	  server -> client: ("result", { success, msg })        deliver feedback
	  client -> server: ("deliver", orderId)
	  client -> server: ("refreshRequest")                  pull current state
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local modules = ReplicatedStorage:WaitForChild("Modules")

local EconomyBalance = require(modules.EconomyBalance)
local HarvestRarityConfig = require(modules.HarvestRarityConfig)
local fruitNameParser = require(modules.FruitNameParse)
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

local random = Random.new()

local ORDER_SLOTS = 3
local REFRESH_SECONDS = 300 -- full board refresh cadence per player
-- Expected fruit value ~= baseValue * E[weight^2] (~3 with the current
-- size roll); the bonus makes orders clearly better than bulk selling.
local EXPECTED_WEIGHT_SQ = 3
local ORDER_BONUS = 1.7

local RARITY_ASKS = {
	{ minRarity = nil, weight = 60, rewardMult = 1 },
	{ minRarity = "Uncommon", weight = 30, rewardMult = 1.3 },
	{ minRarity = "Rare", weight = 10, rewardMult = 1.8 },
}

-- sessionState[player] = { orders = {order...}, refreshAt = os.time() }
local sessionState: { [Player]: any } = {}

local function ensureRemote(name: string): RemoteEvent
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local orderRemote = ensureRemote("OrderBoard")

local function tierIndex(rarity: string?): number
	return table.find(HarvestRarityConfig.TIERS, rarity or "Common") or 1
end

-- ------------------------------------------------------------- generation
local cropPool = nil
local function getCropPool()
	if cropPool then
		return cropPool
	end
	cropPool = {}
	local totalWeight = 0
	for seedName, cfg in EconomyBalance.CROPS do
		-- Cheaper crops appear more often; every crop stays possible.
		local weight = 1000 / (cfg.price + 25)
		totalWeight += weight
		table.insert(cropPool, {
			fruitName = seedName:gsub(" Seed$", ""),
			baseValue = cfg.baseValue,
			price = cfg.price,
			weight = weight,
		})
	end
	cropPool.totalWeight = totalWeight
	return cropPool
end

local function pickWeighted(pool, totalWeight: number)
	local roll = random:NextNumber(0, totalWeight)
	for _, entry in ipairs(pool) do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return pool[#pool]
end

local function generateOrder()
	local pool = getCropPool()
	local crop = pickWeighted(pool, pool.totalWeight)

	local ask = pickWeighted(RARITY_ASKS, 100)
	-- Pricey crops ask for fewer fruits
	local count
	if crop.price <= 40 then
		count = random:NextInteger(3, 5)
	elseif crop.price <= 130 then
		count = random:NextInteger(2, 4)
	else
		count = random:NextInteger(1, 2)
	end

	local reward = crop.baseValue * EXPECTED_WEIGHT_SQ * count * ORDER_BONUS * ask.rewardMult
	reward = math.ceil(reward / 5) * 5

	return {
		id = string.sub(HttpService:GenerateGUID(false), 1, 8),
		fruitName = crop.fruitName,
		count = count,
		minRarity = ask.minRarity,
		reward = reward,
	}
end

local function generateBoard()
	local orders = {}
	local usedFruits = {}
	for _ = 1, ORDER_SLOTS do
		local order = generateOrder()
		-- avoid duplicate crops on one board (best effort)
		for _ = 1, 5 do
			if not usedFruits[order.fruitName] then
				break
			end
			order = generateOrder()
		end
		usedFruits[order.fruitName] = true
		table.insert(orders, order)
	end
	return orders
end

-- ------------------------------------------------------------ state/remote
local function countMatchingFruits(player: Player, order): number
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	if not data then
		return 0
	end

	local needTier = tierIndex(order.minRarity)
	local have = 0
	for _, value in data.Inventory do
		if typeof(value) == "string" then
			local rarity, _, weight, name = fruitNameParser(value)
			if name == order.fruitName and weight > 0 and tierIndex(rarity) >= needTier then
				have += 1
			end
		end
	end
	return have
end

local function getState(player: Player)
	local state = sessionState[player]
	if not state then
		state = { orders = generateBoard(), refreshAt = os.time() + REFRESH_SECONDS }
		sessionState[player] = state
	end
	return state
end

local function pushState(player: Player)
	local state = getState(player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService.getData(player)
	local completed = data and data.OrderStats and data.OrderStats.Completed or 0

	local payload = {}
	for _, order in state.orders do
		table.insert(payload, {
			id = order.id,
			fruitName = order.fruitName,
			count = order.count,
			minRarity = order.minRarity,
			reward = order.reward,
			have = countMatchingFruits(player, order),
		})
	end

	orderRemote:FireClient(player, "state", {
		orders = payload,
		completed = completed,
		refreshIn = math.max(0, state.refreshAt - os.time()),
	})
end

-- ----------------------------------------------------------------- deliver
local function deliver(player: Player, orderId: string)
	if typeof(orderId) ~= "string" then
		return
	end
	if player:FindFirstChild("OrderDebounce") then
		return
	end
	local db = Instance.new("Folder")
	db.Name = "OrderDebounce"
	db.Parent = player
	Debris:AddItem(db, 0.5)

	local dataService = cachedModules.Cache.DataService
	local inventoryService = cachedModules.Cache.InventoryService
	local moneyService = cachedModules.Cache.MoneyService

	local data = dataService.getData(player)
	if not data then
		return
	end

	local state = getState(player)
	local orderIndex, order
	for index, candidate in state.orders do
		if candidate.id == orderId then
			orderIndex, order = index, candidate
			break
		end
	end
	if not order then
		orderRemote:FireClient(player, "result", { success = false, msg = "That order has expired." })
		pushState(player)
		return
	end

	-- Collect matching fruits, cheapest (lightest) first
	local needTier = tierIndex(order.minRarity)
	local matching = {}
	for key, value in data.Inventory do
		if typeof(value) == "string" then
			local rarity, _, weight, name = fruitNameParser(value)
			if name == order.fruitName and weight > 0 and tierIndex(rarity) >= needTier then
				table.insert(matching, { key = key, weight = weight })
			end
		end
	end

	if #matching < order.count then
		local rarityNote = order.minRarity and (" (" .. order.minRarity .. "+)") or ""
		orderRemote:FireClient(player, "result", {
			success = false,
			msg = ("You need %d more %s%s."):format(order.count - #matching, order.fruitName, rarityNote),
		})
		return
	end

	table.sort(matching, function(a, b)
		return a.weight < b.weight
	end)

	for i = 1, order.count do
		inventoryService.removeItem(player, matching[i].key, 1)
	end

	local paid = moneyService.giveMoney(player, order.reward)

	if not data.OrderStats then
		data.OrderStats = { Completed = 0 }
	end
	data.OrderStats.Completed += 1

	-- Replace the completed slot immediately
	state.orders[orderIndex] = generateOrder()

	orderRemote:FireClient(player, "result", {
		success = true,
		msg = ('Delivered %dx %s for <font color="rgb(0,255,0)">$%d</font>!'):format(order.count, order.fruitName, paid),
	})
	pushState(player)
end

-- ------------------------------------------------------------ board build
local function buildBoard()
	if workspace:FindFirstChild("OrderBoard") then
		return
	end

	-- Placement: explicit anchor wins, else beside the sell shop pad
	local anchor = workspace:FindFirstChild("OrderBoardAnchor", true)
	local baseCFrame
	if anchor and anchor:IsA("BasePart") then
		baseCFrame = anchor.CFrame
	else
		local shops = workspace:FindFirstChild("Shops")
		local sell = shops and shops:FindFirstChild("SellStuff")
		local pad = sell and sell:FindFirstChild("TPPart", true)
		if not (pad and pad:IsA("BasePart")) then
			warn("[OrderService] No OrderBoardAnchor or Shops.SellStuff.TPPart — order board not spawned.")
			return
		end
		baseCFrame = pad.CFrame * CFrame.new(8, pad.Size.Y / 2, 0)
	end

	local model = Instance.new("Model")
	model.Name = "OrderBoard"

	-- Proportions: posts sit OUTSIDE the plank (post inner face flush with
	-- the board edge), plus a cap rail — reads as a built notice board
	-- instead of a floating plank.
	local boardWidth = 5.2
	local postSize = 0.6
	local postX = boardWidth / 2 + postSize / 2

	local function post(offsetX: number)
		local part = Instance.new("Part")
		part.Name = "Post"
		part.Size = Vector3.new(postSize, 5.6, postSize)
		part.CFrame = baseCFrame * CFrame.new(offsetX, 2.8, 0)
		part.Material = Enum.Material.Wood
		part.Color = Color3.fromRGB(105, 78, 52)
		part.Anchored = true
		part.Parent = model
		return part
	end
	post(-postX)
	post(postX)

	local board = Instance.new("Part")
	board.Name = "Board"
	board.Size = Vector3.new(boardWidth, 3.2, 0.4)
	board.CFrame = baseCFrame * CFrame.new(0, 4, 0)
	board.Material = Enum.Material.WoodPlanks
	board.Color = Color3.fromRGB(124, 92, 60)
	board.Anchored = true
	board.Parent = model

	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = Vector3.new(boardWidth + postSize * 2 + 0.4, 0.35, 0.9)
	cap.CFrame = baseCFrame * CFrame.new(0, 5.78, 0)
	cap.Material = Enum.Material.Wood
	cap.Color = Color3.fromRGB(96, 70, 46)
	cap.Anchored = true
	cap.Parent = model

	for _, faceEnum in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = faceEnum
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board

		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 0.45)
		title.BackgroundTransparency = 1
		title.Text = "📋 ORDERS"
		title.TextColor3 = Color3.fromRGB(255, 240, 200)
		title.TextStrokeTransparency = 0.4
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.Parent = gui

		local subtitle = Instance.new("TextLabel")
		subtitle.Position = UDim2.fromScale(0, 0.5)
		subtitle.Size = UDim2.fromScale(1, 0.3)
		subtitle.BackgroundTransparency = 1
		subtitle.Text = "Deliver crops, earn a premium!"
		subtitle.TextColor3 = Color3.fromRGB(235, 240, 250)
		subtitle.Font = Enum.Font.Gotham
		subtitle.TextScaled = true
		subtitle.Parent = gui
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "View Orders"
	prompt.ObjectText = "Order Board"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = board

	prompt.Triggered:Connect(function(player)
		pushState(player)
		orderRemote:FireClient(player, "open")
	end)

	model.Parent = workspace
end

-- --------------------------------------------------------------------- init
function Service.init()
	buildBoard()

	orderRemote.OnServerEvent:Connect(function(player, action, payload)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if action == "deliver" then
			deliver(player, payload)
		elseif action == "refreshRequest" then
			pushState(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessionState[player] = nil
	end)

	-- Rotate boards on the refresh cadence
	task.spawn(function()
		while true do
			task.wait(15)
			for player, state in sessionState do
				if os.time() >= state.refreshAt then
					state.orders = generateBoard()
					state.refreshAt = os.time() + REFRESH_SECONDS
					if player.Parent then
						pushState(player)
					end
				end
			end
		end
	end)
end

return Service
