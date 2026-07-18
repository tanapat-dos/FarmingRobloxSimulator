--[[
	LegendaryEggClient — diamond-only Legendary egg panel.

	Opens from the Legendary Egg stand. Shows the Divine (Legendary) egg, the
	player's live diamond balance, a roll button (spends Diamonds via the
	server), and a "Get Diamonds" button that prompts the Robux dev product.
	View + request layer only; PetService validates and grants the pet.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local modules = ReplicatedStorage:WaitForChild("Modules")

local EconomyBalance = require(modules.EconomyBalance)
local Monetization = require(modules.Monetization)

local legendaryRemote = remotes:WaitForChild("LegendaryEgg")
local petRollResult = remotes:WaitForChild("PetRollResult")

local LEGENDARY_EGG = "Divine Egg"
local eggData = EconomyBalance.EGGS[LEGENDARY_EGG]
local DIAMOND_COST = (eggData and eggData.diamondCost) or 100
local BOOST_TEXT = EconomyBalance.formatEggBoostRange(LEGENDARY_EGG)

local COLORS = {
	panel = Color3.fromRGB(26, 28, 44),
	panelTop = Color3.fromRGB(40, 36, 66),
	card = Color3.fromRGB(38, 40, 62),
	text = Color3.fromRGB(238, 240, 252),
	subtext = Color3.fromRGB(180, 184, 210),
	diamond = Color3.fromRGB(120, 210, 255),
	legendary = Color3.fromRGB(255, 196, 90),
	roll = Color3.fromRGB(150, 120, 255),
	rollDark = Color3.fromRGB(104, 82, 190),
	buy = Color3.fromRGB(88, 202, 110),
	close = Color3.fromRGB(214, 92, 92),
}

local gui: ScreenGui? = nil
local balanceLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil

local function corner(instance: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function stroke(instance: Instance, color: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = instance
end

local function formatMoney(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function currentDiamonds(): number
	local amount = player:GetAttribute("Diamonds")
	return typeof(amount) == "number" and amount or 0
end

local function refreshBalance()
	if balanceLabel then
		balanceLabel.Text = ("💎 %s"):format(formatMoney(currentDiamonds()))
	end
end

local function promptBuyDiamonds()
	local id = Monetization.DevProducts.Diamonds100
	if typeof(id) == "number" and id > 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	elseif statusLabel then
		statusLabel.Text = "Diamond pack isn't configured yet."
		statusLabel.TextColor3 = Color3.fromRGB(238, 150, 140)
	end
end

local function buildPanel()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "LegendaryEggGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 500)
	panel.BackgroundColor3 = COLORS.panel
	panel.Parent = gui
	corner(panel, 20)
	stroke(panel, Color3.fromRGB(14, 14, 24), 2, 0.2)

	-- Header
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -60, 0, 56)
	header.Position = UDim2.fromOffset(22, 8)
	header.BackgroundTransparency = 1
	header.Text = "✨ Legendary Egg"
	header.TextColor3 = COLORS.legendary
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Font = Enum.Font.GothamBold
	header.TextSize = 26
	header.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(38, 38)
	closeButton.BackgroundColor3 = COLORS.close
	closeButton.Text = "✕"
	closeButton.TextColor3 = COLORS.text
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.Parent = panel
	corner(closeButton, 10)
	closeButton.MouseButton1Click:Connect(function()
		if gui then
			gui.Enabled = false
		end
	end)

	-- Balance pill
	balanceLabel = Instance.new("TextLabel")
	balanceLabel.AnchorPoint = Vector2.new(1, 0)
	balanceLabel.Position = UDim2.new(1, -60, 0, 20)
	balanceLabel.Size = UDim2.fromOffset(120, 30)
	balanceLabel.BackgroundColor3 = COLORS.panelTop
	balanceLabel.Text = "💎 0"
	balanceLabel.TextColor3 = COLORS.diamond
	balanceLabel.Font = Enum.Font.GothamBold
	balanceLabel.TextSize = 18
	balanceLabel.Parent = panel
	corner(balanceLabel, 15)

	-- Egg card
	local card = Instance.new("Frame")
	card.Position = UDim2.fromOffset(22, 74)
	card.Size = UDim2.new(1, -44, 0, 300)
	card.BackgroundColor3 = COLORS.card
	card.Parent = panel
	corner(card, 16)
	stroke(card, COLORS.legendary, 2, 0.35)

	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0.06)
	badge.Size = UDim2.fromOffset(140, 140)
	badge.BackgroundColor3 = COLORS.roll
	badge.Parent = card
	corner(badge, 70)
	stroke(badge, Color3.fromRGB(255, 255, 255), 3, 0.5)

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Text = "🥚"
	icon.TextColor3 = COLORS.text
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 76
	icon.Parent = badge

	local rarity = Instance.new("TextLabel")
	rarity.AnchorPoint = Vector2.new(0.5, 0)
	rarity.Position = UDim2.fromScale(0.5, 0.56)
	rarity.Size = UDim2.new(1, 0, 0, 26)
	rarity.BackgroundTransparency = 1
	rarity.Text = "LEGENDARY"
	rarity.TextColor3 = COLORS.legendary
	rarity.Font = Enum.Font.GothamBold
	rarity.TextSize = 20
	rarity.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.fromScale(0.5, 0.68)
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = LEGENDARY_EGG
	nameLabel.TextColor3 = COLORS.text
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 22
	nameLabel.Parent = card

	local boost = Instance.new("TextLabel")
	boost.AnchorPoint = Vector2.new(0.5, 0)
	boost.Position = UDim2.fromScale(0.5, 0.82)
	boost.Size = UDim2.new(1, 0, 0, 24)
	boost.BackgroundTransparency = 1
	boost.Text = ("Cash Boost %s  •  Divine pets"):format(BOOST_TEXT)
	boost.TextColor3 = COLORS.subtext
	boost.Font = Enum.Font.GothamMedium
	boost.TextSize = 15
	boost.Parent = card

	-- Roll button
	local rollButton = Instance.new("TextButton")
	rollButton.Position = UDim2.fromOffset(22, 388)
	rollButton.Size = UDim2.new(1, -44, 0, 50)
	rollButton.BackgroundColor3 = COLORS.roll
	rollButton.Text = ("Roll  •  💎 %d"):format(DIAMOND_COST)
	rollButton.TextColor3 = COLORS.text
	rollButton.Font = Enum.Font.GothamBold
	rollButton.TextSize = 20
	rollButton.Parent = panel
	corner(rollButton, 12)
	stroke(rollButton, COLORS.rollDark, 2, 0.1)
	rollButton.MouseButton1Click:Connect(function()
		if currentDiamonds() < DIAMOND_COST then
			if statusLabel then
				statusLabel.Text = "Not enough diamonds — get more below!"
				statusLabel.TextColor3 = Color3.fromRGB(238, 150, 140)
			end
			return
		end
		legendaryRemote:FireServer("roll")
	end)

	-- Get diamonds button
	local buyButton = Instance.new("TextButton")
	buyButton.Position = UDim2.fromOffset(22, 444)
	buyButton.Size = UDim2.new(1, -44, 0, 34)
	buyButton.BackgroundColor3 = COLORS.buy
	buyButton.Text = "＋ Get Diamonds  (100💎 · $0.99)"
	buyButton.TextColor3 = COLORS.text
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 15
	buyButton.Parent = panel
	corner(buyButton, 10)
	buyButton.MouseButton1Click:Connect(promptBuyDiamonds)

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.AnchorPoint = Vector2.new(0.5, 1)
	statusLabel.Position = UDim2.new(0.5, 0, 1, -6)
	statusLabel.Size = UDim2.new(1, -44, 0, 18)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = COLORS.subtext
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 13
	statusLabel.Parent = panel

	refreshBalance()
end

player:GetAttributeChangedSignal("Diamonds"):Connect(refreshBalance)

legendaryRemote.OnClientEvent:Connect(function(action)
	if action == "open" then
		buildPanel()
		refreshBalance()
		if gui then
			gui.Enabled = true
		end
	end
end)

-- Surface roll failures (e.g. not enough diamonds) in the panel.
petRollResult.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" or result.success then
		return
	end
	if statusLabel and gui and gui.Enabled then
		statusLabel.Text = result.msg or "Roll failed."
		statusLabel.TextColor3 = Color3.fromRGB(238, 150, 140)
	end
end)
