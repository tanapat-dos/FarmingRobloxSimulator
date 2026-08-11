--[[
	DailyLoginClient — daily login popup.

	Shows a 7-day streak calendar panel with today's reward highlighted.
	The player clicks "Claim" once per UTC day; the server validates and grants.
	After claiming, the reward flies in as a little animation and the panel
	shows a "See you tomorrow" countdown.

	Polish pass: animated open/close (matches ShopUI/PetShopUI convention),
	click-off backdrop, a "Day X / 7" header pill, a pulsing glow on the
	claimable day + Claim button, a gold "BONUS" treatment on Day 7, and a
	floating reward payoff + sound on claim. Server contract is unchanged.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local dailyRemote = remotes:WaitForChild("DailyLogin")
local EconomyBalance = require(ReplicatedStorage:WaitForChild("Modules").EconomyBalance)
local CloseIconUi = require(ReplicatedStorage:WaitForChild("Modules").CloseIconUi)
local soundsFolder = ReplicatedStorage:WaitForChild("Sounds")

local REWARDS = EconomyBalance.DAILY_LOGIN_REWARDS
local BONUS_DAY = 7 -- day index that gets the special gold "BONUS" treatment

local COLORS = {
	panel = Color3.fromRGB(25, 28, 40),
	header = Color3.fromRGB(34, 38, 56),
	headerDark = Color3.fromRGB(24, 27, 42),
	card = Color3.fromRGB(38, 44, 60),
	cardActive = Color3.fromRGB(52, 96, 68),
	cardClaimed = Color3.fromRGB(44, 52, 70),
	cardFuture = Color3.fromRGB(30, 34, 48),
	text = Color3.fromRGB(238, 243, 255),
	subtext = Color3.fromRGB(170, 180, 205),
	green = Color3.fromRGB(88, 202, 110),
	greenDark = Color3.fromRGB(58, 150, 78),
	greenBright = Color3.fromRGB(120, 230, 140),
	gold = Color3.fromRGB(255, 210, 80),
	goldDark = Color3.fromRGB(200, 160, 50),
	diamond = Color3.fromRGB(120, 210, 255),
	close = Color3.fromRGB(214, 92, 92),
}

local DAY_ICONS = { "🌱", "🌿", "🍃", "🌼", "🌸", "🌺", "⭐" }

local PANEL_SIZE = UDim2.fromOffset(680, 460)
local OPEN_TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local gui: ScreenGui? = nil
local dim: TextButton? = nil
local panel: Frame? = nil
local dayPill: TextLabel? = nil
local claimButton: TextButton? = nil
local claimButtonScale: UIScale? = nil
local statusLabel: TextLabel? = nil
local dayCards: { Frame } = {}
local countdownLabel: TextLabel? = nil

local countdownConn: RBXScriptConnection? = nil
local claimPulseTween: Tween? = nil
local activeGlowTween: Tween? = nil
local activeGlowCard: Frame? = nil
local isOpen = false

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
	return s
end

local function gradient(instance: GuiObject, colorSequence: ColorSequence, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = colorSequence
	g.Rotation = rotation or 90
	g.Parent = instance
	return g
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

local function playClaimSound()
	local template = soundsFolder:FindFirstChild("Coins")
	if template and template:IsA("Sound") then
		local s = template:Clone()
		s.Parent = player:WaitForChild("PlayerGui")
		s:Play()
		Debris:AddItem(s, (s.TimeLength > 0 and s.TimeLength or 2) + 0.5)
	end
end

local function stopClaimPulse()
	if claimPulseTween then
		claimPulseTween:Cancel()
		claimPulseTween = nil
	end
	if claimButtonScale then
		claimButtonScale.Scale = 1
	end
end

local function startClaimPulse()
	stopClaimPulse()
	if not claimButtonScale then
		return
	end
	claimPulseTween = TweenService:Create(
		claimButtonScale,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.045 }
	)
	claimPulseTween:Play()
end

local function stopActiveGlow()
	if activeGlowTween then
		activeGlowTween:Cancel()
		activeGlowTween = nil
	end
	if activeGlowCard then
		local glow = activeGlowCard:FindFirstChild("ActiveGlow")
		if glow then
			glow.Transparency = 1
		end
	end
	activeGlowCard = nil
end

local function startActiveGlow(card: Frame, color: Color3)
	stopActiveGlow()
	local glow = card:FindFirstChild("ActiveGlow") :: UIStroke?
	if not glow then
		glow = stroke(card, color, 4, 0.3)
		glow.Name = "ActiveGlow"
	end
	glow.Color = color
	activeGlowCard = card
	activeGlowTween = TweenService:Create(
		glow,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.05 }
	)
	activeGlowTween:Play()
end

local function floatRewardPayoff(cash: number, diamonds: number)
	if not panel then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "RewardPayoff"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, 300)
	label.Size = UDim2.fromOffset(0, 32)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 24
	label.TextColor3 = COLORS.gold
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.ZIndex = 10
	label.RichText = true
	if diamonds > 0 then
		label.Text = ("+$%s  💎+%d"):format(formatCash(cash), diamonds)
	else
		label.Text = ("+$%s"):format(formatCash(cash))
	end
	label.Parent = panel

	local tween = TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 250),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

