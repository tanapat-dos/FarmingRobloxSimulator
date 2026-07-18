--!strict
--[[
	GardenUpgradeService — server-authoritative "Upgrade Board".

	Sells two permanent garden upgrades:
	  • Extra Plots   — unlocks the next soil bed (delegates to PlotService).
	                    Each level shows the max crops the player can grow.
	  • Growth Speed  — leveled % reduction on crop grow time (stacks with pets).

	One board is attached to each player's farm (next to the name sign) when
	their data loads, and only the farm owner can open it. The client
	(GardenUpgradeClient) renders a big icon panel and sends buy requests;
	all validation (cash, level caps, ownership) happens here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local EconomyBalance = require(ReplicatedStorage:WaitForChild("Modules").EconomyBalance)

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local PLOTS = EconomyBalance.PLOTS

-- Board sits relative to the plot's PlayerSign.Main (same facing as the sign).
-- Tweak this offset to nudge the board around the farm.
local BOARD_OFFSET = CFrame.new(0, 0, 11)

local Service = {}

local playerBoards: { [Player]: Model } = {}

local function ensureRemote(name: string): RemoteEvent
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	return remote :: RemoteEvent
end

local upgradeRemote = ensureRemote("GardenUpgrade")

-- ------------------------------------------------------------- growth state
-- Apply the saved growth-upgrade level as a replicated attribute the growth
-- tick (PlotService) and countdown UI (CropReplicator) both read.
local function applyGrowthReduction(player: Player)
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	local level = (data and data.GrowthUpgradeLevel) or 0
	player:SetAttribute("UpgradeGrowthReduction", EconomyBalance.getGrowthUpgradePct(level))
end

-- --------------------------------------------------------------- board state
local function buildState(player: Player)
	local dataService = cachedModules.Cache.DataService
	local plotService = cachedModules.Cache.PlotService
	local data = dataService.getData(player)

	local owned = plotService.getOwnedBedCount(player)
	local plotMaxed = owned >= PLOTS.maxOwned
	local nextPlotIndex = owned + 1

	local growthLevel = (data and data.GrowthUpgradeLevel) or 0
	local growthMax = EconomyBalance.getGrowthUpgradeMaxLevel()
	local growthMaxed = growthLevel >= growthMax

	return {
		cash = data and data.Cash or 0,
		plots = {
			level = owned,
			maxLevel = PLOTS.maxOwned,
			cropsPerPlot = PLOTS.cropsPerPlot,
			currentCrops = owned * PLOTS.cropsPerPlot,
			nextCrops = plotMaxed and nil or (nextPlotIndex * PLOTS.cropsPerPlot),
			nextPrice = plotMaxed and nil or PLOTS.prices[nextPlotIndex],
			maxed = plotMaxed,
		},
		growth = {
			level = growthLevel,
			maxLevel = growthMax,
			currentPct = EconomyBalance.getGrowthUpgradePct(growthLevel),
			nextPct = growthMaxed and nil or EconomyBalance.getGrowthUpgradePct(growthLevel + 1),
			nextPrice = growthMaxed and nil or EconomyBalance.getGrowthUpgradePrice(growthLevel + 1),
			maxed = growthMaxed,
		},
	}
end

local function pushState(player: Player)
	if player.Parent then
		upgradeRemote:FireClient(player, "state", buildState(player))
	end
end

-- ----------------------------------------------------------------- purchases
local function buyGrowth(player: Player): (boolean, string)
	local dataService = cachedModules.Cache.DataService
	local moneyService = cachedModules.Cache.MoneyService

	local data = dataService.getData(player)
	if not data then
		return false, "Your data isn't loaded yet."
	end

	local level = data.GrowthUpgradeLevel or 0
	if level >= EconomyBalance.getGrowthUpgradeMaxLevel() then
		return false, "Growth Speed is already maxed!"
	end

	local nextLevel = level + 1
	local price = EconomyBalance.getGrowthUpgradePrice(nextLevel)
	if typeof(price) ~= "number" or price <= 0 then
		return false, "This upgrade can't be purchased."
	end

	if not moneyService.removeCash(player, price) then
		return false, ("You need $%d for this upgrade."):format(price)
	end

	data.GrowthUpgradeLevel = nextLevel
	applyGrowthReduction(player)

	return true, ("Growth Speed Lv.%d — crops now grow %d%% faster!"):format(
		nextLevel, EconomyBalance.getGrowthUpgradePct(nextLevel))
end

local function handlePurchase(player: Player, action: string)
	if player:FindFirstChild("UpgradeDebounce") then
		return
	end
	local db = Instance.new("Folder")
	db.Name = "UpgradeDebounce"
	db.Parent = player
	Debris:AddItem(db, 0.4)

	local plotService = cachedModules.Cache.PlotService

	local success, message
	if action == "buyPlot" then
		success, message = plotService.buyPlotUpgrade(player)
	elseif action == "buyGrowth" then
		success, message = buyGrowth(player)
	else
		return
	end

	upgradeRemote:FireClient(player, "result", { success = success, msg = message })
	pushState(player)
end

-- --------------------------------------------------------------- board build
-- Big, readable board mounted at each farm beside the name sign.

local function addBoardSurfaceGui(boardPart: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Left -- matches the name sign's readable face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 45
	gui.Parent = boardPart

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromScale(0.05, 0.06)
	title.Size = UDim2.fromScale(0.9, 0.28)
	title.BackgroundTransparency = 1
	title.Text = "GARDEN UPGRADES"
	title.TextColor3 = Color3.fromRGB(235, 255, 215)
	title.TextStrokeTransparency = 0.35
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = gui

	local icons = Instance.new("TextLabel")
	icons.Name = "Icons"
	icons.Position = UDim2.fromScale(0.05, 0.36)
	icons.Size = UDim2.fromScale(0.9, 0.38)
	icons.BackgroundTransparency = 1
	icons.Text = "🌱      ⏳"
	icons.TextColor3 = Color3.fromRGB(255, 255, 255)
	icons.Font = Enum.Font.GothamBold
	icons.TextScaled = true
	icons.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.Position = UDim2.fromScale(0.05, 0.76)
	sub.Size = UDim2.fromScale(0.9, 0.18)
	sub.BackgroundTransparency = 1
	sub.Text = "More Plots  •  Faster Growth"
	sub.TextColor3 = Color3.fromRGB(225, 235, 245)
	sub.Font = Enum.Font.GothamMedium
	sub.TextScaled = true
	sub.Parent = gui
end

local function buildPlotBoard(plot: Model): Model?
	local sign = plot:FindFirstChild("PlayerSign")
	local main = sign and sign:FindFirstChild("Main")
	if not (main and main:IsA("BasePart")) then
		warn("[GardenUpgradeService] Plot", plot.Name, "has no PlayerSign.Main — board not built.")
		return nil
	end

	local base = main.CFrame * BOARD_OFFSET

	local model = Instance.new("Model")
	model.Name = "UpgradeBoard"

	-- Wooden backing/frame (sits just behind the readable face).
	local frame = Instance.new("Part")
	frame.Name = "Frame"
	frame.Size = Vector3.new(0.35, 5.8, 8.8)
	frame.CFrame = base * CFrame.new(0.12, 0, 0)
	frame.Material = Enum.Material.Wood
	frame.Color = Color3.fromRGB(70, 52, 36)
	frame.Anchored = true
	frame.Parent = model

	-- Green display plank (readable Left face).
	local board = Instance.new("Part")
	board.Name = "Board"
	board.Size = Vector3.new(0.4, 5, 8)
	board.CFrame = base
	board.Material = Enum.Material.WoodPlanks
	board.Color = Color3.fromRGB(83, 125, 74)
	board.Anchored = true
	board.Parent = model
	model.PrimaryPart = board

	-- Support post down to the ground.
	local post = Instance.new("Part")
	post.Name = "Post"
	post.Size = Vector3.new(0.7, 5, 0.7)
	post.CFrame = base * CFrame.new(0.12, -5, 0)
	post.Material = Enum.Material.Wood
	post.Color = Color3.fromRGB(70, 52, 36)
	post.Anchored = true
	post.Parent = model

	addBoardSurfaceGui(board)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrade Garden"
	prompt.ObjectText = "Garden Upgrades"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = board

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		-- Only the farm owner upgrades from their own board.
		if plot:GetAttribute("USERID") ~= player.UserId then
			return
		end
		pushState(player)
		upgradeRemote:FireClient(player, "open")
	end)

	model.Parent = plot
	return model
end

function Service.setupPlotBoard(player: Player)
	local plotService = cachedModules.Cache.PlotService
	local plot = plotService and plotService.getPlot(player)
	if not plot then
		return
	end

	local existing = plot:FindFirstChild("UpgradeBoard")
	if existing then
		existing:Destroy()
	end

	local board = buildPlotBoard(plot)
	if board then
		playerBoards[player] = board
	end
end

function Service.dataLoaded(player: Player)
	applyGrowthReduction(player)
	Service.setupPlotBoard(player)
end

-- --------------------------------------------------------------------- init
function Service.init()
	upgradeRemote.OnServerEvent:Connect(function(player, action)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if action == "refresh" then
			pushState(player)
		elseif action == "buyPlot" or action == "buyGrowth" then
			handlePurchase(player, action)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local board = playerBoards[player]
		if board then
			board:Destroy()
			playerBoards[player] = nil
		end
	end)
end

return Service
