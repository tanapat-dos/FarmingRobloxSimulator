--!strict
--[[
	MiningConfig — tuning for the Mining feature (v1: single ore tier, instant cash on break,
	no ore inventory item yet).

	Ore nodes are 3-stage tap-to-break rocks (matches the 3-stage rock model set placed by
	hand): each tap on a node advances it to the next stage's model. Breaking the FINAL stage
	grants cash and starts a respawn cooldown; the node then rebuilds at Stage1.

	Stage template models live at ReplicatedStorage.Assets.Mining.OreStages.<name>, one per
	entry in STAGE_NAMES (see tools/SetupMiningOreStages.lua for how they were baked from the
	3 example rocks). Node spawn points are Parts named "OreNodeAnchor" anywhere under
	Workspace.MiningNodeAnchors — add more anchors to add more nodes, no code changes needed.
]]

local MiningConfig = {}

MiningConfig.PICKAXE_NAME = "Pickaxe"

-- Ordered stage template names, weakest (full health) to about-to-break.
MiningConfig.STAGE_NAMES = { "Stage1", "Stage2", "Stage3" }

MiningConfig.CASH_REWARD = 100 -- granted once, when the final stage breaks
MiningConfig.RESPAWN_SECONDS = 30
MiningConfig.TAP_DEBOUNCE_SECONDS = 0.35 -- guards against ProximityPrompt double-fires

-- Cosmetic swing tween played (client-side only) on the locally equipped Pickaxe whenever a
-- node's ProximityPrompt is triggered. Purely visual — the server decides the actual outcome.
MiningConfig.SWING_DURATION = 0.22
MiningConfig.MINE_PROMPT_NAME = "Mine"

-- Procedural Pickaxe tool (no .rbxl asset — built entirely in code, same pattern as
-- GearService's Fertilizer/Mutation Spray). Bought once from the Gear Shop for
-- EconomyBalance.GEAR["Pickaxe"].price; InventoryService.createNewTool calls this to build the
-- real tool. Shared here (not server-only) so it's usable from InventoryService too.
function MiningConfig.buildPickaxeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = MiningConfig.PICKAXE_NAME
	tool.ToolTip = "Mine ore nodes in the cave."
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("isPickaxe", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 2.2, 0.35)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(96, 66, 40)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Block
	head.Size = Vector3.new(1.1, 0.32, 0.32)
	head.Material = Enum.Material.Metal
	head.Color = Color3.fromRGB(140, 140, 148)
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle
	head.CFrame = handle.CFrame * CFrame.new(0, handle.Size.Y * 0.5, 0)

	tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	tool.GripPos = Vector3.new(0, handle.Size.Y * 0.3, 0)

	return tool
end

return MiningConfig
