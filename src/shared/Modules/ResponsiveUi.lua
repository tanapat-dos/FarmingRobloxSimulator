--!strict
--[[
	ResponsiveUi — shared viewport fitting for client UI built at fixed pixel sizes.

	Most panels in this project are authored at a size tuned for a ~1280x720 desktop viewport
	(GardenUpgrade 720x540, DailyLogin 680x460, and so on). On a phone those dimensions can exceed
	the viewport outright, pushing close and action buttons off-screen where they cannot be tapped.

	The approach is to scale rather than re-lay-out: a UIScale on the panel shrinks it and every
	descendant together, so the proportions and spacing already tuned by hand survive intact. That
	is much cheaper and less regression-prone than maintaining a second mobile layout per panel.

	Two properties worth relying on:
	  * Fits on BOTH axes (min of the width and height ratios). A width-only ratio reports 1.0 on a
	    wide landscape phone while a tall panel still spills off vertically.
	  * Clamped at maxScale (default 1), so a normal desktop viewport computes exactly 1.0 and
	    renders identically to before. This is purely additive for desktop.

	UIScale composes with Size tweens, so panels that animate open by tweening Size (DailyLogin)
	work unchanged — the tween drives Size, this drives the multiplier.
]]

local ResponsiveUi = {}

-- The viewport the fixed pixel sizes across this project were tuned against.
ResponsiveUi.REFERENCE_VIEWPORT = Vector2.new(1280, 720)

export type FitOptions = {
	margin: number?, -- keep this many pixels clear on each edge
	minScale: number?, -- never shrink below this, so text stays legible
	maxScale: number?, -- never grow beyond this; 1 keeps desktop untouched
}

local DEFAULT_MARGIN = 24
local DEFAULT_MIN_SCALE = 0.5
local DEFAULT_MAX_SCALE = 1

function ResponsiveUi.getViewport(): Vector2
	local camera = workspace.CurrentCamera
	-- Falling back to the reference viewport (rather than zero) means an early call before the
	-- camera exists computes scale 1.0 instead of collapsing the UI to nothing.
	return camera and camera.ViewportSize or ResponsiveUi.REFERENCE_VIEWPORT
end

--[[
	Largest scale at which contentWidth x contentHeight fits the viewport inside the margin,
	clamped to [minScale, maxScale].
]]
function ResponsiveUi.computeFitScale(contentWidth: number, contentHeight: number, options: FitOptions?): number
	local opts = options or {}
	local margin = opts.margin or DEFAULT_MARGIN
	local minScale = opts.minScale or DEFAULT_MIN_SCALE
	local maxScale = opts.maxScale or DEFAULT_MAX_SCALE

	if contentWidth <= 0 or contentHeight <= 0 then
		return maxScale
	end

	local viewport = ResponsiveUi.getViewport()
	local availableX = math.max(1, viewport.X - margin * 2)
	local availableY = math.max(1, viewport.Y - margin * 2)
	local fit = math.min(availableX / contentWidth, availableY / contentHeight)
	return math.clamp(fit, minScale, maxScale)
end

--[[
	Runs callback now and whenever the viewport changes, including across a camera swap (which
	happens on respawn and on some cutscene/teleport flows — reconnecting there is why this is a
	helper rather than a bare GetPropertyChangedSignal at each call site).

	Returns a cleanup function that disconnects everything.
]]
function ResponsiveUi.onViewportChanged(callback: () -> ()): () -> ()
	local connections: { RBXScriptConnection } = {}

	local function watch(camera: Camera?)
		if camera then
			table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(callback))
		end
	end

	watch(workspace.CurrentCamera)
	table.insert(
		connections,
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			watch(workspace.CurrentCamera)
			callback()
		end)
	)

	callback()

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

--[[
	Parents a UIScale to target that keeps contentWidth x contentHeight fitting the viewport, and
	keeps it current as the viewport changes.

	target should use AnchorPoint 0.5 / Position 0.5 scale if it is meant to stay centred — UIScale
	scales around the anchor, so a centred panel needs no position maths.

	Returns the UIScale and a cleanup function.
]]
function ResponsiveUi.attachFitScale(
	target: GuiObject,
	contentWidth: number,
	contentHeight: number,
	options: FitOptions?
): (UIScale, () -> ())
	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveFitScale"
	scale.Parent = target

	local disconnect = ResponsiveUi.onViewportChanged(function()
		if scale.Parent then
			scale.Scale = ResponsiveUi.computeFitScale(contentWidth, contentHeight, options)
		end
	end)

	return scale, disconnect
end

return ResponsiveUi