local function close()
	if not gui or not isOpen then
		return
	end
	isOpen = false
	stopClaimPulse()
	stopActiveGlow()
	if countdownConn then
		countdownConn:Disconnect()
		countdownConn = nil
	end
	if panel then
		TweenService:Create(panel, CLOSE_TWEEN_INFO, { Size = UDim2.fromOffset(0, 0) }):Play()
	end
	if dim then
		TweenService:Create(dim, CLOSE_TWEEN_INFO, { BackgroundTransparency = 1 }):Play()
	end
	task.delay(CLOSE_TWEEN_INFO.Time, function()
		if gui and not isOpen then
			gui.Enabled = false
		end
	end)
end

local function open()
	if not gui then
		return
	end
	gui.Enabled = true
	if isOpen then
		return
	end
	isOpen = true
	if panel then
		panel.Size = UDim2.fromOffset(0, 0)
		TweenService:Create(panel, OPEN_TWEEN_INFO, { Size = PANEL_SIZE }):Play()
	end
	if dim then
		dim.BackgroundTransparency = 1
		TweenService:Create(dim, FADE_TWEEN_INFO, { BackgroundTransparency = 0.5 }):Play()
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

	-- Click-off backdrop. Sits behind the panel so panel clicks never reach it.
	dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Parent = gui
	dim.MouseButton1Click:Connect(close)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(0, 0)
	panel.BackgroundColor3 = COLORS.panel
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, Color3.fromRGB(14, 16, 28), 2, 0.2)
	local outerGlow = stroke(panel, COLORS.gold, 6, 0.85)
	outerGlow.Name = "OuterGlow"

	-- Header
	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, 0, 64)
	headerBar.BackgroundColor3 = COLORS.header
	headerBar.Parent = panel
	corner(headerBar, 18)
	gradient(headerBar, ColorSequence.new(COLORS.header, COLORS.headerDark), 90)

	-- Square off the bottom corners of the header so it reads as one bar.
	local headerSquareOff = Instance.new("Frame")
	headerSquareOff.Size = UDim2.new(1, 0, 0, 18)
	headerSquareOff.Position = UDim2.new(0, 0, 1, -18)
	headerSquareOff.BackgroundColor3 = COLORS.headerDark
	headerSquareOff.BorderSizePixel = 0
	headerSquareOff.ZIndex = 0
	headerSquareOff.Parent = headerBar

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(22, 0)
	title.Size = UDim2.new(1, -220, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "🗓️  Daily Login Rewards"
	title.TextColor3 = COLORS.gold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = headerBar

	dayPill = Instance.new("TextLabel")
	dayPill.Name = "DayPill"
	dayPill.AnchorPoint = Vector2.new(1, 0.5)
	dayPill.Position = UDim2.new(1, -58, 0.5, 0)
	dayPill.Size = UDim2.fromOffset(96, 30)
	dayPill.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	dayPill.BackgroundTransparency = 0.15
	dayPill.Text = "Day 1 / 7"
	dayPill.TextColor3 = COLORS.text
	dayPill.Font = Enum.Font.GothamBold
	dayPill.TextSize = 14
	dayPill.Parent = headerBar
	corner(dayPill, 15)
	stroke(dayPill, COLORS.gold, 1, 0.5)

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(34, 34)
	closeBtn.BackgroundColor3 = COLORS.close
	closeBtn.Text = ""
	closeBtn.Parent = headerBar
	corner(closeBtn, 8)
	CloseIconUi.build(closeBtn, { color = COLORS.text })
	closeBtn.MouseButton1Click:Connect(close)

	-- Day cards row
	local cardsRow = Instance.new("Frame")
	cardsRow.Position = UDim2.fromOffset(18, 84)
	cardsRow.Size = UDim2.new(1, -36, 0, 210)
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
		local isBonusDay = i == BONUS_DAY
		local topOffset = isBonusDay and 14 or 0

		local card = Instance.new("Frame")
		card.Name = "Day" .. i
		card.Size = UDim2.new(1 / 7, -6, 1, 0)
		card.BackgroundColor3 = COLORS.cardFuture
		card.LayoutOrder = i
		card.Parent = cardsRow
		corner(card, 12)
		gradient(card, ColorSequence.new(
			Color3.new(1, 1, 1),
			Color3.fromRGB(215, 215, 215)
		), 90)
		card:FindFirstChildOfClass("UIGradient").Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 1),
		})

		if isBonusDay then
			local badge = Instance.new("TextLabel")
			badge.Name = "Badge"
			badge.Position = UDim2.fromOffset(0, 4)
			badge.Size = UDim2.new(1, 0, 0, 14)
			badge.BackgroundTransparency = 1
			badge.Text = "🎁 BONUS"
			badge.TextColor3 = COLORS.gold
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 10
			badge.Parent = card

			stroke(card, COLORS.gold, 1.5, 0.45).Name = "BonusStroke"
		end

		local dayLabel = Instance.new("TextLabel")
		dayLabel.Name = "DayNum"
		dayLabel.Position = UDim2.fromOffset(0, 6 + topOffset)
		dayLabel.Size = UDim2.new(1, 0, 0, 20)
		dayLabel.BackgroundTransparency = 1
		dayLabel.Text = ("Day %d"):format(i)
		dayLabel.TextColor3 = COLORS.subtext
		dayLabel.Font = Enum.Font.GothamBold
		dayLabel.TextSize = 13
		dayLabel.Parent = card

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "Icon"
		iconLabel.Position = UDim2.fromOffset(0, 29 + topOffset)
		iconLabel.Size = UDim2.new(1, 0, 0, 45)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = DAY_ICONS[i]
		iconLabel.TextColor3 = COLORS.text
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextSize = 34
		iconLabel.Parent = card

		local cashLabel = Instance.new("TextLabel")
		cashLabel.Name = "Cash"
		cashLabel.Position = UDim2.fromOffset(0, 79 + topOffset)
		cashLabel.Size = UDim2.new(1, 0, 0, 22)
		cashLabel.BackgroundTransparency = 1
		cashLabel.Text = ("$%s"):format(formatCash(r.cash))
		cashLabel.TextColor3 = COLORS.gold
		cashLabel.Font = Enum.Font.GothamBold
		cashLabel.TextSize = 12
		cashLabel.Parent = card

		if r.diamonds and r.diamonds > 0 then
			local diaLabel = Instance.new("TextLabel")
			diaLabel.Name = "Diamonds"
			diaLabel.Position = UDim2.fromOffset(0, 101 + topOffset)
			diaLabel.Size = UDim2.new(1, 0, 0, 20)
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
	claimButton.Position = UDim2.fromOffset(18, 306)
	claimButton.Size = UDim2.new(1, -36, 0, 58)
	claimButton.BackgroundColor3 = COLORS.green
	claimButton.Text = "✅  Claim Today's Reward"
	claimButton.TextColor3 = COLORS.text
	claimButton.Font = Enum.Font.GothamBold
	claimButton.TextSize = 22
	claimButton.AutoButtonColor = false
	claimButton.Parent = panel
	corner(claimButton, 12)
	stroke(claimButton, COLORS.greenDark, 2, 0.15)
	gradient(claimButton, ColorSequence.new(COLORS.greenBright, COLORS.greenDark), 90)

	claimButtonScale = Instance.new("UIScale")
	claimButtonScale.Parent = claimButton

	claimButton.MouseEnter:Connect(function()
		if claimButton.Visible then
			TweenService:Create(claimButton, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.greenBright }):Play()
		end
	end)
	claimButton.MouseLeave:Connect(function()
		TweenService:Create(claimButton, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.green }):Play()
	end)
	claimButton.MouseButton1Click:Connect(function()
		dailyRemote:FireServer("claim")
	end)

	statusLabel = Instance.new("TextLabel")
	statusLabel.Position = UDim2.fromOffset(18, 374)
	statusLabel.Size = UDim2.new(1, -36, 0, 26)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.RichText = true
	statusLabel.TextColor3 = COLORS.subtext
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 15
	statusLabel.Parent = panel

	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Position = UDim2.fromOffset(18, 404)
	countdownLabel.Size = UDim2.new(1, -36, 0, 28)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = ""
	countdownLabel.TextColor3 = COLORS.subtext
	countdownLabel.Font = Enum.Font.Gotham
	countdownLabel.TextSize = 13
	countdownLabel.Parent = panel
