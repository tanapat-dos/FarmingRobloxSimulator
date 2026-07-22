--!strict
-- Discovers bridge / canal rock fishing spots (server sets attributes; client reads them).

local CollectionService = game:GetService("CollectionService")

local FishingConfig = require(script.Parent.FishingConfig)

local FishingStandRegistry = {}

local cachedStands: { BasePart } = {}
local lastScanAt = 0
local SCAN_INTERVAL = 2

local function isStandPart(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	if CollectionService:HasTag(part, FishingConfig.STAND_TAG) then
		return true
	end
	return part:GetAttribute("FishingStand") == true and typeof(part:GetAttribute("ZoneId")) == "string"
end

function FishingStandRegistry.collectStandParts(): { BasePart }
	local now = os.clock()
	if #cachedStands > 0 and now - lastScanAt < SCAN_INTERVAL then
		return cachedStands
	end

	local found: { BasePart } = {}
	local seen: { [BasePart]: boolean } = {}

	for _, inst in CollectionService:GetTagged(FishingConfig.STAND_TAG) do
		if inst:IsA("BasePart") and not seen[inst] then
			seen[inst] = true
			table.insert(found, inst)
		end
	end

	for _, desc in workspace:GetDescendants() do
		if isStandPart(desc) and not seen[desc :: BasePart] then
			seen[desc :: BasePart] = true
			table.insert(found, desc :: BasePart)
		end
	end

	cachedStands = found
	lastScanAt = now
	return found
end

function FishingStandRegistry.clearCache()
	table.clear(cachedStands)
	lastScanAt = 0
end

local function registerStand(part: BasePart, zoneId: string)
	part:SetAttribute("FishingStand", true)
	part:SetAttribute("ZoneId", zoneId)
	if not CollectionService:HasTag(part, FishingConfig.STAND_TAG) then
		CollectionService:AddTag(part, FishingConfig.STAND_TAG)
	end
end

local function findBridgeModels(): { Model }
	local bridges: { Model } = {}
	for _, desc in workspace:GetDescendants() do
		if desc:IsA("Model") and desc.Name == "Bridge" then
			table.insert(bridges, desc)
		end
	end
	return bridges
end

local ensured = false

function FishingStandRegistry.ensureRegistered()
	if ensured then
		return
	end
	ensured = true

	local registered = 0

	for _, bridge in findBridgeModels() do
		for _, desc in bridge:GetDescendants() do
			if desc:IsA("BasePart") and desc.Size.Magnitude > 1.5 then
				registerStand(desc, "CanalFull")
				registered += 1
			end
		end
	end

	local rockFolder = workspace:FindFirstChild("Rock")
	if rockFolder then
		for _, child in rockFolder:GetDescendants() do
			if child:IsA("BasePart") and child.CanCollide then
				local pos = child.Position
				local nearWaterfall = (pos - Vector3.new(-17.5, 48, -229)).Magnitude < 55
				registerStand(child, if nearWaterfall then "WaterfallPool" else "CanalFull")
				registered += 1
			end
		end
	end

	local waterfall = workspace:FindFirstChild("Waterfall")
	if waterfall then
		for _, desc in waterfall:GetDescendants() do
			if desc:IsA("BasePart") and desc.CanCollide then
				registerStand(desc, "WaterfallPool")
				registered += 1
			end
		end
	end

	workspace:SetAttribute("FishingStandsRegistered", true)
	FishingStandRegistry.clearCache()

	if registered > 0 then
		print(`[FishingStandRegistry] Registered {registered} fishing stand part(s).`)
	else
		warn("[FishingStandRegistry] No fishing stands found — check Bridge / Rock / Waterfall in Workspace.")
	end
end

return FishingStandRegistry
