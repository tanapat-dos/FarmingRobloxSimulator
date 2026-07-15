--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")

--// Pet Shop signal - resolved lazily so we never block at startup
local function firePetShopOpen()
	local cs = ReplicatedStorage:FindFirstChild("ClientSignals")
	if cs then
		local toggle = cs:FindFirstChild("TogglePetShop")
		if toggle then toggle:Fire("open") end
	end
end

local function fireCropPriceBoardOpen()
	local cs = ReplicatedStorage:FindFirstChild("ClientSignals")
	if cs then
		local toggle = cs:FindFirstChild("ToggleCropPriceBoard")
		if toggle then toggle:Fire("open") end
	end
end

--// Assets
local DialogueTemplate = ReplicatedStorage:WaitForChild("DialogueGUI")
local SellDisplay = ReplicatedStorage:WaitForChild("SellGUI")
local dialogueSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Typing")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local NavigationHudState = require(ReplicatedStorage:WaitForChild("Modules").NavigationHudState)

--// Player
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

--// State
local activeUI = {
	SellGUI = nil,
	SellAnchor = nil,
	NPCDialogue = nil,
	PlayerDialogue = nil,
	Highlight = nil
}

local currentNPC = nil

--// Utility: Typing Text
local function typeTextRich(label, fullText, delayPerLetter)
	label.RichText = true
	label.Text = ""
	dialogueSound:Stop()
	dialogueSound:Play()

	local splitStart = fullText:find("<font")
	if not splitStart then
		for i = 1, #fullText do
			label.Text = string.sub(fullText, 1, i)
			task.wait(delayPerLetter)
		end
		dialogueSound:Stop()
		return
	end

	local baseText = string.sub(fullText, 1, splitStart - 1)
	local richText = string.sub(fullText, splitStart)

	for i = 1, #baseText do
		label.Text = string.sub(baseText, 1, i)
		task.wait(delayPerLetter)
	end

	label.Text = baseText .. richText
	dialogueSound:Stop()
end


--// Toggle Prompts
local function toggleAllPrompts(enable)
	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = enable
		end
	end
end

--// Dialogue
local Dialogue = {}

function Dialogue:NPC(model, text)
	if activeUI.NPCDialogue then activeUI.NPCDialogue:Destroy() end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then return end

	local gui = DialogueTemplate:Clone()
	gui.Adornee = root
	gui.Parent = model
	gui.Enabled = true
	-- Keep the bubble readable: render above world geometry and just over
	-- the NPC's head so shop roofs never clip or occlude it.
	gui.AlwaysOnTop = true
	gui.StudsOffset = Vector3.new(0, 3, 0)

	local frame = gui:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChildWhichIsA("TextLabel")
	if label then typeTextRich(label, text, 0.05) end
	activeUI.NPCDialogue = gui
end

function Dialogue:Player(text)
	if activeUI.PlayerDialogue then activeUI.PlayerDialogue:Destroy() end

	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if not root then return end

	local gui = DialogueTemplate:Clone()
	gui.Adornee = root
	gui.Parent = player:WaitForChild("PlayerGui")
	gui.Enabled = true
	gui.AlwaysOnTop = true
	gui.StudsOffset = Vector3.new(0, 2.6, 0)

	local frame = gui:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChildWhichIsA("TextLabel")
	if label then typeTextRich(label, text, 0.05) end

	activeUI.PlayerDialogue = gui
	task.delay(2.5, function()
		if gui == activeUI.PlayerDialogue then
			gui:Destroy()
			activeUI.PlayerDialogue = nil
		end
	end)
end

function Dialogue:HideAll()
	if activeUI.NPCDialogue then activeUI.NPCDialogue:Destroy() activeUI.NPCDialogue = nil end
	if activeUI.PlayerDialogue then activeUI.PlayerDialogue:Destroy() activeUI.PlayerDialogue = nil end
end

