--[[
	PREPARE CRYSTAL BLOOMS DISPLAY MODELS (non-destructive)
	Paste into Studio Command Bar.

	Select exactly 4 Models in Explorer (sprout → growing → mature → harvest, left to right),
	then run. Renames them to:

	  Crystal Blooms Sprout / Growing / Mature / Harvest

	Asset unique ids (usually the Model name after import):
	  sprout  …000e56
	  growing …000e42
	  mature  …00021c9
	  harvest …000dee

	Then run IntegrateCrystalBlooms.lua
--]]

local Selection = game:GetService("Selection")

local DISPLAY = {
	"Crystal Blooms Sprout",
	"Crystal Blooms Growing",
	"Crystal Blooms Mature",
	"Crystal Blooms Harvest",
}

local selected = Selection:Get()
if #selected ~= 4 then
	error("[CrystalBlooms] Select exactly 4 Models (sprout, growing, mature, harvest). Selected: " .. #selected)
end

local models: { Model } = {}
for _, inst in selected do
	if not inst:IsA("Model") then
		error("[CrystalBlooms] Each selection must be a Model, got " .. inst.ClassName)
	end
	table.insert(models, inst)
end

table.sort(models, function(a, b)
	local pa = a:GetPivot().Position
	local pb = b:GetPivot().Position
	if math.abs(pa.X - pb.X) > 0.25 then
		return pa.X < pb.X
	end
	return pa.Z < pb.Z
end)

for i, name in DISPLAY do
	models[i].Name = name
	models[i]:SetAttribute("CrystalBloomsDisplay", true)
	print("[CrystalBlooms] Prepared", name)
end

print("[CrystalBlooms] Done. Next: IntegrateCrystalBlooms.lua")
