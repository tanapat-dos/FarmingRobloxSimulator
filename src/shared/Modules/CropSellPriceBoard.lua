--!strict
-- Crop sell leaderboard data and sign UI layout.

local EconomyBalance = require(script.Parent.EconomyBalance)
local HarvestRarityConfig = require(script.Parent.HarvestRarityConfig)

export type BestSaleRecord = {
	PlayerName: string,
	UserId: number,
	CropName: string,
	Weight: number,
	Rarity: string,
	SellPrice: number,
}

export type LeaderboardEntry = {
	Rank: number,
	PlayerName: string,
	CropName: string,
	Weight: number,
	Rarity: string,
	SeedRarity: string,
	SellPrice: number,
	LayoutOrder: number,
}

local CropSellPriceBoard = {}

local REFERENCE_WEIGHT = 1
local REFERENCE_HARVEST_RARITY = "Common"
local EMPTY_PLAYER = "—"

CropSellPriceBoard.COLUMNS = {
	{ name = "Rank", width = 0.10, align = Enum.TextXAlignment.Center },
	{ name = "Player", width = 0.30, align = Enum.TextXAlignment.Left },
	{ name = "Crop", width = 0.26, align = Enum.TextXAlignment.Left },
	{ name = "Weight", width = 0.16, align = Enum.TextXAlignment.Center },
	{ name = "Price", width = 0.18, align = Enum.TextXAlignment.Right },
}

local SIGN_ROW_HEIGHT_SCALE = 0.095

local function seedNameToCrop(seedName: string): string
	return seedName:gsub(" Seed$", "")
end

local function computeReferenceSellPrice(baseValue: number): number
	local rarityMultiplier = HarvestRarityConfig.getMultiplier(REFERENCE_HARVEST_RARITY)
	return math.floor(baseValue * REFERENCE_WEIGHT * REFERENCE_WEIGHT * rarityMultiplier)
end

function CropSellPriceBoard.getDisplayEntries(bestByCrop: { [string]: BestSaleRecord }?): { LeaderboardEntry }
	local entries: { LeaderboardEntry } = {}

	for seedName, cfg in EconomyBalance.CROPS do
		local cropName = seedNameToCrop(seedName)
		local best = bestByCrop and bestByCrop[cropName]
		table.insert(entries, {
			Rank = 0,
			PlayerName = if best then best.PlayerName else EMPTY_PLAYER,
			CropName = cropName,
			Weight = if best then best.Weight else REFERENCE_WEIGHT,
			Rarity = if best then best.Rarity else REFERENCE_HARVEST_RARITY,
			SeedRarity = cfg.rarity,
			SellPrice = if best then best.SellPrice else computeReferenceSellPrice(cfg.baseValue),
			LayoutOrder = 0,
		})
	end

	table.sort(entries, function(a, b)
		if a.SellPrice ~= b.SellPrice then
			return a.SellPrice > b.SellPrice
		end
		return a.CropName < b.CropName
	end)

	for index, entry in entries do
		entry.Rank = index
		entry.LayoutOrder = index
	end

	return entries
end

function CropSellPriceBoard.formatMoney(amount: number): string
	if amount >= 1000 then
		return string.format("$%0.0f", amount)
	end
	if math.floor(amount) == amount then
		return "$" .. tostring(amount)
	end
	return string.format("$%.2f", amount)
end

function CropSellPriceBoard.formatWeight(weight: number): string
	return string.format("%.1f kg", weight)
end

function CropSellPriceBoard.getSignCFrame(signPosition: Vector3, viewTarget: Vector3): CFrame
	-- Upright sign; yaw only so Front (+Z) faces the shop plaza at ground level.
	local flatTarget = Vector3.new(viewTarget.X, signPosition.Y, viewTarget.Z)
	local direction = flatTarget - signPosition
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end
	local yaw = math.atan2(direction.X, direction.Z)
	return CFrame.new(signPosition) * CFrame.Angles(0, yaw, 0)
end

local function getColumnOffset(index: number): number
	local offset = 0
	for i = 1, index - 1 do
		offset += CropSellPriceBoard.COLUMNS[i].width
	end
	return offset
end

local function createLabel(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	textSize: number,
	align: Enum.TextXAlignment,
	color: Color3?,
	bold: boolean?,
	textScaled: boolean?,
	maxTextSize: number?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextSize = textSize
	label.TextColor3 = color or Color3.fromRGB(245, 245, 245)
	label.TextXAlignment = align
	label.Text = text
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextScaled = textScaled == true
	if textScaled and maxTextSize then
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = maxTextSize
		constraint.MinTextSize = math.max(8, math.floor(maxTextSize * 0.45))
		constraint.Parent = label
	end
	label.Parent = parent
	return label
end

function CropSellPriceBoard.populateSignGui(signPart: BasePart, entries: { LeaderboardEntry })
	local existingGui = signPart:FindFirstChild("BoardGui")
	if existingGui then
		existingGui:Destroy()
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "BoardGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = signPart

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(24, 34, 24)
	root.BorderSizePixel = 0
	root.Parent = surfaceGui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.02, 0)
	padding.PaddingBottom = UDim.new(0.02, 0)
	padding.PaddingLeft = UDim.new(0.02, 0)
	padding.PaddingRight = UDim.new(0.02, 0)
	padding.Parent = root

	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(72, 110, 72)
	border.Thickness = 3
	border.Parent = root

	createLabel(
		root,
		"Title",
		"Crop Sell Leaderboard",
		UDim2.fromScale(1, 0.14),
		UDim2.fromScale(0, 0),
		48,
		Enum.TextXAlignment.Center,
		Color3.fromRGB(240, 240, 240),
		true,
		true,
		160
	)
	createLabel(
		root,
		"Subtitle",
		"Best sale per crop · Player · Weight · Price",
		UDim2.fromScale(1, 0.06),
		UDim2.fromScale(0, 0.14),
		24,
		Enum.TextXAlignment.Center,
		Color3.fromRGB(170, 190, 170),
		false,
		true,
		72
	)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, 0.08)
	header.Position = UDim2.fromScale(0, 0.21)
	header.BackgroundColor3 = Color3.fromRGB(18, 28, 18)
	header.BorderSizePixel = 0
	header.Parent = root
	Instance.new("UICorner", header).CornerRadius = UDim.new(0.08, 0)

	for index, column in CropSellPriceBoard.COLUMNS do
		createLabel(
			header,
			column.name,
			column.name,
			UDim2.new(column.width, -0.01, 1, 0),
			UDim2.new(getColumnOffset(index), 0.005, 0, 0),
			20,
			column.align,
			Color3.fromRGB(180, 200, 180),
			true,
			true,
			80
		)
	end

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "List"
	scrollFrame.Size = UDim2.fromScale(1, 0.69)
	scrollFrame.Position = UDim2.fromScale(0, 0.30)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 12
	scrollFrame.CanvasSize = UDim2.new()
	scrollFrame.Parent = root

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0.008, 0)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollFrame

	CropSellPriceBoard.renderSignRows(scrollFrame, entries)

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
	end)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
