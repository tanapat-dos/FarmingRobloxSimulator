--[[
	AchievementClient — collection book panel for achievements.

	Opens via the 🏆 button in the menu bar. Displays all achievements
	grouped by category with progress bars, reward text, and a ✅ badge
	on completed + claimed ones. Server pushes full state; client is view-only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local achieveRemote = remotes:WaitForChild("Achievements")

local AchievementConfig = require(ReplicatedStorage:WaitForChild("Modules").AchievementConfig)

local COLORS = {
	panel      = Color3.fromRGB(20, 22, 34),
	header     = Color3.fromRGB(28, 32, 50),
	section    = Color3.fromRGB(26, 30, 44),
	card       = Color3.fromRGB(32, 36, 52),
	cardDone   = Color3.fromRGB(30, 52, 38),
	text       = Color3.fromRGB(235, 240, 252),
	subtext    = Color3.fromRGB(150, 158, 185),
	green      = Color3.fromRGB(88, 202, 110),
	greenDark  = Color3.fromRGB(58, 150, 78),
	gold       = Color3.fromRGB(255, 210, 80),
	diamond    = Color3.fromRGB(120, 210, 255),
	close      = Color3.fromRGB(214, 92, 92),
	barBg      = Color3.fromRGB(22, 26, 40),
	barFill    = Color3.fromRGB(88, 202, 110),
	barFillMax = Color3.fromRGB(255, 210, 80),
	stroke     = Color3.fromRGB(14, 16, 24),
}

local CAT_COLORS: { [string]: Color3 } = {}
for _, cat in AchievementConfig.CATEGORIES do
	local c = cat.color
	CAT_COLORS[cat.id] = Color3.fromRGB(c.r, c.g, c.b)
end

local gui: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil

local function corner(inst: GuiObject, r: number)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = inst
end
local function stroke(inst: GuiObject, col: Color3, th: number, tr: number?)
	local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = th; s.Transparency = tr or 0; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = inst
end

local function formatMoney(n: number): string
	local t = tostring(math.floor(n)); local f = t:reverse():gsub("(%d%d%d)", "%1,"):reverse(); return f:gsub("^,", "")
end

local function buildPanel()
	if gui then return end

	gui = Instance.new("ScreenGui")
	gui.Name = "AchievementGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 11
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(620, 580)
	panel.BackgroundColor3 = COLORS.panel
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, COLORS.stroke, 2, 0.2)

	-- Header bar
	local hBar = Instance.new("Frame")
	hBar.Size = UDim2.new(1, 0, 0, 62)
	hBar.BackgroundColor3 = COLORS.header
	hBar.Parent = panel
	corner(hBar, 18)

	local hFill = Instance.new("Frame") -- hides lower-half rounded corners of header
	hFill.Size = UDim2.new(1, 0, 0.5, 0)
	hFill.Position = UDim2.fromScale(0, 0.5)
	hFill.BackgroundColor3 = COLORS.header
	hFill.BorderSizePixel = 0
	hFill.Parent = hBar

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(22, 0)
	title.Size = UDim2.new(1, -60, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "🏆  Achievement Book"
	title.TextColor3 = COLORS.gold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.Parent = hBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.BackgroundColor3 = COLORS.close
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = COLORS.text
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.Parent = hBar
	corner(closeBtn, 10)
	closeBtn.MouseButton1Click:Connect(function()
		if gui then gui.Enabled = false end
	end)

	-- Stats bar
	local statsBar = Instance.new("Frame")
	statsBar.Name = "StatsBar"
	statsBar.Position = UDim2.fromOffset(16, 70)
	statsBar.Size = UDim2.new(1, -32, 0, 52)
	statsBar.BackgroundColor3 = COLORS.section
	statsBar.Parent = panel
	corner(statsBar, 10)

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.fromScale(1, 1)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "Loading stats..."
	statsLabel.TextColor3 = COLORS.subtext
	statsLabel.Font = Enum.Font.GothamMedium
	statsLabel.TextSize = 13
	statsLabel.RichText = true
	statsLabel.TextWrapped = true
	statsLabel.TextYAlignment = Enum.TextYAlignment.Center
	statsLabel.Parent = statsBar

	-- Scrolling list
	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "List"
	listFrame.Position = UDim2.fromOffset(16, 130)
	listFrame.Size = UDim2.new(1, -32, 1, -142)
	listFrame.BackgroundTransparency = 1
	listFrame.ScrollBarThickness = 4
	listFrame.ScrollBarImageColor3 = Color3.fromRGB(88, 202, 110)
	listFrame.BorderSizePixel = 0
	listFrame.CanvasSize = UDim2.fromOffset(0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listFrame
end

-- Rebuild achievement rows from server state
local function renderState(state)
	buildPanel()
	if not listFrame then return end

	-- Clear old rows
	for _, c in listFrame:GetChildren() do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end

	local statsLabel = gui and gui:FindFirstChild("Panel")
		and gui.Panel:FindFirstChild("StatsBar")
		and gui.Panel.StatsBar:FindFirstChild("StatsLabel")

	if statsLabel and state.stats then
		local s = state.stats
		statsLabel.Text = table.concat({
			("🌱 <b>%d</b> planted   💰 <b>$%s</b> earned   🥚 <b>%d</b> pets"):format(
				s.CropsPlanted or 0,
				formatMoney(s.TotalEarned or 0),
				s.PetsOwned or 0
			),
			("🌟 <b>%d</b> harvested   📋 <b>%d</b> orders   🌈 <b>%d</b> mutations   ⭐ <b>%d</b> rebirths"):format(
				s.FruitsHarvested or 0,
				s.OrdersDelivered or 0,
				s.MutationsFound or 0,
				s.Rebirths or 0
			),
		}, "\n")
	end

	-- Group by category in config order
	local grouped: { [string]: { any } } = {}
	local catOrder = {}
	for _, cat in AchievementConfig.CATEGORIES do
		grouped[cat.id] = {}
		table.insert(catOrder, cat.id)
	end
	for _, a in state.achievements do
		if grouped[a.category] then
			table.insert(grouped[a.category], a)
		end
	end

	local layoutOrder = 0
	for _, catId in catOrder do
		local catDef
		for _, c in AchievementConfig.CATEGORIES do
			if c.id == catId then catDef = c break end
		end
		local catColor = CAT_COLORS[catId] or COLORS.green
		local items = grouped[catId] or {}
		if #items == 0 then continue end

		layoutOrder += 1

		-- Category header
		local catHeader = Instance.new("Frame")
		catHeader.LayoutOrder = layoutOrder
		catHeader.Size = UDim2.new(1, 0, 0, 36)
		catHeader.BackgroundColor3 = COLORS.section
		catHeader.Parent = listFrame
		corner(catHeader, 8)

		local catTitle = Instance.new("TextLabel")
		catTitle.Size = UDim2.fromScale(1, 1)
		catTitle.Position = UDim2.fromOffset(12, 0)
		catTitle.BackgroundTransparency = 1
		catTitle.Text = (catDef and catDef.icon or "") .. "  " .. catId
		catTitle.TextColor3 = catColor
		catTitle.TextXAlignment = Enum.TextXAlignment.Left
		catTitle.Font = Enum.Font.GothamBold
		catTitle.TextSize = 16
		catTitle.Parent = catHeader

		-- Achievement cards
		for _, a in items do
			layoutOrder += 1
			local isDone = a.completed
			local isClaimed = a.claimed
			local pct = if a.goal > 0 then math.clamp(a.progress / a.goal, 0, 1) else 1

			local card = Instance.new("Frame")
			card.LayoutOrder = layoutOrder
			card.Size = UDim2.new(1, 0, 0, 86)
			card.BackgroundColor3 = isDone and COLORS.cardDone or COLORS.card
			card.Parent = listFrame
			corner(card, 12)
			if isDone then
				stroke(card, catColor, 1.5, 0.4)
			end

			-- Left color stripe
			local stripe = Instance.new("Frame")
			stripe.Size = UDim2.new(0, 4, 1, -16)
			stripe.Position = UDim2.fromOffset(0, 8)
			stripe.AnchorPoint = Vector2.new(0, 0)
			stripe.BackgroundColor3 = catColor
			stripe.BackgroundTransparency = isDone and 0.1 or 0.45
			stripe.BorderSizePixel = 0
			stripe.Parent = card
			corner(stripe, 4)

			-- Icon badge
			local badge = Instance.new("Frame")
			badge.Size = UDim2.fromOffset(46, 46)
			badge.Position = UDim2.fromOffset(12, 20)
			badge.BackgroundColor3 = isDone and catColor or COLORS.barBg
			badge.BackgroundTransparency = isDone and 0.25 or 0.2
			badge.Parent = card
			corner(badge, 10)

			local iconLbl = Instance.new("TextLabel")
			iconLbl.Size = UDim2.fromScale(1, 1)
			iconLbl.BackgroundTransparency = 1
			iconLbl.Text = a.icon
			iconLbl.TextColor3 = COLORS.text
			iconLbl.Font = Enum.Font.GothamBold
			iconLbl.TextSize = 26
			iconLbl.Parent = badge

			-- Title
			local titleLbl = Instance.new("TextLabel")
			titleLbl.Position = UDim2.fromOffset(68, 10)
			titleLbl.Size = UDim2.new(1, -160, 0, 22)
			titleLbl.BackgroundTransparency = 1
			titleLbl.Text = a.title
			titleLbl.TextColor3 = isDone and COLORS.text or COLORS.subtext
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.TextSize = 16
			titleLbl.Parent = card

			-- Desc
			local descLbl = Instance.new("TextLabel")
			descLbl.Position = UDim2.fromOffset(68, 30)
			descLbl.Size = UDim2.new(1, -160, 0, 16)
			descLbl.BackgroundTransparency = 1
			descLbl.Text = a.desc
			descLbl.TextColor3 = COLORS.subtext
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.Font = Enum.Font.Gotham
			descLbl.TextSize = 12
			descLbl.Parent = card

			-- Progress bar background
			local barBg = Instance.new("Frame")
			barBg.Position = UDim2.fromOffset(68, 54)
			barBg.Size = UDim2.new(1, -160, 0, 10)
			barBg.BackgroundColor3 = COLORS.barBg
			barBg.BackgroundTransparency = 0.3
			barBg.Parent = card
			corner(barBg, 5)

			-- Progress bar fill
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(pct, 1)
			fill.BackgroundColor3 = isDone and COLORS.barFillMax or COLORS.barFill
			fill.BackgroundTransparency = 0.1
			fill.Parent = barBg
			corner(fill, 5)

			-- Progress text
			local progLbl = Instance.new("TextLabel")
			progLbl.Position = UDim2.fromOffset(68, 66)
			progLbl.Size = UDim2.new(1, -160, 0, 14)
			progLbl.BackgroundTransparency = 1
			progLbl.Text = ("%d / %d"):format(a.progress, a.goal)
			progLbl.TextColor3 = isDone and COLORS.gold or COLORS.subtext
			progLbl.TextXAlignment = Enum.TextXAlignment.Left
			progLbl.Font = Enum.Font.Gotham
			progLbl.TextSize = 11
			progLbl.Parent = card

			-- Reward label (right side)
			local rewardText
			if a.diamondReward and a.diamondReward > 0 then
				rewardText = ("$%s\n💎 %d"):format(formatMoney(a.cashReward), a.diamondReward)
			else
				rewardText = ("$%s"):format(formatMoney(a.cashReward))
			end

			local rewardLbl = Instance.new("TextLabel")
			rewardLbl.AnchorPoint = Vector2.new(1, 0.5)
			rewardLbl.Position = UDim2.new(1, -14, 0.5, 0)
			rewardLbl.Size = UDim2.fromOffset(90, 50)
			rewardLbl.BackgroundTransparency = 1
			rewardLbl.Text = rewardText
			rewardLbl.TextColor3 = isClaimed and COLORS.subtext or COLORS.gold
			rewardLbl.TextXAlignment = Enum.TextXAlignment.Right
			rewardLbl.Font = Enum.Font.GothamBold
			rewardLbl.TextSize = 15
			rewardLbl.LineHeight = 1.3
			rewardLbl.Parent = card

			-- Claimed badge
			if isClaimed then
				local claimedBadge = Instance.new("Frame")
				claimedBadge.AnchorPoint = Vector2.new(1, 0)
				claimedBadge.Position = UDim2.new(1, -14, 0, 8)
				claimedBadge.Size = UDim2.fromOffset(64, 22)
				claimedBadge.BackgroundColor3 = COLORS.barFill
				claimedBadge.BackgroundTransparency = 0.2
				claimedBadge.Parent = card
				corner(claimedBadge, 6)

				local claimedLbl = Instance.new("TextLabel")
				claimedLbl.Size = UDim2.fromScale(1, 1)
				claimedLbl.BackgroundTransparency = 1
				claimedLbl.Text = "✅ Done"
				claimedLbl.TextColor3 = COLORS.text
				claimedLbl.Font = Enum.Font.GothamBold
				claimedLbl.TextSize = 13
				claimedLbl.Parent = claimedBadge
			end
		end

		-- Small padding after each category
		layoutOrder += 1
		local spacer = Instance.new("Frame")
		spacer.LayoutOrder = layoutOrder
		spacer.Size = UDim2.new(1, 0, 0, 4)
		spacer.BackgroundTransparency = 1
		spacer.Parent = listFrame
	end
end

achieveRemote.OnClientEvent:Connect(function(action, payload)
	if action == "state" and payload then
		buildPanel()
		renderState(payload)
		-- Only auto-open on first load if there are new unlocks
		local hasNew = false
		for _, a in ipairs(payload.achievements or {}) do
			if a.completed and not a.claimed then hasNew = true break end
		end
		-- Don't force-open; let the button handle it.
		_ = hasNew
	end
end)