--// Hover Effect
local function addHoverEffect(button)
	local originalSize = button.Size
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, tweenInfo, {
			Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, originalSize.Y.Scale, originalSize.Y.Offset + 10)
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, tweenInfo, {
			Size = originalSize
		}):Play()
	end)
end

--// Highlight
local function highlightModel(model)
	if activeUI.Highlight then activeUI.Highlight:Destroy() end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.new(1,1,1)
	hl.Adornee = model
	hl.Parent = model
	activeUI.Highlight = hl
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	local model = prompt.Parent.Parent
	if model and model:IsA("Model") then
		highlightModel(model)
	end
	
	if prompt.Name == "HarvestPrompt" then
		local correspondingModel: ObjectValue = prompt:FindFirstChild("CorrespondingAdornee")
		if correspondingModel then
			script.Highlight.Adornee = correspondingModel.Value
		end
	end
	
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if activeUI.Highlight then
		activeUI.Highlight:Destroy()
		activeUI.Highlight = nil
	end
	
	if prompt.Name == "HarvestPrompt" then
		script.Highlight.Adornee = nil
	end
	
end)

--// Shop GUI
local ShopScreenGui = PlayerGui:WaitForChild("Shop")
local ShopUI = ShopScreenGui:WaitForChild("Frame")
local closeShopBtn = ShopUI:WaitForChild("CloseShop")
local mainButtons = PlayerGui:WaitForChild("Main"):WaitForChild("Buttons")
local blur = game.Lighting:WaitForChild("Blur")

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
	TweenService:Create(blur, TweenInfo.new(0.3), {Size = enable and 15 or 0}):Play()
end

local function showShopUI()
	ShopScreenGui.DisplayOrder = 10
	pcall(setHudButtonsVisible, false)
	ShopUI.Size = UDim2.new(0,0,0,0)
	ShopUI.Visible = true
	toggleBlur(true)
	TweenService:Create(ShopUI, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0.414, 0, 0.8, 0)}):Play()
end

