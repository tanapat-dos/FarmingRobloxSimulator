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
local activePetModel = nil
local followConnection = nil
local panelOpen = false
local uiReady = false

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

local function despawnPet()
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
	if activePetModel then
		activePetModel:Destroy()
		activePetModel = nil
	end
end

local function spawnPet(eggName, petName)
	despawnPet()

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

	local model = src:Clone()

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = false
		end
	end

	if not model.PrimaryPart then
		local primary = model:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			model.PrimaryPart = primary
		end
	end

	pcall(function()
		model:ScaleTo(0.75)
	end)

	local char = player.Character
	if not char then
		char = player.CharacterAdded:Wait()
	end
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if hrp then
		model:PivotTo(hrp.CFrame * CFrame.new(2.5, 0, 0))
	end

	model.Parent = workspace
	activePetModel = model

	followConnection = RunService.Heartbeat:Connect(function()
		if not activePetModel or not activePetModel.Parent then
			return
		end
		local character = player.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local pivot = activePetModel:GetPivot()
		local target = root.CFrame * CFrame.new(2.5, 0, 0)
		activePetModel:PivotTo(pivot:Lerp(target, 0.15))
	end)
end

local petFollowUpdate = remotes:WaitForChild("PetFollowUpdate", 60)
if petFollowUpdate then
	petFollowUpdate.OnClientEvent:Connect(function(state)
		if state.equipped and state.name and state.egg then
			spawnPet(state.egg, state.name)
		else
			despawnPet()
		end
	end)
end

local petRollResult = remotes:WaitForChild("PetRollResult", 60)
if petRollResult then
	petRollResult.OnClientEvent:Connect(function(result)
		if result.success and not panelOpen then
			showPetShopUI()
		end
	end)
end

player.CharacterAdded:Connect(function()
	if activePetModel then
		task.wait(0.5)
	end
end)
