--!strict
--[[
	BackpackTopbarIcon — a bag button in the topbar strip, left of centre, next to Roblox's own
	icons.

	Why this exists: Roblox's unified topbar collapses "Inventory" into the overflow ("More") menu,
	and there is no CoreGui flag to pin it back out. Games that show a bag next to the Roblox logo
	draw their own icon, which is what this does.

	It opens BackpackPanelUi (the same panel as the B key and the menu bar's Bag button) rather
	than Roblox's CoreGui backpack, because Roblox exposes no API to open that one programmatically.
	The default backpack stays enabled and reachable from the More menu and the bottom hotbar.

	Positioning uses GuiService.TopbarInset, which reports the strip Roblox is NOT already using.
	Anchoring to its left edge means the button lands beside Roblox's buttons instead of underneath
	them, and it re-anchors when the inset changes (window resize, device rotation, Roblox adding
	or removing its own icons).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage:WaitForChild("Modules")
local BackpackPanelUi = require(modules:WaitForChild("BackpackPanelUi"))
local NavigationHudState = require(modules:WaitForChild("NavigationHudState"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ICON_SIZE = 36
local ICON_GAP = 8
-- Roblox's own topbar buttons sit slightly below the reported inset top, so centring in the inset
-- alone leaves this button riding high. Nudge down to sit on the same optical line as them.
-- Tune this single value if the alignment looks off on a given resolution.
local ICON_NUDGE_Y = 4

local COLORS = {
	btn = Color3.fromRGB(30, 34, 48),
	btnHover = Color3.fromRGB(44, 50, 68),
	text = Color3.fromRGB(235, 240, 250),
}

-- Mounted by MenuBarClient/EnableBackpackCoreGui already, but mount() self-guards, so calling it
-- here removes any ordering assumption about which script wins the race.
BackpackPanelUi.mount(player)

local gui = Instance.new("ScreenGui")
gui.Name = "BackpackTopbarIcon"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 7 -- below MenuBarGui (8) so open panels always draw over it
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "BagButton"
button.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
button.BackgroundColor3 = COLORS.btn
button.BackgroundTransparency = 0.15
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.Text = "🎒"
button.TextSize = 18
button.TextColor3 = COLORS.text
button.Font = Enum.Font.GothamMedium
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = button

-- Roblox reports the free strip in absolute pixels; sit just inside its left edge and vertically
-- centre within it so the button lines up with Roblox's own icons at any topbar height.
local function reposition()
	local inset = GuiService.TopbarInset
	local height = inset.Height
	if height <= 0 then
		-- No topbar strip reported (some devices/fullscreen states). Fall back to a sane offset
		-- rather than positioning at 0,0 on top of the Roblox logo.
		button.Position = UDim2.fromOffset(ICON_GAP, ICON_GAP + ICON_NUDGE_Y)
		return
	end
	local y = inset.Min.Y + math.max(0, (height - ICON_SIZE) // 2) + ICON_NUDGE_Y
	button.Position = UDim2.fromOffset(inset.Min.X + ICON_GAP, y)
end

reposition()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(reposition)

button.MouseEnter:Connect(function()
	button.BackgroundColor3 = COLORS.btnHover
end)
button.MouseLeave:Connect(function()
	button.BackgroundColor3 = COLORS.btn
end)

button.Activated:Connect(function()
	BackpackPanelUi.toggle()
end)

-- Follow the same HUD show/hide toggle as the rest of the navigation UI, so hiding the HUD hides
-- this too instead of leaving one orphaned button floating in the topbar.
local function applyVisibility(visible: boolean)
	gui.Enabled = visible
end

applyVisibility(NavigationHudState.isVisible())
NavigationHudState.onChanged(applyVisibility)
