--!strict
-- Shared client HUD visibility for Garden / Seeds / Sell / Pets navigation buttons.

local NavigationHudState = {
	visible = true,
}

local changed = Instance.new("BindableEvent")
changed.Name = "NavigationHudVisibilityChanged"

function NavigationHudState.isVisible(): boolean
	return NavigationHudState.visible
end

function NavigationHudState.setVisible(visible: boolean)
	if NavigationHudState.visible == visible then
		return
	end
	NavigationHudState.visible = visible
	changed:Fire(visible)
end

function NavigationHudState.toggle()
	NavigationHudState.setVisible(not NavigationHudState.visible)
end

function NavigationHudState.onChanged(callback: (visible: boolean) -> ())
	return changed.Event:Connect(callback)
end

function NavigationHudState.applyMainButtons(mainButtons: Instance)
	local visible = NavigationHudState.visible
	for _, child in mainButtons:GetChildren() do
		if child:IsA("GuiObject") then
			child.Visible = visible
		end
	end
end

function NavigationHudState.applyToPlayerGui(playerGui: Instance)
	local main = playerGui:FindFirstChild("Main")
	if main then
		local buttons = main:FindFirstChild("Buttons")
		if buttons then
			NavigationHudState.applyMainButtons(buttons)
		end
	end

	-- PetMenuGui no longer has its own toggle button (opened via the left
	-- menu bar's "My Pets" button instead) — just force-close the panel
	-- when the HUD is hidden.
	local petMenu = playerGui:FindFirstChild("PetMenuGui")
	if petMenu and not NavigationHudState.visible then
		local panel = petMenu:FindFirstChild("Panel")
		if panel and panel:IsA("GuiObject") then
			panel.Visible = false
		end
	end
end

return NavigationHudState
