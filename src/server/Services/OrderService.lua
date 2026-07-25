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

-- Expected sell value of one fruit is
--   baseValue * E[weight^2] * E[mutation] * rarityAvg(tier)
-- The old formula used only E[weight^2] and a 1.7x "bonus", omitting the 2.43x mutation
-- expectation entirely — so orders paid ~5.1x baseValue while selling averaged ~7.85x,
-- making the "premium" order board strictly worse than bulk selling.
--
-- Now orders pay the full expected value with a deliberate discount: they are the reliable,
-- zero-variance floor, while selling stays the high-variance play where mutations pay off.
local ORDER_PAYOUT_RATIO = 0.85

-- Matches SeedShopService.getRandomFruitSize: w = a + b * r^2.2, E[r^k] = 1/(k+1)
local function expectedWeightSq(a: number, b: number): number
	return a * a + 2 * a * b * (1 / 3.2) + b * b * (1 / 5.4)
end

local E_W2_STANDARD = expectedWeightSq(1, 2) -- ~2.99
local E_W2_MANGO = expectedWeightSq(0.75, 1.1) -- ~1.30 (reduced roll, perennial)

-- MutationService: 1% Rainbow (x50), then 5% Golden (x20) of the remaining 99%
local E_MUTATION = 0.01 * 50 + (0.99 * 0.05) * 20 + (1 - 0.01 - 0.99 * 0.05) * 1

-- Average harvest-quality multiplier for a crop of the given tier.
local rarityAvgCache: { [string]: number } = {}
local function rarityAvgForTier(tier: string?): number
	if not tier then
		return 1
	end
	if rarityAvgCache[tier] then
		return rarityAvgCache[tier]
	end
	local bias = HarvestRarityConfig.CROP_BIAS[tier]
	if not bias then
		return 1
	end
	local sum, weight = 0, 0
	for quality, pct in bias do
		sum += pct * HarvestRarityConfig.getMultiplier(quality)
		weight += pct
	end
	local avg = if weight > 0 then sum / weight else 1
	rarityAvgCache[tier] = avg
	return avg
end

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
		-- Crops with no cash price are bought with another currency (Crystal Blooms uses
		-- Fish Coins). Skip them: `1000 / (0 + 25)` would make them the most common ask,
		-- and they are the hardest crop in the game to obtain.
		if (cfg.price or 0) > 0 then
			-- Cheaper crops appear more often; every crop stays possible.
			local weight = 1000 / (cfg.price + 25)
			totalWeight += weight
			table.insert(cropPool, {
				fruitName = seedName:gsub(" Seed$", ""),
				baseValue = cfg.baseValue,
				price = cfg.price,
				tier = cfg.rarity,
				-- Perennials use a reduced size roll, so their fruits are worth less each.
				expectedWeightSq = if cfg.multiHarvest then E_W2_MANGO else E_W2_STANDARD,
				weight = weight,
			})
		end
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

	-- Higher tiers ask for fewer fruits, since each one takes much longer to grow.
	-- Keyed on tier rather than price so re-pricing crops can't silently change ask sizes.
	local COUNT_BY_TIER = {
		Common = { 3, 5 },
		Uncommon = { 2, 4 },
		Rare = { 2, 3 },
		Epic = { 1, 3 },
		Legendary = { 1, 2 },
		Mythical = { 1, 2 },
	}
	local range = COUNT_BY_TIER[crop.tier] or { 1, 2 }
	local count = random:NextInteger(range[1], range[2])

	local perFruit = crop.baseValue
		* crop.expectedWeightSq
		* E_MUTATION
		* rarityAvgForTier(crop.tier)
	local reward = perFruit * count * ORDER_PAYOUT_RATIO * ask.rewardMult
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

	-- Track order-delivery achievement stat
	local achieveService = cachedModules.Cache.AchievementService
	if achieveService and achieveService.addOrderDelivered then
		achieveService.addOrderDelivered(player, 1)
	end

	-- Replace the completed slot immediately
	state.orders[orderIndex] = generateOrder()

	orderRemote:FireClient(player, "result", {
		success = true,
		msg = ('Delivered %dx %s for <font color="rgb(0,255,0)">$%d</font>!'):format(order.count, order.fruitName, paid),
	})
	pushState(player)
end

-- ------------------------------------------------------------ board build
-- The board is an editable Workspace model. If a Model named "OrderBoard"
-- already exists (placed/moved by hand in Studio), we respect its position
-- and only wire up behaviour. Otherwise we build one procedurally next to
-- the sell shop (or at an "OrderBoardAnchor" part) as a fallback.

local function findBoardPart(model: Model): BasePart?
	local named = model:FindFirstChild("Board")
	if named and named:IsA("BasePart") then
		return named
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function addBoardSurfaceGuis(boardPart: BasePart)
	if boardPart:FindFirstChildWhichIsA("SurfaceGui") then
		return
	end
	for _, faceEnum in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = faceEnum
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = boardPart

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
end

local function buildBoardModel(): Model?
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
			warn("[OrderService] No OrderBoard model, OrderBoardAnchor or Shops.SellStuff.TPPart — order board not spawned.")
			return nil
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

	model.PrimaryPart = board
	model.Parent = workspace
	return model
end

local function setupBoard()
	local board = workspace:FindFirstChild("OrderBoard", true)
	if not (board and board:IsA("Model")) then
		board = buildBoardModel()
	end
	if not board then
		return
	end

	local boardPart = findBoardPart(board)
	if not boardPart then
		warn("[OrderService] OrderBoard has no board part — cannot attach prompt.")
		return
	end
	if not board.PrimaryPart then
		board.PrimaryPart = boardPart
	end

	addBoardSurfaceGuis(boardPart)

	local prompt = board:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.ActionText = "View Orders"
		newPrompt.ObjectText = "Order Board"
		newPrompt.HoldDuration = 0
		newPrompt.MaxActivationDistance = 12
		newPrompt.RequiresLineOfSight = false
		newPrompt.Parent = boardPart
		prompt = newPrompt
	end

	prompt.Triggered:Connect(function(player)
		pushState(player)
		orderRemote:FireClient(player, "open")
	end)
end

-- --------------------------------------------------------------------- init
function Service.init()
	setupBoard()

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