end

local function setDayPill(day: number)
	if dayPill then
		dayPill.Text = ("Day %d / 7"):format(day)
	end
end

local function applyDayCards(currentDay: number, alreadyClaimed: boolean)
	for i, card in dayCards do
		local isBonusDay = i == BONUS_DAY
		local label = card:FindFirstChild("DayNum")
		local checkOffset = isBonusDay and 147 or 133

		if i < currentDay or (alreadyClaimed and i == currentDay) then
			-- past / already claimed
			card.BackgroundColor3 = COLORS.cardClaimed
			if label then
				label.TextColor3 = COLORS.subtext
			end
			local check = card:FindFirstChild("Check")
			if not check and (alreadyClaimed and i == currentDay) then
				local c = Instance.new("TextLabel")
				c.Name = "Check"
				c.Position = UDim2.fromOffset(0, checkOffset)
				c.Size = UDim2.new(1, 0, 0, 20)
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
			if label then
				label.TextColor3 = isBonusDay and COLORS.gold or COLORS.green
			end
			startActiveGlow(card, isBonusDay and COLORS.gold or COLORS.green)
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
		countdownLabel.Text = ("⏰ Next reward in: %s"):format(formatCountdown(remaining))
	end
	countdownConn = RunService.Heartbeat:Connect(function(dt)
		remaining -= dt
		if countdownLabel then
			if remaining <= 0 then
				countdownLabel.Text = "🔔 New reward available! Rejoin to claim."
				if countdownConn then
					countdownConn:Disconnect()
					countdownConn = nil
				end
			else
				countdownLabel.Text = ("⏰ Next reward in: %s"):format(formatCountdown(remaining))
			end
		end
	end)
end

dailyRemote.OnClientEvent:Connect(function(action, payload)
	buildPanel()
	open()

	if action == "claimable" then
		local streakDay = payload.streak or 1
		setDayPill(streakDay)
		applyDayCards(streakDay, false)
		if claimButton then
			claimButton.Visible = true
			claimButton.BackgroundColor3 = COLORS.green
			claimButton.Text = ("✅  Claim Day %d Reward"):format(streakDay)
		end
		startClaimPulse()
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
		setDayPill(streakDay)
		applyDayCards(streakDay, true)
		stopActiveGlow()
		stopClaimPulse()

		if claimButton then
			claimButton.Visible = false
		end

		playClaimSound()
		floatRewardPayoff(cash, diamonds)

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
			if isOpen then
				close()
			end
		end)

	elseif action == "alreadyClaimed" then
		local streak = payload.streak or 0
		local nextIn = payload.nextIn or 0
		setDayPill(streak)
		-- Show all claimed up to current streak
		applyDayCards(streak, true)
		stopActiveGlow()
		stopClaimPulse()

		if claimButton then
			claimButton.Visible = false
		end
		if statusLabel then
			statusLabel.Text = "Already claimed today — come back tomorrow!"
		end
		startCountdown(nextIn)
	end
end)
