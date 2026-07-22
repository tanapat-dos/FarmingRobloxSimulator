--[[
	PREPARE MANGO DISPLAY (non-destructive — never Destroy() art)

	Mature layout: Workspace.Mango Mature
	  • tree (MeshParts on root and/or one child Model)
	  • 4 fruit child Models

	Option A — 8 Models selected (left → right on baseplate):
	  sprout, growing, tree, fruit, fruit, fruit, fruit, harvest
	  → renames stages and groups tree + 4 fruits under Mango Mature

	Option B — 4 Models selected:
	  sprout, growing, Mango Mature (already has tree + 4 fruits), harvest

	Option C — 5 Models selected:
	  tree + 4 fruits only → parents into existing or new Mango Mature

	Then IntegrateMango.lua
--]]

local Selection = game:GetService("Selection")

local MATURE_NAME = "Mango Mature"
local DISPLAY = {
	sprout = "Mango Sprout",
	growing = "Mango Growing",
	mature = MATURE_NAME,
	harvest = "Mango Harvest",
}

local function sortByX(models: { Model }): { Model }
	table.sort(models, function(a, b)
		local pa = a:GetPivot().Position
		local pb = b:GetPivot().Position
		if math.abs(pa.X - pb.X) > 0.25 then
			return pa.X < pb.X
		end
		return pa.Z < pb.Z
	end)
	return models
end

local function getOrCreateMature(): Model
	local m = workspace:FindFirstChild(MATURE_NAME)
	if m and m:IsA("Model") then
		return m
	end
	m = Instance.new("Model")
	m.Name = MATURE_NAME
	m:SetAttribute("MangoDisplay", true)
	m.Parent = workspace
	return m
end

local function groupTreeAndFruits(tree: Model, fruits: { Model })
	local container = getOrCreateMature()
	container:SetAttribute("MangoDisplay", true)

	if tree ~= container then
		tree.Parent = container
	end
	for i, fruit in fruits do
		if fruit ~= container and fruit ~= tree then
			fruit.Parent = container
		end
		print("[Mango]  fruit", i, "→", fruit.Name)
	end
	if tree ~= container then
		print("[Mango]  tree →", tree.Name)
	end
end

local selected = Selection:Get()
local models: { Model } = {}
for _, inst in selected do
	if inst:IsA("Model") then
		table.insert(models, inst)
	end
end

if #models == 8 then
	sortByX(models)
	models[1].Name = DISPLAY.sprout
	models[1]:SetAttribute("MangoDisplay", true)
	models[2].Name = DISPLAY.growing
	models[2]:SetAttribute("MangoDisplay", true)
	groupTreeAndFruits(models[3], { models[4], models[5], models[6], models[7] })
	models[8].Name = DISPLAY.harvest
	models[8]:SetAttribute("MangoDisplay", true)
	print("[Mango] Prepared 8-stage row (sprout → harvest)")
elseif #models == 4 then
	sortByX(models)
	models[1].Name = DISPLAY.sprout
	models[1]:SetAttribute("MangoDisplay", true)
	models[2].Name = DISPLAY.growing
	models[2]:SetAttribute("MangoDisplay", true)
	if models[3].Name ~= MATURE_NAME then
		models[3].Name = MATURE_NAME
	end
	models[3]:SetAttribute("MangoDisplay", true)
	models[4].Name = DISPLAY.harvest
	models[4]:SetAttribute("MangoDisplay", true)
	print("[Mango] Prepared 4 display names (mature must contain tree + 4 fruits)")
elseif #models == 5 then
	sortByX(models)
	groupTreeAndFruits(models[1], { models[2], models[3], models[4], models[5] })
	print("[Mango] Grouped tree + 4 fruits under", MATURE_NAME)
else
	error("[Mango] Select 8 (full row), 4 (sprout/growing/mature/harvest), or 5 (tree + 4 fruits). Got: " .. #models)
end

print("[Mango] Next: IntegrateMango.lua")
