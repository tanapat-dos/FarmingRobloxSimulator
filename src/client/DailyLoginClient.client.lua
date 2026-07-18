--[[
	DailyLoginClient — daily login popup.

	Shows a 7-day streak calendar panel with the today's reward highlighted.
	The player clicks "Claim" once per UTC day; the server validates and grants.
	After claiming, the reward flies in as a little animation and the panel
	shows a "See you tomorrow" countdown.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local dailyRemote = remotes:WaitForChild("DailyLogin")

local REWARDS = {
	{ day = 1, cash = 500,   diamonds = 0  },
	{ day = 2, cash = 1000,  diamonds = 0  },
	{ day = 3, cash = 2000,  diamonds = 0  },
	{ day = 4, cash = 3500,  diamonds = 0  },
	{ day = 5, cash = 6000,  diamonds = 0  },
	{ day = 6, cash = 10000, diamonds = 0  },
	{ day = 7, cash = 20000, diamonds = 10 },
}

local COLORS = {
	panel = Color3.fromRGB(25, 28, 40),
	header = Color3.fromRGB(34, 38, 56),
	card = Color3.fromRGB(38, 44, 60),
	cardActive = Color3.fromRGB(52, 96, 68),
	cardClaimed = Color3.fromRGB(44, 52, 70),
	cardFuture = Color3.fromRGB(30, 34, 48),
	text = Color3.fromRGB(238, 243, 255),
	subtext = Color3.fromRGB(170, 180, 205),
	green = Color3.fromRGB(88, 202, 110),
	greenDark = Color3.fromRGB(58, 150, 78),
	gold = Color3.fromRGB(255, 210, 80),
	diamond = Color3.fromRGB(120, 210, 255),
	close = Color3.fromRGB(214, 92, 92),
}

local DAY_ICONS = { "🌱", "🌿", "🍃", "🌼", "🌸", "🌺", "⭐" }

local gui: ScreenGui? = nil
local panel: Frame? = nil
local claimButton: TextButton? = nil
local statusLabel: TextLabel? = nil
local dayCards: { Frame } = {}
local countdownLabel: TextLabel? = nil

local countdownConn: RBXScriptConnection? = nil

local function corner(instance: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

local function stroke(instance: GuiObject, color: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = instance
end

local function formatCountdown(secs: number): string
	secs = math.max(0, math.floor(secs))
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	local s = secs % 60
	return ("%02d:%02d:%02d"):format(h, m, s)
end

local function formatCash(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function close()
	if countdownConn then
		countdownConn:Disconnect()
		countdownConn = nil
	end
	if gui then
		gui.Enabled = false
	end
end

local function buildPanel()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "DailyLoginGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(580, 400)
	panel.BackgroundColor3 = COLORS.panel
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, Color3.fromRGB(14, 16, 28), 2, 0.2)

	-- Header
	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, 0, 60)
	headerBar.BackgroundColor3 = COLORS.header
	headerBar.Parent = panel
	corner(headerBar, 18)

	local headerFill = Instance.new("Frame")
	headerFill.Size = UDim2.new(1, 0, 0.5, 0)
	headerFill.Position = UDim2.fromScale(0, 0.5)
	headerFill.BackgroundColor3 = COLORS.header
	headerFill.BorderSizePixel = 0
	headerFill.Parent = headerBar

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(22, 0)
	title.Size = UDim2.new(1, -60, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "🗓️  Daily Login Rewards"
	title.TextColor3 = COLORS.gold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.Parent = headerBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(34, 34)
	closeBtn.BackgroundColor3 = COLORS.close
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = COLORS.text
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.Parent = headerBar
	corner(closeBtn, 8)
	closeBtn.MouseButton1Click:Connect(close)

	-- Day cards row
	local cardsRow = Instance.new("Frame")
	cardsRow.Position = UDim2.fromOffset(16, 72)
	cardsRow.Size = UDim2.new(1, -32, 0, 188)
	cardsRow.BackgroundTransparency = 1
	cardsRow.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cardsRow

	dayCards = {}
	for i = 1, 7 do
		local r = REWARDS[i]
		local card = Instance.new("Frame")
		card.Name = "Day" .. i
		card.Size = UDim2.new(1/7, -6, 1, 0)
		card.BackgroundColor3 = COLORS.cardFuture
		card.LayoutOrder = i
		card.Parent = cardsRow
		corner(card, 10)

		local dayLabel = Instance.new("TextLabel")
		dayLabel.Name = "DayNum"
		dayLabel.Position = UDim2.fromOffset(0, 5)
		dayLabel.Size = UDim2.new(1, 0, 0, 18)
		dayLabel.BackgroundTransparency = 1
		dayLabel.Text = ("Day %d"):format(i)
		dayLabel.TextColor3 = COLORS.subtext
		dayLabel.Font = Enum.Font.GothamBold
		dayLabel.TextSize = 12
		dayLabel.Parent = card

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "Icon"
		iconLabel.Position = UDim2.fromOffset(0, 26)
		iconLabel.Size = UDim2.new(1, 0, 0, 40)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = DAY_ICONS[i]
		iconLabel.TextColor3 = COLORS.text
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextSize = 30
		iconLabel.Parent = card

		local cashLabel = Instance.new("TextLabel")
		cashLabel.Name = "Cash"
		cashLabel.Position = UDim2.fromOffset(0, 70)
		cashLabel.Size = UDim2.new(1, 0, 0, 20)
		cashLabel.BackgroundTransparency = 1
		cashLabel.Text = ("$%s"):format(formatCash(r.cash))
		cashLabel.TextColor3 = COLORS.gold
		cashLabel.Font = Enum.Font.GothamBold
		cashLabel.TextSize = 11
		cashLabel.Parent = card

		if r.diamonds and r.diamonds > 0 then
			local diaLabel = Instance.new("TextLabel")
			diaLabel.Name = "Diamonds"
			diaLabel.Position = UDim2.fromOffset(0, 90)
			diaLabel.Size = UDim2.new(1, 0, 0, 18)
			diaLabel.BackgroundTransparency = 1
			diaLabel.Text = ("💎 +%d"):format(r.diamonds)
			diaLabel.TextColor3 = COLORS.diamond
			diaLabel.Font = Enum.Font.GothamBold
			diaLabel.TextSize = 12
			diaLabel.Parent = card
		end

		dayCards[i] = card
	end

	-- Claim button
	claimButton = Instance.new("TextButton")
	claimButton.Position = UDim2.fromOffset(16, 272)
	claimButton.Size = UDim2.new(1, -32, 0, 52)
	claimButton.BackgroundColor3 = COLORS.green
	claimButton.Text = "✅  Claim Today's Reward"
	claimButton.TextColor3 = COLORS.text
	claimButton.Font = Enum.Font.GothamBold
	claimButton.TextSize = 20
	claimButton.Parent = panel
	corner(claimButton, 12)
	stroke(claimButton, COLORS.greenDark, 2, 0.15)
	claimButton.MouseButton1Click:Connect(function()
		dailyRemote:FireServer("claim")
	end)

	statusLabel = Instance.new("TextLabel")
	statusLabel.Position = UDim2.fromOffset(16, 332)
	statusLabel.Size = UDim2.new(1, -32, 0, 24)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.RichText = true
	statusLabel.TextColor3 = COLORS.subtext
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 15
	statusLabel.Parent = panel

	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Position = UDim2.fromOffset(16, 358)
	countdownLabel.Size = UDim2.new(1, -32, 0, 22)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = ""
	countdownLabel.TextColor3 = COLORS.subtext
	countdownLabel.Font = Enum.Font.Gotham
	countdownLabel.TextSize = 13
	countdownLabel.Parent = panel
end

local function applyDayCards(currentDay: number, alreadyClaimed: boolean)
	for i, card in dayCards do
		local label = card:FindFirstChild("DayNum")
		if i < currentDay or (alreadyClaimed and i == currentDay) then
			-- past / already claimed
			card.BackgroundColor3 = COLORS.cardClaimed
			if label then
				label.TextColor3 = COLORS.subtext
			end
			-- Show checkmark on claimed day
			local check = card:FindFirstChild("Check")
			if not check and (alreadyClaimed and i == currentDay) then
				local c = Instance.new("TextLabel")
				c.Name = "Check"
				c.Position = UDim2.fromOffset(0, 118)
				c.Size = UDim2.new(1, 0, 0, 18)
				c.BackgroundTransparency = 1
				c.Text = "✅"
				c.TextColor3 = COLORS.green
				c.Font = Enum.Font.GothamBold
				c.TextSize = 16
				c.Parent = card
			end
		elseif i == currentDay then
			-- active / claimable
			card.BackgroundColor3 = COLORS.cardActive
			stroke(card, COLORS.green, 2, 0.1)
			if label then
				label.TextColor3 = COLORS.green
			end
		else
			-- future
			card.BackgroundColor3 = COLORS.cardFuture
		end
	end
end

local function startCountdown(seconds: number)
	if countdownConn then
		countdownConn:Disconnect()
	end
	local remaining = seconds
	if countdownLabel then
		countdownLabel.Text = ("Next reward in: %s"):format(formatCountdown(remaining))
	end
	countdownConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		remaining -= dt
		if countdownLabel then
			if remaining <= 0 then
				countdownLabel.Text = "New reward available! Rejoin to claim."
				if countdownConn then
					countdownConn:Disconnect()
					countdownConn = nil
				end
			else
				countdownLabel.Text = ("Next reward in: %s"):format(formatCountdown(remaining))
			end
		end
	end)
end

dailyRemote.OnClientEvent:Connect(function(action, payload)
	buildPanel()
	gui.Enabled = true

	if action == "claimable" then
		local streakDay = payload.streak or 1
		applyDayCards(streakDay, false)
		if claimButton then
			claimButton.Visible = true
			claimButton.BackgroundColor3 = COLORS.green
			claimButton.Text = ("✅  Claim Day %d Reward"):format(streakDay)
			claimButton.AutoButtonColor = true
		end
		if statusLabel then
			statusLabel.Text = ""
		end
		if countdownLabel then
			countdownLabel.Text = ""
		end
		if countdownConn then
			countdownConn:Disconnect()
			countdownConn = nil
		end

	elseif action == "claimed" then
		local streakDay = payload.streak or 1
		local cash = payload.actualCash or 0
		local diamonds = payload.actualDiamonds or 0
		applyDayCards(streakDay, true)

		if claimButton then
			claimButton.Visible = false
		end

		-- Bounce animation on the active card
		if dayCards[streakDay] then
			local card = dayCards[streakDay]
			TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.new(1/7, -2, 1.08, 0) }):Play()
			task.wait(0.12)
			TweenService:Create(card, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = UDim2.new(1/7, -6, 1, 0) }):Play()
		end

		if statusLabel then
			local msg
			if diamonds > 0 then
				msg = ("🎉 You got <font color=\"rgb(255,210,80)\">$%s</font>  💎 <font color=\"rgb(120,210,255)\">+%d</font>!"):format(
					formatCash(cash), diamonds)
			else
				msg = ("🎉 You got <font color=\"rgb(255,210,80)\">$%s</font>!"):format(formatCash(cash))
			end
			statusLabel.Text = msg
		end

		-- Auto-close after 4 s
		task.delay(4, function()
			if gui and gui.Enabled then
				close()
			end
		end)

	elseif action == "alreadyClaimed" then
		local streak = payload.streak or 0
		local nextIn = payload.nextIn or 0
		-- Show all claimed up to current streak
		applyDayCards(streak, true)

		if claimButton then
			claimButton.Visible = false
		end
		if statusLabel then
			statusLabel.Text = "Already claimed today — come back tomorrow!"
		end
		startCountdown(nextIn)
	end
end)
