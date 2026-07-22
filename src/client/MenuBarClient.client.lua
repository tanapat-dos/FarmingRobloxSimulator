--[[
	MenuBarClient — unified left-side navigation bar.

	Replaces the scattered ImageButton HUD buttons with a clean vertical menu
	bar that slides in from the left. Contains teleport shortcuts and panel
	openers, keeping full parity with the old TeleportManager names so
	NavigationHudState still hides/shows everything correctly.

	Buttons (top to bottom):
	  🎒 Bag         — open backpack tool list (or press B)
	  🌱 Garden      — teleport to own plot
	  🌾 Seeds       — teleport to seed shop
	  💰 Sell        — teleport to sell shop
	  🥚 Pet Shop    — teleport to pet shop
	  🐾 My Pets     — open PetMenu panel
	  🏆 Achievements — open Achievements panel
	  🗓️ Daily Login — open Daily Login panel
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local NavigationHudState = require(ReplicatedStorage:WaitForChild("Modules").NavigationHudState)
local BackpackPanelUi = require(ReplicatedStorage:WaitForChild("Modules").BackpackPanelUi)

local COLORS = {
	bar         = Color3.fromRGB(18, 20, 30),
	barBorder   = Color3.fromRGB(40, 44, 60),
	btn         = Color3.fromRGB(30, 34, 48),
	btnHover    = Color3.fromRGB(44, 50, 68),
	btnActive   = Color3.fromRGB(52, 96, 68),
	text        = Color3.fromRGB(235, 240, 250),
	subtext     = Color3.fromRGB(150, 158, 180),
	accent      = Color3.fromRGB(88, 202, 110),
	gold        = Color3.fromRGB(255, 210, 80),
	diamond     = Color3.fromRGB(120, 210, 255),
	close       = Color3.fromRGB(214, 92, 92),
	separator   = Color3.fromRGB(40, 44, 60),
}

local BTN_SIZE   = 52
local BAR_WIDTH  = 72
local BAR_PAD    = 10
local CORNER_R   = 14

-- Button definitions in order
local BUTTONS = {
	{ name = "BackpackBtn",       icon = "🎒", label = "Bag",      color = Color3.fromRGB(140, 200, 255), panel = "Backpack" },
	{ name = "_sepTop" },
	{ name = "GardenTeleport",    icon = "🌱", label = "Garden",   color = COLORS.accent },
	{ name = "SeedsTeleport",     icon = "🌾", label = "Seeds",    color = Color3.fromRGB(200, 220, 100) },
	{ name = "SellTeleport",      icon = "💰", label = "Sell",     color = COLORS.gold },
	{ name = "PetsTeleport",      icon = "🥚", label = "Pets",     color = Color3.fromRGB(200, 160, 255) },
	{ name = "_sep" },
	{ name = "MyPetsBtn",         icon = "🐾", label = "My Pets",  color = Color3.fromRGB(180, 200, 255), panel = "PetMenu" },
	{ name = "AchievementsBtn",   icon = "🏆", label = "Achieve",  color = COLORS.gold, panel = "Achievements" },
	{ name = "DailyLoginBtn",     icon = "🗓️", label = "Daily",   color = Color3.fromRGB(120, 210, 255), panel = "DailyLogin" },
}

local gui: ScreenGui
local bar: Frame
local isVisible = true
local notifDots: { [string]: Frame } = {}

-- ------------------------------------------------------------------ helpers
local function corner(inst: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function makeBar()
	gui = Instance.new("ScreenGui")
	gui.Name = "MenuBarGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Slide-in container
	bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, 12, 0.5, 0)
	bar.Size = UDim2.fromOffset(BAR_WIDTH, 0)   -- auto height via layout
	bar.AutomaticSize = Enum.AutomaticSize.Y
	bar.BackgroundColor3 = COLORS.bar
	bar.BackgroundTransparency = 0.08
	bar.ClipsDescendants = false
	bar.Parent = gui
	corner(bar, CORNER_R)

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = COLORS.barBorder
	barStroke.Thickness = 1.5
	barStroke.Transparency = 0.3
	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barStroke.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local barPad = Instance.new("UIPadding")
	barPad.PaddingTop = UDim.new(0, BAR_PAD)
	barPad.PaddingBottom = UDim.new(0, BAR_PAD)
	barPad.PaddingLeft = UDim.new(0, 8)
	barPad.PaddingRight = UDim.new(0, 8)
	barPad.Parent = bar

	for i, def in ipairs(BUTTONS) do
		if def.name == "_sep" or def.name == "_sepTop" then
			local sep = Instance.new("Frame")
			sep.LayoutOrder = i
			sep.Size = UDim2.new(1, -8, 0, 1)
			sep.BackgroundColor3 = COLORS.separator
			sep.BackgroundTransparency = 0.5
			sep.BorderSizePixel = 0
			sep.Parent = bar
			continue
		end

		local btn = Instance.new("TextButton")
		btn.Name = def.name
		btn.LayoutOrder = i
		btn.Size = UDim2.fromOffset(BTN_SIZE, BTN_SIZE)
		btn.BackgroundColor3 = COLORS.btn
		btn.BackgroundTransparency = 0.1
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = bar
		corner(btn, 12)

		-- Icon
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "Icon"
		iconLabel.Size = UDim2.new(1, 0, 0.6, 0)
		iconLabel.Position = UDim2.fromScale(0, 0.08)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = def.icon
		iconLabel.TextColor3 = COLORS.text
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextSize = 22
		iconLabel.Parent = btn

		-- Label under icon
		local labelText = Instance.new("TextLabel")
		labelText.Name = "Label"
		labelText.Size = UDim2.new(1, 0, 0.36, 0)
		labelText.Position = UDim2.fromScale(0, 0.64)
		labelText.BackgroundTransparency = 1
		labelText.Text = def.label
		labelText.TextColor3 = COLORS.subtext
		labelText.Font = Enum.Font.Gotham
		labelText.TextSize = 10
		labelText.Parent = btn

		-- Hover / press scale
		local scale = Instance.new("UIScale")
		scale.Parent = btn
		local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = COLORS.btnHover
			TweenService:Create(scale, tweenInfo, { Scale = 1.06 }):Play()
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = COLORS.btn
			TweenService:Create(scale, tweenInfo, { Scale = 1 }):Play()
		end)
		btn.MouseButton1Down:Connect(function()
			TweenService:Create(scale, tweenInfo, { Scale = 0.93 }):Play()
		end)
		btn.MouseButton1Up:Connect(function()
			TweenService:Create(scale, tweenInfo, { Scale = 1.06 }):Play()
		end)

		-- Notification dot (for Daily Login, Achievements)
		if def.panel == "DailyLogin" or def.panel == "Achievements" then
			local dot = Instance.new("Frame")
			dot.Name = "NotifDot"
			dot.Size = UDim2.fromOffset(10, 10)
			dot.AnchorPoint = Vector2.new(1, 0)
			dot.Position = UDim2.new(1, 2, 0, -2)
			dot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
			dot.Visible = false
			dot.ZIndex = 10
			dot.Parent = btn
			corner(dot, 5)
			notifDots[def.name] = dot
		end

		-- Wire click
		btn.MouseButton1Click:Connect(function()
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")

			if def.name == "GardenTeleport" and hrp then
				for _, plot in ipairs(workspace.Plots:GetChildren()) do
					if plot:GetAttribute("USERID") == player.UserId then
						hrp.CFrame = CFrame.new(plot.TPPart.Position + Vector3.new(0, 3, 0))
						return
					end
				end
			elseif def.name == "SeedsTeleport" and hrp then
				hrp.CFrame = CFrame.new(workspace.Shops.SeedShop.TPPart.Position + Vector3.new(0, 3, 0))
			elseif def.name == "SellTeleport" and hrp then
				hrp.CFrame = CFrame.new(workspace.Shops.SellStuff.TPPart.Position + Vector3.new(0, 3, 0))
			elseif def.name == "PetsTeleport" and hrp then
				hrp.CFrame = CFrame.new(workspace.Shops.PetShop.TPPart.Position + Vector3.new(0, 3, 0))
			elseif def.panel == "Backpack" then
				BackpackPanelUi.toggle()
			elseif def.panel == "PetMenu" then
				local petMenu = remotes:FindFirstChild("PetMenu")
				if petMenu then
					petMenu:FireServer("refresh")
				end
				local signals = ReplicatedStorage:FindFirstChild("ClientSignals")
				local toggle = signals and signals:FindFirstChild("TogglePetShop")
				-- The pet MENU panel (not shop) is in PetMenuGui — trigger its toggle
				local pmGui = playerGui:FindFirstChild("PetMenuGui")
				local panel = pmGui and pmGui:FindFirstChild("Panel")
				if panel then
					panel.Visible = not panel.Visible
				end
			elseif def.panel == "Achievements" then
				local achieveRemote = remotes:FindFirstChild("Achievements")
				if achieveRemote then
					achieveRemote:FireServer("request")
				end
				local pmGui = playerGui:FindFirstChild("AchievementGui")
				if pmGui then
					pmGui.Enabled = not pmGui.Enabled
				end
				if notifDots["AchievementsBtn"] then
					notifDots["AchievementsBtn"].Visible = false
				end
			elseif def.panel == "DailyLogin" then
				local dailyRemote = remotes:FindFirstChild("DailyLogin")
				if dailyRemote then
					dailyRemote:FireServer("request")
				end
				local pmGui = playerGui:FindFirstChild("DailyLoginGui")
				if pmGui then
					pmGui.Enabled = not pmGui.Enabled
				end
				if notifDots["DailyLoginBtn"] then
					notifDots["DailyLoginBtn"].Visible = false
				end
			end
		end)
	end

	-- Slide-in animation on load
	bar.Position = UDim2.new(0, -BAR_WIDTH - 20, 0.5, 0)
	task.wait(0.3)
	TweenService:Create(bar, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 12, 0.5, 0) }):Play()