local function hideShopUI()
	TweenService:Create(ShopUI, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
	toggleBlur(false)
	task.delay(0.2, function()
		ShopUI.Visible = false
		pcall(setHudButtonsVisible, true)
	end)
end

closeShopBtn.MouseButton1Click:Connect(hideShopUI)

--// response
local function respondAfter(seconds, message, reenablePrompts)
	if currentNPC then
		task.delay(seconds, function()
			Dialogue:NPC(currentNPC, message)
			task.delay(2, function()
				Dialogue:HideAll()
				if reenablePrompts then
					toggleAllPrompts(true)
				end
			end)
		end)
	end
end

--// World Facing Billboard Setup

local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local function createAnchorPart()
	local part = Instance.new("Part")
	part.Name = "SellAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 1
	part.Parent = workspace
	return part
end

local function createSellGUI()
	hideSellGUI()

	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")

	local anchor = createAnchorPart()
	anchor.Position = hrp.Position + Vector3.new(-0.5, 0.5, 0)

	local connection
	connection = RunService.RenderStepped:Connect(function()
		if activeUI.SellGUI and anchor and anchor.Parent and hrp and hrp.Parent then
			anchor.Position = hrp.Position + Vector3.new(-0.5, 0.5, 0)
			anchor.CFrame = CFrame.new(anchor.Position, Camera.CFrame.Position)
		else
			if connection then connection:Disconnect() end
		end
	end)

	local gui = SellDisplay:Clone()
	gui.Adornee = anchor
	gui.Parent = PlayerGui
	gui.Enabled = true
	activeUI.SellGUI = gui
	activeUI.SellAnchor = anchor

	local frame = gui:WaitForChild("Frame")
	local sellInventoryBtn = frame:FindFirstChild("SellInventory")
	if sellInventoryBtn then
		sellInventoryBtn:Destroy()
	end

	local buttons = {
		SellItem = function()
			hideSellGUI()
			Dialogue:Player("I want to sell this item")
			
			local result = remotes.Sell:InvokeServer("itemSell")

			if result and result.success ~= nil then
				respondAfter(0.5, result.msg, true)
			else
				respondAfter(1.5, "Something went wrong with selling.", true)
			end

		end,

		HowMuch = function()
			hideSellGUI()
			Dialogue:Player("How much is this worth?")
			
			local result = remotes.Sell:InvokeServer("howMuch")

			if result and result.success ~= nil then
				respondAfter(0.5, result.msg, true)
			else
				respondAfter(1.5, "Oops try again.", true)
			end	
			
		end,

		Cancel = function()
			hideSellGUI()
			Dialogue:Player("Nevermind")
			respondAfter(1.5, "Goodbye!", true)
		end,

		PriceGuide = function()
			hideSellGUI()
			Dialogue:Player("Show me crop sell prices")
			respondAfter(0.5, "Here's what each crop sells for.", true)
			fireCropPriceBoardOpen()
		end,
	}

	for name, callback in pairs(buttons) do
		local btn = frame:FindFirstChild(name)
		if btn then
			addHoverEffect(btn)
			btn.MouseButton1Click:Connect(callback)
		end
	end

	if not frame:FindFirstChild("PriceGuide") then
		local cancelBtn = frame:FindFirstChild("Cancel")
		local templateBtn = frame:FindFirstChild("HowMuch") or cancelBtn
		if templateBtn and templateBtn:IsA("GuiObject") then
			local priceGuideBtn = templateBtn:Clone()
			priceGuideBtn.Name = "PriceGuide"
			if priceGuideBtn:IsA("TextButton") then
				priceGuideBtn.Text = "Price Guide"
			end
			priceGuideBtn.LayoutOrder = (templateBtn :: GuiObject).LayoutOrder + 1
			priceGuideBtn.Parent = frame
			addHoverEffect(priceGuideBtn)
			priceGuideBtn.MouseButton1Click:Connect(buttons.PriceGuide)
		end
	end
end

function hideSellGUI()
	if activeUI.SellGUI then
		activeUI.SellGUI:Destroy()
		activeUI.SellGUI = nil
	end

	if activeUI.SellAnchor then
		activeUI.SellAnchor:Destroy()
		activeUI.SellAnchor = nil
	end
end

--// Prompt Logic
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
	if triggeredPlayer ~= player then return end

	toggleAllPrompts(false)

	if prompt.Name == "OpenShop" then
		local npc = prompt.Parent.Parent
		Dialogue:NPC(npc, "Here are the shop seeds currently:")
		task.delay(1.5, function()
			Dialogue:HideAll()
			showShopUI()
			closeShopBtn.MouseButton1Click:Once(function()
				toggleAllPrompts(true)
			end)
		end)
	elseif prompt.Name == "SellShop" then
		local npc = prompt.Parent.Parent
		currentNPC = npc
		Dialogue:NPC(npc, "Got anything to sell?")
		task.delay(1.5, function()
			Dialogue:HideAll()
			createSellGUI()
		end)
	elseif prompt.Name == "OpenPetShop" then
		local npc = prompt.Parent.Parent
		Dialogue:NPC(npc, "Looking for a pet? Roll for your companion! \xF0\x9F\x90\xBE")
		task.delay(1.5, function()
			Dialogue:HideAll()
			firePetShopOpen()
			task.delay(0.5, function()
				toggleAllPrompts(true)
			end)
		end)
	elseif prompt.Name == "CropPriceBoard" then
		fireCropPriceBoardOpen()
		task.delay(0.5, function()
			toggleAllPrompts(true)
		end)
	end
	
	if prompt.Name == "HarvestPrompt" then
		toggleAllPrompts(true)
		local part = prompt.Parent
		if part and part.Parent and part.Parent.Name == "FruitPrompts" then
			local plantKey : string = part.Parent.Parent.Name
			local fruitNumber = part.Name
			
			remotes.Harvest:FireServer(plantKey,fruitNumber)
		else
			local plantKey = part.Parent.Name
			remotes.Harvest:FireServer(plantKey)
		end
	end
	
end)
