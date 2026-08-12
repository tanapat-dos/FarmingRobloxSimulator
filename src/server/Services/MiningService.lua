--!strict
--[[
	MiningService — server-authoritative tap-to-mine ore nodes.

	Each node is a 3-stage rock (Stage1 = full health -> Stage2 -> Stage3 = about to break).
	A ProximityPrompt sits on whichever stage model is currently visible; each tap advances the
	node one stage. Breaking the final stage grants instant cash, hides the node, and respawns
	it back at Stage1 after a cooldown. Same shared-world-resource pattern as GearService's
	kiosk crates — server owns node state, client only ever sends "I triggered this specific
	prompt" (no position/amount payload), never trusted with the reward directly.

	Requires the player to have their Pickaxe tool equipped to mine (bought from the Gear Shop,
	see EconomyBalance.GEAR["Pickaxe"]). The swing itself is a purely cosmetic client tween on
	the local ProximityPrompt trigger (see MiningClient.client.lua); nothing about the swing
	motion is trusted here.

	Stage templates: ReplicatedStorage.Assets.Mining.OreStages.<StageName>, one per
	MiningConfig.STAGE_NAMES. Node spawn points: any Part named "OreNodeAnchor" anywhere under
	Workspace.MiningNodeAnchors — add more anchors to add more nodes, no code changes needed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MiningConfig = require(ReplicatedStorage:WaitForChild("Modules").MiningConfig)
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

local ORE_NODE_TAG = "MiningOreNode"
local lastTapAt: { [Player]: number } = {}

local function notify(player: Player, message: string, kind: string?)
	local remote = remotes:FindFirstChild("Notify")
	if remote then
		remote:FireClient(player, message, kind or "info")
	end
end

local function getOreStagesFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local mining = assets and assets:FindFirstChild("Mining")
	local stages = mining and mining:FindFirstChild("OreStages")
	return stages :: Folder?
end

local function getStageTemplate(stageIndex: number): Model?
	local stages = getOreStagesFolder()
	local name = MiningConfig.STAGE_NAMES[stageIndex]
	if not stages or not name then
		return nil
	end
	local template = stages:FindFirstChild(name)
	return (template :: Model?)
end

--[[
	Server-side node state, keyed by the anchor that owns it. `placementCFrame` is the node's
	OWN world position — set once (from wherever the model was hand-placed/adopted, or from the
	anchor as a fallback for a brand-new node) and reused for every stage swap AND respawn.
	Crucially this is NOT re-derived from the anchor's CFrame on every rebuild — that's what
	lets you drag the node anywhere in Edit mode and have it stay there permanently, instead of
	snapping back to the anchor whenever it respawns (the anchor only exists to mark "there
	should be a node somewhere near here", not to dictate its exact position).
]]
type NodeState = {
	anchorPart: BasePart,
	placementCFrame: CFrame,
	stageIndex: number,
	model: Model,
	respawning: boolean,
}

local nodesByAnchor: { [BasePart]: NodeState } = {}

local function buildPromptOn(model: Model, root: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = MiningConfig.MINE_PROMPT_NAME
	prompt.ActionText = "Mine"
	prompt.ObjectText = "Ore Node"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player: Player)
		Service.handleTap(player, model)
	end)
end

-- Builds (or rebuilds) the visible model for a node at the given stage, replacing whatever
-- model currently sits there, always at state.placementCFrame — never at the anchor's raw
-- CFrame. Every geometry part gets Anchored/CanCollide set explicitly — templates are just
-- clones of hand-placed rocks, not guaranteed to already be anchored.
local function setStage(anchorPart: BasePart, stageIndex: number, state: NodeState)
	local template = getStageTemplate(stageIndex)
	if not template then
		warn(("[MiningService] Missing stage template '%s' — node not (re)built."):format(
			MiningConfig.STAGE_NAMES[stageIndex] or tostring(stageIndex)))
		return
	end

	if state.model then
		state.model:Destroy()
	end

	local model = template:Clone()
	model.Name = "OreNode"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
		end
	end

	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		warn("[MiningService] Stage template has no BasePart — cannot place node.")
		model:Destroy()
		return
	end

	-- Pivot directly to the node's saved placement. No offset math needed here (unlike the
	-- crop/rebirth boards, which derive a sign's height/rotation relative to an anchor) — the
	-- node's own placementCFrame IS the exact spot it should sit at, always.
	model:PivotTo(state.placementCFrame)

	CollectionService:AddTag(model, ORE_NODE_TAG)
	model.Parent = anchorPart.Parent

	buildPromptOn(model, root)

	state.stageIndex = stageIndex
	state.model = model
	state.respawning = false
end

local function respawnNode(anchorPart: BasePart)
	local state = nodesByAnchor[anchorPart]
	if not state then
		return
	end
	state.respawning = true
	state.model:Destroy()

	task.delay(MiningConfig.RESPAWN_SECONDS, function()
		if anchorPart.Parent and nodesByAnchor[anchorPart] == state then
			setStage(anchorPart, 1, state)
		end
	end)
end

local function isPickaxeEquipped(player: Player): boolean
	local character = player.Character
	local tool = character and character:FindFirstChildWhichIsA("Tool")
	return tool ~= nil and tool.Name == MiningConfig.PICKAXE_NAME
end

function Service.handleTap(player: Player, expectedModel: Model)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end

	local now = os.clock()
	local last = lastTapAt[player] or 0
	if now - last < MiningConfig.TAP_DEBOUNCE_SECONDS then
		return
	end
	lastTapAt[player] = now

	if not isPickaxeEquipped(player) then
		notify(player, "Equip your Pickaxe to mine!", "error")
		return
	end

	-- Find the node this model still belongs to (guards against a tap landing on a model
	-- that already got swapped/destroyed by a faster, or simultaneous, hit).
	local anchorPart: BasePart? = nil
	local state: NodeState? = nil
	for anchor, s in nodesByAnchor do
		if s.model == expectedModel then
			anchorPart, state = anchor, s
			break
		end
	end
	if not anchorPart or not state or state.respawning then
		return
	end

	local nextStage = state.stageIndex + 1
	if nextStage <= #MiningConfig.STAGE_NAMES then
		setStage(anchorPart :: BasePart, nextStage, state)
		return
	end

	-- Final stage just broke.
	local moneyService = cachedModules.Cache.MoneyService
	local paid = moneyService and moneyService.giveMoney(player, MiningConfig.CASH_REWARD) or 0
	notify(player, ("⛏️ Mined ore! +$%d"):format(paid), "success")
	respawnNode(anchorPart)
end

local function collectAnchors(): { BasePart }
	local root = workspace:FindFirstChild("MiningNodeAnchors")
	if not root then
		return {}
	end
	local anchors = {}
	for _, descendant in root:GetDescendants() do
		if descendant.Name == "OreNodeAnchor" and descendant:IsA("BasePart") then
			table.insert(anchors, descendant)
		end
	end
	return anchors
end

-- Multiple OreNodeAnchors commonly share one parent folder, so matching by name alone would
-- only ever find ONE "OreNode" sibling per folder. Match by proximity instead: the nearest
-- untagged-yet "OreNode" model within this radius belongs to this anchor.
local ADOPT_MATCH_RADIUS = 15

--[[
	Adopts a hand-placed "OreNode" model already sitting near this anchor in Edit mode (baked
	in via a one-time Studio bake, same pattern as CropSellLeaderboardService's board) instead
	of building a fresh one from the template. This is what makes the node visible AND movable
	in Edit mode: wherever you drag the baked model becomes its permanent placement (captured
	into state.placementCFrame), which every future stage swap and respawn reuses — the anchor
	is only used to locate this sibling, never to override its position.
]]
local function adoptExistingNode(anchorPart: BasePart): boolean
	local parent = anchorPart.Parent
	if not parent then
		return false
	end

	local claimedModels = {}
	for _, state in nodesByAnchor do
		claimedModels[state.model] = true
	end

	local best: Model? = nil
	local bestDistance = ADOPT_MATCH_RADIUS
	for _, child in workspace:GetDescendants() do
		if child.Name == "OreNode" and child:IsA("Model") and not claimedModels[child] then
			local ok, pivot = pcall(function()
				return child:GetPivot()
			end)
			if ok then
				local distance = (pivot.Position - anchorPart.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = child, distance
				end
			end
		end
	end

	local siblingModel = best
	if not siblingModel or not siblingModel:IsA("Model") then
		return false
	end

	local root = siblingModel.PrimaryPart or siblingModel:FindFirstChildWhichIsA("BasePart")
	if not root then
		return false
	end

	for _, part in siblingModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
		end
	end
	if not siblingModel.PrimaryPart then
		siblingModel.PrimaryPart = root
	end

	CollectionService:AddTag(siblingModel, ORE_NODE_TAG)
	if not root:FindFirstChild(MiningConfig.MINE_PROMPT_NAME) then
		buildPromptOn(siblingModel, root)
	end

	nodesByAnchor[anchorPart] = {
		anchorPart = anchorPart,
		placementCFrame = siblingModel:GetPivot(),
		stageIndex = 1,
		model = siblingModel,
		respawning = false,
	}
	return true
end

local function setupNodes()
	local anchors = collectAnchors()
	if #anchors == 0 then
		warn("[MiningService] No OreNodeAnchor parts found under Workspace.MiningNodeAnchors — no ore nodes spawned.")
		return
	end
	for _, anchorPart in anchors do
		anchorPart.Anchored = true
		anchorPart.CanCollide = false
		anchorPart.Transparency = 1
		if not nodesByAnchor[anchorPart] then
			if not adoptExistingNode(anchorPart) then
				-- No hand-placed model to adopt — build a brand-new node at the anchor's own
				-- position (this only happens for freshly-added anchors with no baked model yet).
				local freshState: NodeState = {
					anchorPart = anchorPart,
					placementCFrame = anchorPart.CFrame,
					stageIndex = 1,
					model = Instance.new("Model"), -- placeholder, replaced immediately by setStage
					respawning = false,
				}
				nodesByAnchor[anchorPart] = freshState
				setStage(anchorPart, 1, freshState)
			end
		end
	end
end

-- Pickaxe is now a Gear Shop purchase (EconomyBalance.GEAR["Pickaxe"], $1000, one-time), not a
-- free grant. See MiningConfig.buildPickaxeTool for the actual tool geometry (shared with
-- InventoryService.createNewTool's nonConsumable-gear branch, which builds it on purchase and
-- on every rejoin/character respawn).

function Service.init()
	setupNodes()

	game.Players.PlayerRemoving:Connect(function(player)
		lastTapAt[player] = nil
	end)
end

return Service