end

-- ------------------------------------------------------------------ visibility sync
local function applyVisibility(visible: boolean)
	isVisible = visible
	if bar then
		if visible then
			TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{ Position = UDim2.new(0, 12, 0.5, 0) }):Play()
		else
			TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{ Position = UDim2.new(0, -BAR_WIDTH - 20, 0.5, 0) }):Play()
		end
	end
end

-- ------------------------------------------------------------------ notification dots
-- Show red dot when daily login is claimable
local dailyRemote = remotes:WaitForChild("DailyLogin", 30)
if dailyRemote then
	dailyRemote.OnClientEvent:Connect(function(action)
		local dot = notifDots["DailyLoginBtn"]
		if dot then
			dot.Visible = (action == "claimable")
		end
	end)
end

-- Show red dot when a new achievement is unlocked (state contains newly completed unclaimed)
local achieveRemote = remotes:WaitForChild("Achievements", 30)
if achieveRemote then
	achieveRemote.OnClientEvent:Connect(function(action, payload)
		if action == "state" and payload then
			local hasNew = false
			for _, a in ipairs(payload.achievements or {}) do
				if a.completed and not a.claimed then
					hasNew = true
					break
				end
			end
			local dot = notifDots["AchievementsBtn"]
			if dot then
				dot.Visible = hasNew
			end
		end
	end)
end

-- ------------------------------------------------------------------ init
NavigationHudState.onChanged(applyVisibility)

BackpackPanelUi.mount(player)

task.spawn(makeBar)
