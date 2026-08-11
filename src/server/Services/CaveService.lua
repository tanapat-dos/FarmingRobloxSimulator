--!strict
--[[
	CaveService — server-authoritative teleport between the cave entrance and cave interior.

	workspace.cave_entrance and workspace.cave_inner each have a "portal plane" (Model.Part,
	a semi-transparent Neon Part shaped like a doorway) already positioned by hand in Studio.
	A ProximityPrompt is attached to the entrance's plane; triggering it moves the player's
	character to just in front of the interior's plane.

	Server-side only, matching this project's established rule (see the removed
	RemoteEvents.Teleport handler referenced in TeleportManager.client.lua): a client-trusted
	teleport destination is pure exploit surface. The player only ever sends "I triggered this
	specific ProximityPrompt" (built into Roblox's replication, not a custom remote with a
	position payload) — the server decides where that leads.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local Service = {}

local ENTRANCE_MODEL_NAME = "cave_entrance"
local INNER_MODEL_NAME = "cave_inner"
local PORTAL_PART_PATH = { "Model", "Part" } -- <model>.Model.Part, the doorway plane

-- How far in front of the destination plane's face the player lands, so they appear to walk
-- OUT of the portal instead of spawning inside/clipping through the (CanCollide) Neon part.
local ARRIVAL_OFFSET_STUDS = 4
local ARRIVAL_HEIGHT_OFFSET = 3

local function notify(player: Player, message: string, kind: string?)
	local remote = remotes:FindFirstChild("Notify")
	if remote then
		remote:FireClient(player, message, kind or "info")
	end
end

local function findPortalPart(modelName: string): BasePart?
	local model = workspace:FindFirstChild(modelName)
	if not model then
		warn(("[CaveService] workspace.%s not found."):format(modelName))
		return nil
	end
	local current: Instance = model
	for _, name in PORTAL_PART_PATH do
		local next = current:FindFirstChild(name)
		if not next then
			warn(("[CaveService] %s.%s missing (expected %s.%s)."):format(
				modelName, name, modelName, table.concat(PORTAL_PART_PATH, ".")))
			return nil
		end
		current = next
	end
	if not current:IsA("BasePart") then
		warn(("[CaveService] %s.%s is not a BasePart."):format(modelName, table.concat(PORTAL_PART_PATH, ".")))
		return nil
	end
	return current :: BasePart
end

-- Landing CFrame: standing upright, offset along the portal plane's own forward face (its
-- LookVector) so the player appears in front of the doorway rather than inside the Neon part,
-- and facing back toward the portal (as if just having stepped through it).
local function getArrivalCFrame(portalPart: BasePart): CFrame
	local forward = portalPart.CFrame.LookVector
	local landingPosition = portalPart.Position
		+ forward * ARRIVAL_OFFSET_STUDS
		+ Vector3.new(0, ARRIVAL_HEIGHT_OFFSET, 0)
	-- Face back the way they came (toward the portal), upright (no pitch/roll from the
	-- portal's own tilt).
	local flatLookAt = Vector3.new(-forward.X, 0, -forward.Z)
	if flatLookAt.Magnitude < 0.01 then
		flatLookAt = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(landingPosition, landingPosition + flatLookAt)
end

local function teleportPlayerTo(player: Player, destinationModelName: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local portalPart = findPortalPart(destinationModelName)
	if not portalPart then
		notify(player, "The cave path seems to be blocked right now.", "error")
		return
	end

	(root :: BasePart).CFrame = getArrivalCFrame(portalPart)
end

local function buildEntrancePrompt()
	local entrancePortal = findPortalPart(ENTRANCE_MODEL_NAME)
	if not entrancePortal then
		return
	end

	local existing = entrancePortal:FindFirstChild("EnterPrompt")
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = "Enter Cave"
	prompt.ObjectText = "Cave Entrance"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = entrancePortal

	prompt.Triggered:Connect(function(player: Player)
		teleportPlayerTo(player, INNER_MODEL_NAME)
	end)
end

-- Optional: lets players walk back out the way they came. Only built if the interior's
-- portal exists — a cave with no exit trigger is a valid design choice (e.g. a required
-- item or a different exit path elsewhere), so this doesn't warn if skipped.
local function buildExitPrompt()
	local innerPortal = findPortalPart(INNER_MODEL_NAME)
	if not innerPortal then
		return
	end

	local existing = innerPortal:FindFirstChild("ExitPrompt")
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExitPrompt"
	prompt.ActionText = "Exit Cave"
	prompt.ObjectText = "Cave Exit"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = innerPortal

	prompt.Triggered:Connect(function(player: Player)
		teleportPlayerTo(player, ENTRANCE_MODEL_NAME)
	end)
end

function Service.init()
	buildEntrancePrompt()
	buildExitPrompt()
end

return Service
