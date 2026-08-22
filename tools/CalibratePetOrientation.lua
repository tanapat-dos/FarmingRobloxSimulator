--[[
	PET ORIENTATION CALIBRATION
	Paste into the Studio Command Bar while Studio is in Edit mode.

	This tool standardizes every baked pet around a direct FollowerRoot PrimaryPart containing a
	FacingAttachment. The attachment's LookVector is the visual face direction and its UpVector
	is visual up, so imported mesh axes no longer require runtime guessing.

	Every station points the same way: FacingAttachment looks along station local +Z, the red
	FacingGuide bar runs toward +Z, and the yellow FacingTip ball sits at the far +Z end. "Face the
	tip" and "face where FacingAttachment looks" are the same instruction.

	SETUP:
	  1. Select pet Models directly under ReplicatedStorage.Assets.Pets.<Egg>, or use SCOPE="ALL".
	  2. Run ACTION="SETUP". A Workspace.PetOrientationCalibration area is created and the current
	     tier of every source asset (gen2 / gen1 / legacy) is printed.
	  3. Per station, drag the magenta FaceMarker ball onto the animal's nose/face. The marker is
	     parented inside Visuals, so it keeps tracking the face while you rotate.
	  4. Select ONLY the Visuals Model, then move/rotate it until the animal is upright and its
	     FACE points at the yellow FacingTip ball (local +Z). Never rotate FollowerRoot.
	BAKE:
	  5. Set ACTION="BAKE" and CONFIRM_BAKE=true, then run again. BAKE refuses any station whose
	     FaceMarker points away from FacingTip - that missing check is what let 180°-flipped pets
	     bake silently before.
	  6. Inspect the printed self-check, Ctrl+S, then test equipped pets manually.
	CLEANUP:
	  7. Set ACTION="CLEANUP" after verification to remove only the calibration area.

	BAKE replaces matching pet Models but preserves Model attributes except obsolete
	FacingOffset attributes. It never changes EconomyBalance, player data, or Workspace sources.
]]

--=============================== CONFIGURE ===============================
local ACTION = "SETUP" -- "SETUP", "BAKE", or "CLEANUP"
local SCOPE = "SELECTED" -- "SELECTED" or "ALL" (SETUP only)
local CONFIRM_BAKE = false -- must be true for BAKE
local ORIGIN = Vector3.new(0, 20, 0)
local GRID_COLUMNS = 5
local GRID_SPACING = 18
--=========================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local petsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local CALIBRATION_NAME = "PetOrientationCalibration"
local FACE_MARKER_NAME = "FaceMarker"
-- Minimum horizontal distance between FaceMarker and the visual body centre before the marker
-- counts as a real face declaration instead of an untouched default.
local MIN_FACE_OFFSET = 0.35
-- Warn (do not block) once the declared face is more than this far off the FacingTip direction.
local FACE_WARN_DOT = 0.5
local LEGACY_ATTRIBUTES = {
	FacingOffsetX = true,
	FacingOffsetY = true,
	FacingOffsetZ = true,
	FacingOffsetDegrees = true,
}
local function sanitizePart(part: BasePart, isRoot: boolean)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	if isRoot then
		part.Name = "FollowerRoot"
		part.Transparency = 1
	end
end

