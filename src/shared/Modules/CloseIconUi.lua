--[[
	CloseIconUi — draws an "X" close icon from real UI elements.

	Roblox's default fonts don't reliably render the ✕ (U+2715) Unicode
	glyph — it shows as a tofu/missing-glyph box on some clients. This
	module builds the X from two rotated Frame bars instead, guaranteeing
	it renders identically everywhere.

	Usage:
		local CloseIconUi = require(ReplicatedStorage.Modules.CloseIconUi)
		CloseIconUi.build(closeButton, { color = Color3.new(1,1,1) })
]]

local CloseIconUi = {}

export type BuildOptions = {
	color: Color3?,
	size: number?, -- bounding box size in pixels (square); default 16
	thickness: number?, -- bar thickness in pixels; default 2.2
}

-- Builds an X icon centered inside `parent` (any GuiObject, typically a
-- TextButton used as a close button). Returns the icon Frame.
function CloseIconUi.build(parent: GuiObject, options: BuildOptions?): Frame
	local opts = options or {}
	local color = opts.color or Color3.fromRGB(255, 255, 255)
	local size = opts.size or 16
	local thickness = opts.thickness or 2.2

	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "CloseIcon"
	iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	iconFrame.Position = UDim2.fromScale(0.5, 0.5)
	iconFrame.Size = UDim2.fromOffset(size, size)
	iconFrame.BackgroundTransparency = 1
	iconFrame.Parent = parent

	for _, rotation in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(1, 0, 0, thickness)
		bar.Rotation = rotation
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.Parent = iconFrame

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = bar
	end

	return iconFrame
end

return CloseIconUi
