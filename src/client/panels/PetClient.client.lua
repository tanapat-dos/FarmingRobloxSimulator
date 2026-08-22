local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local petsAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local NavigationHudState = require(ReplicatedStorage:WaitForChild("Modules").NavigationHudState)

local clientSignals = ReplicatedStorage:FindFirstChild("ClientSignals")
if not clientSignals then
	clientSignals = Instance.new("Folder")
	clientSignals.Name = "ClientSignals"
	clientSignals.Parent = ReplicatedStorage
end
local togglePetShop = clientSignals:FindFirstChild("TogglePetShop")
if not togglePetShop then
	togglePetShop = Instance.new("BindableEvent")
	togglePetShop.Name = "TogglePetShop"
	togglePetShop.Parent = clientSignals
end

local mainButtons = PlayerGui:WaitForChild("Main"):WaitForChild("Buttons")
local blur = game.Lighting:WaitForChild("Blur")

local PetShopScreenGui: ScreenGui? = nil
local PetShopUI: Frame? = nil
local closePetShopBtn: TextButton? = nil
local panelOpen = false
local uiReady = false

--[[
	Equipped pets are visual-only followers (no server-owned Model to replicate), so every
	client is responsible for spawning a follower for EVERY player who has one equipped — not
	just itself. petFollowUpdate now arrives tagged with ownerUserId (see PetService), so we
	key active pet models per owner instead of assuming "the pet" always belongs to LocalPlayer.
]]
local activePets: { [number]: { model: Model, connection: RBXScriptConnection } } = {}

local function resolvePetShopUI(): boolean
	if uiReady and PetShopUI and PetShopUI.Parent then
		return true
	end

	local gui = PlayerGui:FindFirstChild("PetShop")
	if not gui or not gui:IsA("ScreenGui") then
		return false
	end

	local frame = gui:FindFirstChild("Frame")
	if not frame or not frame:IsA("Frame") then
		return false
	end

	local closeBtn = frame:FindFirstChild("CloseShop")
	if not closeBtn or not closeBtn:IsA("TextButton") then
		return false
	end

	PetShopScreenGui = gui
	PetShopUI = frame
	closePetShopBtn = closeBtn
	uiReady = true
	return true
end

local function setHudButtonsVisible(visible: boolean)
	if visible then
		NavigationHudState.applyMainButtons(mainButtons)
	else
		for _, child in mainButtons:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
	end
end

local function toggleBlur(enable)
	TweenService:Create(blur, TweenInfo.new(0.3), { Size = enable and 15 or 0 }):Play()
end

local function showPetShopUI()
	if not resolvePetShopUI() or not PetShopScreenGui or not PetShopUI then
		warn("[PetClient] Cannot open pet shop — UI not ready.")
		return
	end
	panelOpen = true
	PetShopScreenGui.DisplayOrder = 10
	pcall(setHudButtonsVisible, false)
	PetShopUI.Size = UDim2.new(0, 0, 0, 0)
	PetShopUI.Visible = true
	toggleBlur(true)
	TweenService:Create(PetShopUI, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.414, 0, 0.8, 0),
	}):Play()
end

local function hidePetShopUI()
	if not PetShopUI then
		panelOpen = false
		return
	end
	panelOpen = false
	TweenService:Create(PetShopUI, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
	}):Play()
	toggleBlur(false)
	task.delay(0.2, function()
		if PetShopUI then
			PetShopUI.Visible = false
		end
		pcall(setHudButtonsVisible, true)
	end)
end

task.spawn(function()
	local gui = PlayerGui:WaitForChild("PetShop", 30)
	if not gui then
		warn("[PetClient] PetShop ScreenGui missing from StarterGui — pet shop UI will not open.")
		return
	end
	if not resolvePetShopUI() then
		warn("[PetClient] PetShop is missing Frame or CloseShop.")
		return
	end
	if closePetShopBtn then
		closePetShopBtn.MouseButton1Click:Connect(hidePetShopUI)
	end
end)

togglePetShop.Event:Connect(function(action)
	if action == "open" then
		if panelOpen then
			hidePetShopUI()
		else
			showPetShopUI()
		end
	elseif action == "close" then
		if panelOpen then
			hidePetShopUI()
		end
	end
end)

local function despawnPet(ownerUserId: number)
	local active = activePets[ownerUserId]
	if not active then
		return
	end
	active.connection:Disconnect()
	active.model:Destroy()
	activePets[ownerUserId] = nil
end

local function getOwnerRoot(ownerUserId: number): BasePart?
	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	local character = ownerPlayer and ownerPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

--[[
	Permanent orientation convention:
	- A calibrated pet has a direct BasePart child named FollowerRoot.
	- FollowerRoot is the Model.PrimaryPart.
	- FollowerRoot contains FacingAttachment; its LookVector is visual forward and UpVector is up.

	Runtime aligns that complete attachment frame with the player's level facing frame. This
	handles arbitrary imported forward/up axes without guessing from mesh bounds. Legacy
	FacingOffset attributes remain only as a migration fallback for uncalibrated assets.
]]
local function getFollowerRoot(model: Model): BasePart?
	local root = model:FindFirstChild("FollowerRoot")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getFacingAttachment(root: BasePart?): Attachment?
	local attachment = root and root:FindFirstChild("FacingAttachment")
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end
	return nil
