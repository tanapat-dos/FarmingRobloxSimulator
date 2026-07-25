--[[
	FishCoinShopClient — "Fish Coin Shop" panel for crops bought with 🐟
	Fish Coins (earned from fishing) instead of Cash.

	Opened via the "Fish Shop" button in the left menu bar (MenuBarClient),
	same toggle-Panel.Visible pattern as PetMenuClient/Achievements/Daily
	Login. Offer list comes from FishCoinShopService's ResetFishCoinShop
	remote — server is always the source of truth for price.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local buyRemote = remotes:WaitForChild("BuyFishCoinItem")
local resetRemote = remotes:WaitForChild("ResetFishCoinShop")

local CloseIconUi = require(ReplicatedStorage:WaitForChild("Modules").CloseIconUi)
local SeedRarityColors = require(ReplicatedStorage:WaitForChild("Modules").SeedRarity)

local COLORS = {
	panel = Color3.fromRGB(20, 26, 38),
	header = Color3.fromRGB(28, 36, 52),
	row = Color3.fromRGB(34, 42, 58),
	rowLocked = Color3.fromRGB(26, 30, 40),
	text = Color3.fromRGB(235, 240, 250),
	subtext = Color3.fromRGB(170, 180, 198),
	coin = Color3.fromRGB(255, 210, 90),
	accent = Color3.fromRGB(90, 190, 220),
	locked = Color3.fromRGB(120, 128, 145),
	close = Color3.fromRGB(210, 90, 90),
}

-- Compact number for gate progress, e.g. 15000000 -> "15M", 340000 -> "340K"
local function abbreviate(n: number): string
	if n >= 1e9 then
		return ("%.3gB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.3gM"):format(n / 1e6)
	elseif n >= 1e3 then
		return ("%.3gK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

--[[
	Turns the server's UnlockProgress list into one line, showing the first unmet gate:
	  "$340K / $2M earned"  or  "312 / 500 fruits harvested"
]]
local function formatUnlockProgress(progress: { any }?): string?
	if not progress then
		return nil
	end
	for _, gate in progress do
		if not gate.met then
			local prefix = if gate.stat == "TotalEarned" then "$" else ""
			return ("%s%s / %s%s %s"):format(
				prefix, abbreviate(gate.have),
				prefix, abbreviate(gate.goal),
				gate.label or "")
		end
	end
	return nil
end

local gui: ScreenGui
local panel: Frame
local listFrame: ScrollingFrame
local balanceLabel: TextLabel
local currentOffers: { [string]: any } = {}

local function corner(instance: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function refreshBalanceLabel()
	if not balanceLabel then
		return
	end
	local amount = player:GetAttribute("FishCoins") or 0
	balanceLabel.Text = ("🐟 %d Fish Coins"):format(amount)
end

local function buildOfferRow(seedName: string, offer: any, layoutOrder: number): Frame
	local row = Instance.new("Frame")
	row.Name = seedName
	row.Size = UDim2.new(1, -6, 0, 70)
	row.BackgroundColor3 = COLORS.row
	row.LayoutOrder = layoutOrder
	corner(row, 10)

	local rarityBar = Instance.new("Frame")
	rarityBar.Size = UDim2.new(0, 4, 1, -12)
	rarityBar.Position = UDim2.fromOffset(6, 6)
	rarityBar.BorderSizePixel = 0
	rarityBar.Parent = row
	corner(rarityBar, 2)
	local rarityStyle = SeedRarityColors[offer.Rarity]
	if typeof(rarityStyle) == "Color3" then
		rarityBar.BackgroundColor3 = rarityStyle
	else
		rarityBar.BackgroundColor3 = COLORS.subtext
	end

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(18, 8)
	title.Size = UDim2.new(1, -140, 0, 22)
	title.BackgroundTransparency = 1
	title.Text = offer.Name or seedName
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.Parent = row

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Position = UDim2.fromOffset(18, 32)
	rarityLabel.Size = UDim2.new(1, -140, 0, 18)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = offer.Rarity or "Epic"
	rarityLabel.TextColor3 = COLORS.subtext
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextSize = 13
	rarityLabel.Parent = row

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(118, 38)
	button.TextColor3 = COLORS.text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.Parent = row
	corner(button, 8)

	if offer.Locked then
		-- Tier-locked: show the requirement instead of a price, and don't fire the remote
		-- (the server rejects it anyway).
		row.BackgroundColor3 = COLORS.rowLocked
		button.BackgroundColor3 = COLORS.locked
		button.Text = "🔒 Locked"
		button.AutoButtonColor = false
		title.TextColor3 = COLORS.subtext

		rarityLabel.Text = formatUnlockProgress(offer.UnlockProgress) or "Locked"
		rarityLabel.TextColor3 = COLORS.locked
	else
		button.BackgroundColor3 = COLORS.accent
		button.Text = ("🐟 %d"):format(offer.Price or 0)
		button.MouseButton1Click:Connect(function()
			buyRemote:FireServer(seedName)
		end)
	end

	return row
end

local function renderOffers()
	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local ordered = {}
	for seedName, offer in currentOffers do
		table.insert(ordered, { seedName = seedName, offer = offer })
	end
	table.sort(ordered, function(a, b)
		return (a.offer.LayoutOrder or 0) < (b.offer.LayoutOrder or 0)
	end)

	if #ordered == 0 then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1, -6, 0, 70)
		empty.BackgroundTransparency = 1
		empty.Parent = listFrame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "No items in stock right now — check back later!"
		label.TextWrapped = true
		label.TextColor3 = COLORS.subtext
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.Parent = empty
		return
	end

	for index, entry in ordered do
		buildOfferRow(entry.seedName, entry.offer, index).Parent = listFrame
	end
end

local function buildUi()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "FishCoinShopGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(410, 450)
	panel.BackgroundColor3 = COLORS.panel
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(12, 15, 22)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, 0, 60)
	headerBar.BackgroundColor3 = COLORS.header
	headerBar.Parent = panel
	corner(headerBar, 14)

	local headerFill = Instance.new("Frame")
	headerFill.Size = UDim2.new(1, 0, 0.5, 0)
	headerFill.Position = UDim2.fromScale(0, 0.5)
	headerFill.BackgroundColor3 = COLORS.header
	headerFill.BorderSizePixel = 0
	headerFill.Parent = headerBar

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 4)
	title.Size = UDim2.new(1, -60, 0, 22)
	title.BackgroundTransparency = 1
	title.Text = "🎣 Fish Coin Shop"
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.Parent = headerBar

	balanceLabel = Instance.new("TextLabel")
	balanceLabel.Position = UDim2.fromOffset(16, 30)
	balanceLabel.Size = UDim2.new(1, -60, 0, 20)
	balanceLabel.BackgroundTransparency = 1
	balanceLabel.Text = "🐟 0 Fish Coins"
	balanceLabel.TextColor3 = COLORS.coin
	balanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	balanceLabel.Font = Enum.Font.GothamBold
	balanceLabel.TextSize = 13
	balanceLabel.Parent = headerBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.BackgroundColor3 = COLORS.close
	closeBtn.Text = ""
	closeBtn.Parent = headerBar
	corner(closeBtn, 8)
	CloseIconUi.build(closeBtn, { color = COLORS.text })
	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "List"
	listFrame.Position = UDim2.fromOffset(12, 76)
	listFrame.Size = UDim2.new(1, -24, 1, -88)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.new()
	listFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listFrame

	refreshBalanceLabel()
end

resetRemote.OnClientEvent:Connect(function(offers)
	buildUi()
	if typeof(offers) == "table" then
		currentOffers = offers
		renderOffers()
	end
end)

player:GetAttributeChangedSignal("FishCoins"):Connect(refreshBalanceLabel)

buildUi()