end

function CropSellPriceBoard.renderSignRows(scrollFrame: ScrollingFrame, entries: { LeaderboardEntry })
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local function getRowHeight(): number
		return math.max(48, math.floor(scrollFrame.AbsoluteSize.Y * SIGN_ROW_HEIGHT_SCALE))
	end

	local function refreshRowHeights()
		local rowHeight = getRowHeight()
		for _, child in scrollFrame:GetChildren() do
			if child:IsA("Frame") then
				child.Size = UDim2.new(1, 0, 0, rowHeight)
			end
		end
	end

	for _, entry in entries do
		local row = Instance.new("Frame")
		row.Name = entry.CropName
		row.Size = UDim2.new(1, 0, 0, getRowHeight())
		row.BackgroundColor3 = if entry.Rank % 2 == 0
			then Color3.fromRGB(34, 48, 34)
			else Color3.fromRGB(28, 40, 28)
		row.BorderSizePixel = 0
		row.LayoutOrder = entry.LayoutOrder
		row.Parent = scrollFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0.12, 0)

		local hasPlayer = entry.PlayerName ~= EMPTY_PLAYER
		local values = {
			"#" .. tostring(entry.Rank),
			entry.PlayerName,
			entry.CropName,
			CropSellPriceBoard.formatWeight(entry.Weight),
			CropSellPriceBoard.formatMoney(entry.SellPrice),
		}

		for index, column in CropSellPriceBoard.COLUMNS do
			local text = values[index]
			local color = if index == 1
				then (if entry.Rank <= 3 then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(255, 255, 255))
				elseif index == 2 then (if hasPlayer then Color3.fromRGB(170, 220, 255) else Color3.fromRGB(140, 140, 140))
				elseif index == 5 then Color3.fromRGB(130, 230, 130)
				else Color3.fromRGB(255, 255, 255)

			createLabel(
				row,
				column.name,
				text,
				UDim2.new(column.width, -0.01, 1, 0),
				UDim2.new(getColumnOffset(index), 0.005, 0, 0),
				18,
				column.align,
				color,
				index == 2 or index == 3 or index == 5,
				true,
				if index == 3 then 96 else 88
			)
		end
	end

	if not scrollFrame:GetAttribute("RowHeightHooked") then
		scrollFrame:SetAttribute("RowHeightHooked", true)
		scrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshRowHeights)
	end
end

function CropSellPriceBoard.renderRows(scrollFrame: ScrollingFrame, entries: { LeaderboardEntry }, rowHeight: number)
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "Header" then
			child:Destroy()
		end
	end

	for _, entry in entries do
		local row = Instance.new("Frame")
		row.Name = entry.CropName
		row.Size = UDim2.new(1, 0, 0, rowHeight)
		row.BackgroundColor3 = if entry.Rank % 2 == 0
			then Color3.fromRGB(34, 48, 34)
			else Color3.fromRGB(28, 40, 28)
		row.BorderSizePixel = 0
		row.LayoutOrder = entry.LayoutOrder
		row.Parent = scrollFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local hasPlayer = entry.PlayerName ~= EMPTY_PLAYER
		local values = {
			"#" .. tostring(entry.Rank),
			entry.PlayerName,
			entry.CropName,
			CropSellPriceBoard.formatWeight(entry.Weight),
			CropSellPriceBoard.formatMoney(entry.SellPrice),
		}

		for index, column in CropSellPriceBoard.COLUMNS do
			local text = values[index]
			local color = if index == 1
				then (if entry.Rank <= 3 then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(255, 255, 255))
				elseif index == 2 then (if hasPlayer then Color3.fromRGB(170, 220, 255) else Color3.fromRGB(140, 140, 140))
				elseif index == 5 then Color3.fromRGB(130, 230, 130)
				else Color3.fromRGB(255, 255, 255)

			createLabel(
				row,
				column.name,
				text,
				UDim2.new(column.width, -4, 1, 0),
				UDim2.new(getColumnOffset(index), 2, 0, 0),
				if index == 3 then 20 else 17,
				column.align,
				color,
				index == 2 or index == 3 or index == 5
			)
		end
	end
end

return CropSellPriceBoard