end

local function getLegacyFacingOffset(src: Model): CFrame
	local x = src:GetAttribute("FacingOffsetX")
	local y = src:GetAttribute("FacingOffsetY")
	local z = src:GetAttribute("FacingOffsetZ")
	if typeof(y) ~= "number" then
		y = src:GetAttribute("FacingOffsetDegrees")
	end

	x = if typeof(x) == "number" then x else 0
	y = if typeof(y) == "number" then y else 0
	z = if typeof(z) == "number" then z else 0
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local FOLLOW_OFFSET = Vector3.new(2.5, 0, 0) -- local-space offset from root (to the right)
local FOLLOW_UP = Vector3.new(0, 1, 0) -- world up, not root.CFrame.UpVector — see below

-- Rebuild a level frame from LookVector so seated/ragdolled root roll cannot tilt the pet.
local function computeFollowTarget(root: BasePart, facingCorrection: CFrame): CFrame
	local position = (root.CFrame * CFrame.new(FOLLOW_OFFSET)).Position
	local baseCFrame = CFrame.lookAt(position, position + root.CFrame.LookVector, FOLLOW_UP)
	return baseCFrame * facingCorrection
end

local function spawnPet(ownerUserId: number, eggName: string, petName: string)
	despawnPet(ownerUserId)

	local folder = petsAssets:FindFirstChild(eggName)
	if not folder then
		warn("[PetClient] Missing egg folder:", eggName)
		return
	end
	local src = folder:FindFirstChild(petName)
	if not src or not src:IsA("Model") then
		warn("[PetClient] Missing pet model:", petName, "in", eggName)
		return
	end

	local sourceFollowerRoot = getFollowerRoot(src)
	local sourceFacingAttachment = getFacingAttachment(sourceFollowerRoot)
	local facingCorrection = if sourceFacingAttachment
		then sourceFacingAttachment.CFrame:Inverse()
		elseif sourceFollowerRoot then CFrame.new()
		else getLegacyFacingOffset(src)
	if sourceFollowerRoot and src.PrimaryPart ~= sourceFollowerRoot then
		warn("[PetClient] Calibrated pet PrimaryPart was not FollowerRoot; repairing clone:", eggName, petName)
	end
	if sourceFollowerRoot and not sourceFacingAttachment then
		warn("[PetClient] Calibrated pet is missing FacingAttachment:", eggName, petName)
	end

	local model = src:Clone()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end

	local followerRoot = getFollowerRoot(model)
	if followerRoot then
		model.PrimaryPart = followerRoot
	elseif not model.PrimaryPart then
		local primary = model:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			model.PrimaryPart = primary
		end
	end
	if not model.PrimaryPart then
		warn("[PetClient] Pet model has no BasePart:", petName, "in", eggName)
		model:Destroy()
		return
	end

	pcall(function()
		model:ScaleTo(0.75)
	end)

	local root = getOwnerRoot(ownerUserId)
	if not root then
		-- Owner's character isn't ready yet (they may still be loading in). Wait briefly;
		-- if it never shows up, the model just starts at the origin until the next update.
		local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
		if ownerPlayer then
			task.spawn(function()
				local character = ownerPlayer.CharacterAdded:Wait()
				local hrp = character:WaitForChild("HumanoidRootPart", 10)
				if hrp and activePets[ownerUserId] and activePets[ownerUserId].model == model then
					model:PivotTo(computeFollowTarget(hrp, facingCorrection))
				end
			end)
		end
	else
		model:PivotTo(computeFollowTarget(root, facingCorrection))
	end

	model.Parent = workspace

	local connection = RunService.Heartbeat:Connect(function()
		if not model.Parent then
			return
		end
		local currentRoot = getOwnerRoot(ownerUserId)
		if not currentRoot then
			return
		end
		local pivot = model:GetPivot()
		local target = computeFollowTarget(currentRoot, facingCorrection)
		model:PivotTo(pivot:Lerp(target, 0.15))
	end)

	activePets[ownerUserId] = { model = model, connection = connection }
end

local petFollowUpdate = remotes:WaitForChild("PetFollowUpdate", 60)
if petFollowUpdate then
	petFollowUpdate.OnClientEvent:Connect(function(state)
		local ownerUserId = state.ownerUserId
		if typeof(ownerUserId) ~= "number" then
			return
		end
		if state.equipped and state.name and state.egg then
			spawnPet(ownerUserId, state.egg, state.name)
		else
			despawnPet(ownerUserId)
		end
	end)
end

Players.PlayerRemoving:Connect(function(leavingPlayer)
	despawnPet(leavingPlayer.UserId)
end)

local petRollResult = remotes:WaitForChild("PetRollResult", 60)
if petRollResult then
	petRollResult.OnClientEvent:Connect(function(result)
		if result.success and not panelOpen then
			showPetShopUI()
		end
	end)
end