local function removeUnsafeDescendants(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			sanitizePart(descendant, false)
		end
	end
end

local function getAssetIdentity(model: Model): (string?, string?)
	local eggFolder = model.Parent
	if not eggFolder or not eggFolder:IsA("Folder") or eggFolder.Parent ~= petsAssets then
		return nil, nil
	end
	return eggFolder.Name, model.Name
end

-- Horizontal unit direction, or nil when the vector carries no usable yaw.
local function flattenXZ(vector: Vector3): Vector3?
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 1e-4 then
		return nil
	end
	return flat.Unit
end

-- Mean world position of every visual BasePart except the marker itself. A rough centre is enough:
-- FaceMarker is dropped on an extremity, so only the sign of the resulting direction matters.
local function visualBodyCentre(visuals: Model, ignore: Instance?): Vector3?
	local total = Vector3.zero
	local count = 0
	for _, descendant in visuals:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= ignore then
			total += descendant.Position
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	return total / count
end

-- Reports which orientation contract the source asset currently uses, so SETUP output alone tells
-- gen2 / gen1 / legacy apart instead of leaving it to guesswork.
local function describeSourceTier(source: Model): string
	local root = source:FindFirstChild("FollowerRoot")
	local rootPart = if root and root:IsA("BasePart") then root else nil
	local facing = rootPart and rootPart:FindFirstChild("FacingAttachment") or nil
	local facingAttachment = if facing and facing:IsA("Attachment") then facing else nil

	local legacy = {}
	for _, name in { "FacingOffsetX", "FacingOffsetY", "FacingOffsetZ", "FacingOffsetDegrees" } do
		local value = source:GetAttribute(name)
		if value ~= nil then
			table.insert(legacy, ("%s=%s"):format(name:gsub("FacingOffset", ""), tostring(value)))
		end
	end
	local legacyText = if #legacy == 0 then "none" else table.concat(legacy, ",")

	local tier
	if rootPart and facingAttachment then
		tier = "gen2"
	elseif rootPart then
		tier = "gen1"
	else
		tier = "legacy"
	end

	local primary = source.PrimaryPart
	local primaryText = "PrimaryPart=nil"
	if primary ~= nil then
		primaryText = if primary == rootPart
			then "PrimaryPart=FollowerRoot"
			else ("PrimaryPart=%s"):format(primary.Name)
	end

	local facingText = "FacingAttachment=none"
	if facingAttachment then
		local look = facingAttachment.CFrame.LookVector
		facingText = ("FacingAttachment look=(%.2f,%.2f,%.2f)"):format(look.X, look.Y, look.Z)
	end

	return ("tier=%-6s %-24s %-38s FacingOffset*=%s"):format(tier, primaryText, facingText, legacyText)
end

local function collectSources(): { Model }
	local sources: { Model } = {}
	if SCOPE == "ALL" then
		for _, eggFolder in petsAssets:GetChildren() do
			if eggFolder:IsA("Folder") then
				for _, child in eggFolder:GetChildren() do
					if child:IsA("Model") then
						table.insert(sources, child)
					end
				end
			end
		end
	elseif SCOPE == "SELECTED" then
		for _, selected in Selection:Get() do
			if selected:IsA("Model") then
				local eggName = getAssetIdentity(selected)
				if eggName then
					table.insert(sources, selected)
				end
			end
		end
	else
		error("[PetCalibration] SCOPE must be SELECTED or ALL.")
	end

	table.sort(sources, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	if #sources == 0 then
		error("[PetCalibration] No pet asset Models found. Select Models directly inside an egg folder.")
	end
	return sources
end
local function makeHelperPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function setupStation(parent: Folder, source: Model, index: number)
	local eggName, petName = getAssetIdentity(source)
	assert(eggName and petName, "Source identity changed during setup")
	if not source:FindFirstChildWhichIsA("BasePart", true) then
		error(("[PetCalibration] %s.%s has no BasePart."):format(eggName, petName))
	end

	local column = (index - 1) % GRID_COLUMNS
	local row = math.floor((index - 1) / GRID_COLUMNS)
	local stationPosition = ORIGIN + Vector3.new(column * GRID_SPACING, 0, row * GRID_SPACING)

	local station = Instance.new("Model")
	station.Name = eggName .. "__" .. petName
	station:SetAttribute("EggName", eggName)
	station:SetAttribute("PetName", petName)
	station.Parent = parent

	local visuals = source:Clone()
	visuals.Name = "Visuals"
	visuals.PrimaryPart = nil
	for _, child in visuals:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "FollowerRoot" or child.Name == FACE_MARKER_NAME) then
			child:Destroy()
		end
	end
	removeUnsafeDescendants(visuals)
	visuals.Parent = station
	local offsetX = tonumber(source:GetAttribute("FacingOffsetX")) or 0
	local offsetY = tonumber(source:GetAttribute("FacingOffsetY"))
		or tonumber(source:GetAttribute("FacingOffsetDegrees"))
		or 0
	local offsetZ = tonumber(source:GetAttribute("FacingOffsetZ")) or 0
	local legacyOrientation = CFrame.Angles(math.rad(offsetX), math.rad(offsetY), math.rad(offsetZ))
	visuals:PivotTo(CFrame.new(stationPosition) * legacyOrientation)

	local boundsCFrame, boundsSize = visuals:GetBoundingBox()
	local floorY = stationPosition.Y
	local desiredCenter = Vector3.new(stationPosition.X, floorY + boundsSize.Y / 2 + 0.5, stationPosition.Z)
	local delta = desiredCenter - boundsCFrame.Position
	visuals:PivotTo(CFrame.new(delta) * visuals:GetPivot())

	local root = makeHelperPart("FollowerRoot", Vector3.new(2, 2, 2), CFrame.new(desiredCenter),
		Color3.fromRGB(80, 255, 120), station)
	root.Transparency = 0.35
	local facing = Instance.new("Attachment")
	facing.Name = "FacingAttachment"
	facing.CFrame = CFrame.Angles(0, math.pi, 0) -- LookVector +Z, UpVector +Y
	facing.Parent = root
	station.PrimaryPart = root

	local floorSize = math.max(12, math.max(boundsSize.X, boundsSize.Z) + 4)
	local floor = makeHelperPart("Floor", Vector3.new(floorSize, 0.25, floorSize),
		CFrame.new(stationPosition.X, floorY - 0.125, stationPosition.Z), Color3.fromRGB(70, 70, 70), station)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Transparency = 0.25
	makeHelperPart("FacingGuide", Vector3.new(0.5, 0.5, 7),
		CFrame.new(desiredCenter) * CFrame.new(0, -boundsSize.Y / 2 + 0.5, 5), Color3.fromRGB(255, 70, 70), station)
	local tip = makeHelperPart("FacingTip", Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(desiredCenter) * CFrame.new(0, -boundsSize.Y / 2 + 0.5, 9), Color3.fromRGB(255, 220, 40), station)
	tip.Shape = Enum.PartType.Ball

	-- Where the animal's face is cannot be read from instance data: each mesh pack authors its own
	-- forward axis, so relative yaw is not a facing oracle. FaceMarker turns the one thing only a
	-- human can see into checkable data. It starts straight above the body (zero horizontal offset)
	-- so BAKE fails closed until it has actually been placed on the face.
	local marker = makeHelperPart(FACE_MARKER_NAME, Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(desiredCenter) * CFrame.new(0, boundsSize.Y / 2 + 1.2, 0),
		Color3.fromRGB(255, 60, 220), visuals)
	marker.Shape = Enum.PartType.Ball
end
local function setup()
	if Workspace:FindFirstChild(CALIBRATION_NAME) then
		error("[PetCalibration] Calibration area already exists. BAKE it or CLEANUP before a new SETUP.")
	end
	local sources = collectSources()
	local folder = Instance.new("Folder")
	folder.Name = CALIBRATION_NAME
	folder.Parent = Workspace
	for index, source in sources do
		local eggName, petName = getAssetIdentity(source)
		print(("[PetCalibration] SETUP %-14s / %-16s %s"):format(
			tostring(eggName), tostring(petName), describeSourceTier(source)))
		setupStation(folder, source, index)
	end
	print(("[PetCalibration] SETUP complete: %d station(s)."):format(#sources))
	print(("1) Drag each station's magenta %s ball onto the animal's nose/face (it stays with Visuals)."):format(FACE_MARKER_NAME))
	print("2) Select ONLY the Visuals Model and rotate/move it until the animal is upright and its")
	print("   FACE points at the yellow FacingTip ball at the far end of the red guide (local +Z,")
	print("   the direction FacingAttachment looks). Never rotate FollowerRoot.")
	print(("3) BAKE errors out if %s ends up pointing away from FacingTip."):format(FACE_MARKER_NAME))
	Selection:Set({ folder })
end

local function isHelperPart(instance: Instance): boolean
	return instance:IsA("BasePart") and (instance.Name == "FollowerRoot" or instance.Name == FACE_MARKER_NAME)
end

local function cloneBakedChild(child: Instance): Instance?
	if child:IsA("LuaSourceContainer") or isHelperPart(child) then
		return nil
	end
	local clone = child:Clone()
	removeUnsafeDescendants(clone)
	for _, descendant in clone:GetDescendants() do
		if isHelperPart(descendant) then
			descendant:Destroy()
		end
	end
	return clone
end

-- Guard the one failure BAKE used to wave through: Visuals baked facing the opposite way to
-- FacingAttachment. Runtime makes FacingAttachment.WorldCFrame equal the player's ground frame, so a
-- flipped body is a permanent 180° error that no later check catches. Returns the off-axis angle.
local function assertVisualsFaceAttachment(station: Model, visuals: Model, stationFacing: Attachment): number
	local marker = visuals:FindFirstChild(FACE_MARKER_NAME, true)
	if not marker or not marker:IsA("BasePart") then
		error(("[PetCalibration] %s has no %s ball inside its Visuals Model. The marker must stay parented under Visuals so it tracks rotation - move it back, or CLEANUP and re-run SETUP."):format(
			station.Name, FACE_MARKER_NAME))
	end

	local centre = visualBodyCentre(visuals, marker)
	if not centre then
		error(("[PetCalibration] %s Visuals has no BasePart to measure."):format(station.Name))
	end

	local offset = Vector3.new(marker.Position.X - centre.X, 0, marker.Position.Z - centre.Z)
	if offset.Magnitude < MIN_FACE_OFFSET then
		error(("[PetCalibration] %s %s is still sitting above the body centre. Drag it onto the animal's nose/face first, then BAKE."):format(
			station.Name, FACE_MARKER_NAME))
	end

	local faceDirection = flattenXZ(offset)
	local guideDirection = flattenXZ(stationFacing.WorldCFrame.LookVector)
	if not faceDirection or not guideDirection then
		error(("[PetCalibration] %s could not resolve a horizontal facing direction."):format(station.Name))
	end

	local dot = math.clamp(faceDirection:Dot(guideDirection), -1, 1)
	local angle = math.deg(math.acos(dot))
	if dot < 0 then
		error(("[PetCalibration] %s Visuals is facing backwards (%.0f° off the yellow FacingTip). Rotate the Visuals Model 180° so the face and %s point at FacingTip - do NOT rotate FollowerRoot."):format(
			station.Name, angle, FACE_MARKER_NAME))
	end
	if dot < FACE_WARN_DOT then
		warn(("[PetCalibration] %s Visuals is %.0f° off the yellow FacingTip. Square it up before trusting the bake."):format(
			station.Name, angle))
	end
	return angle
end

local function bakeStation(station: Model): (string, string, number)
	local eggName = station:GetAttribute("EggName")
	local petName = station:GetAttribute("PetName")
	if typeof(eggName) ~= "string" or typeof(petName) ~= "string" then
		error(("[PetCalibration] %s is missing EggName/PetName attributes."):format(station.Name))
	end

	local eggFolder = petsAssets:FindFirstChild(eggName)
	local source = eggFolder and eggFolder:FindFirstChild(petName)
	local visuals = station:FindFirstChild("Visuals")
	local stationRoot = station:FindFirstChild("FollowerRoot")
	local stationFacing = stationRoot and stationRoot:FindFirstChild("FacingAttachment")
	if not eggFolder or not eggFolder:IsA("Folder") or not source or not source:IsA("Model") then
		error(("[PetCalibration] Asset disappeared: %s.%s"):format(eggName, petName))
	end
	if not visuals or not visuals:IsA("Model") or not stationRoot or not stationRoot:IsA("BasePart")
		or not stationFacing or not stationFacing:IsA("Attachment") then
		error(("[PetCalibration] Station is missing Visuals, FollowerRoot, or FacingAttachment: %s"):format(station.Name))
	end
	if station.PrimaryPart ~= stationRoot then
		error(("[PetCalibration] %s PrimaryPart must remain FollowerRoot."):format(station.Name))
	end
	if stationRoot.CFrame.UpVector:Dot(Vector3.yAxis) < 0.999
		or stationRoot.CFrame.LookVector:Dot(Vector3.new(0, 0, -1)) < 0.999 then
		error(("[PetCalibration] %s FollowerRoot was rotated. Undo that; rotate Visuals only."):format(station.Name))
	end
	local faceAngle = assertVisualsFaceAttachment(station, visuals, stationFacing)

	local replacement = Instance.new("Model")
	replacement.Name = petName .. "_Calibrated"
	for name, value in source:GetAttributes() do
		if not LEGACY_ATTRIBUTES[name] then
			replacement:SetAttribute(name, value)
		end
	end

	local bakedRoot = stationRoot:Clone()
	for _, child in bakedRoot:GetChildren() do
		child:Destroy()
	end
	sanitizePart(bakedRoot, true)
	local bakedFacing = stationFacing:Clone()
	bakedFacing.Name = "FacingAttachment"
	bakedFacing.Parent = bakedRoot
	bakedRoot.Parent = replacement
	local visiblePartCount = 0
	for _, child in visuals:GetChildren() do
		local clone = cloneBakedChild(child)
		if clone then
			clone.Parent = replacement
			if clone:IsA("BasePart") then
				visiblePartCount += 1
			end
			for _, descendant in clone:GetDescendants() do
				if descendant:IsA("BasePart") then
					visiblePartCount += 1
				end
			end
		end
	end
	if visiblePartCount == 0 then
		replacement:Destroy()
		error(("[PetCalibration] %s.%s would have no visible BaseParts."):format(eggName, petName))
	end

	replacement.PrimaryPart = bakedRoot
	replacement.Parent = eggFolder
	source:Destroy()
	replacement.Name = petName
	return eggName, petName, faceAngle
end

local function bake()
	if not CONFIRM_BAKE then
		error("[PetCalibration] BAKE replaces pet assets. Set CONFIRM_BAKE=true after reviewing every station.")
	end
	local folder = Workspace:FindFirstChild(CALIBRATION_NAME)
	if not folder or not folder:IsA("Folder") then
		error("[PetCalibration] No calibration area found. Run SETUP first.")
	end

	local stations: { Model } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(stations, child)
		end
	end
	table.sort(stations, function(a, b)
		return a.Name < b.Name
	end)
	if #stations == 0 then
		error("[PetCalibration] Calibration area has no stations.")
	end

	for _, station in stations do
		local eggName, petName, faceAngle = bakeStation(station)
		local baked = petsAssets:FindFirstChild(eggName):FindFirstChild(petName)
		local root = baked and baked:FindFirstChild("FollowerRoot")
		local facing = root and root:FindFirstChild("FacingAttachment")
		local valid = baked and baked:IsA("Model") and root and root:IsA("BasePart")
			and baked.PrimaryPart == root and facing and facing:IsA("Attachment")
		print(("[PetCalibration] BAKED %-14s / %-16s root=%s face=%.0f° off FacingTip"):format(
			eggName, petName, tostring(valid), faceAngle))
		if not valid then
			error(("[PetCalibration] Self-check failed for %s.%s"):format(eggName, petName))
		end
	end
	print(("[PetCalibration] BAKE complete: %d pet(s). Ctrl+S, then test manually before CLEANUP."):format(#stations))
end

local function cleanup()
	local folder = Workspace:FindFirstChild(CALIBRATION_NAME)
	if folder then
		folder:Destroy()
	end
	print("[PetCalibration] Calibration area removed. Pet assets were not changed.")
end

if ACTION == "SETUP" then
	setup()
elseif ACTION == "BAKE" then
	bake()
elseif ACTION == "CLEANUP" then
	cleanup()
else
	error("[PetCalibration] ACTION must be SETUP, BAKE, or CLEANUP.")
end
