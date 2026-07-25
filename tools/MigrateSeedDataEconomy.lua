--[[
	SEEDDATA ECONOMY MIGRATION
	Paste into the Studio Command Bar.

	Pushes EconomyBalance.CROPS values into the live ReplicatedStorage.Modules.SeedData
	instance tree, which is what the game actually reads at runtime (GetFruitValue and
	SeedShopService.GenerateStock both read SeedData, not EconomyBalance).

	Writes:  Price, BaseValue, GrowthTime, Rarity
	Skips:   HarvestCount, HarvestInterval, MultiHarvest  (bound to fruit attachment points
	         on the plant mesh — changing them desyncs the model. Design Property 7.)

	Rarity MUST be migrated: many crops changed tier in the rebalance (Tomato Uncommon->Rare,
	Grape Rare->Legendary, Pineapple Epic->Legendary, ...) and GenerateStock reads
	SeedData.Rarity for both the stock range and the appearance roll.

	Idempotent — safe to re-run. Prints a before/after line for every change.
	Run tools/VerifyEconomyMath.lua afterwards to confirm agreement.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyBalance = require(ReplicatedStorage.Modules.EconomyBalance)
local seedDataFolder = ReplicatedStorage.Modules.SeedData

-- instance name -> EconomyBalance.CROPS key
local FIELDS = {
	{ instance = "Price", key = "price" },
	{ instance = "BaseValue", key = "baseValue" },
	{ instance = "GrowthTime", key = "growthTime" },
	{ instance = "Rarity", key = "rarity" },
}

-- Never written: mesh-bound.
local PROTECTED = {
	HarvestCount = true,
	HarvestInterval = true,
	MultiHarvest = true,
}

local function classFor(value: any): string?
	if typeof(value) == "number" then
		return if math.floor(value) == value then "IntValue" else "NumberValue"
	elseif typeof(value) == "string" then
		return "StringValue"
	elseif typeof(value) == "boolean" then
		return "BoolValue"
	end
	return nil
end

--[[
	Sets folder[name] = value, creating the value object if absent.
	Numbers always land in a NumberValue so fractional baseValues (e.g. 977.7) are not
	silently truncated by an existing IntValue.
]]
local function setValue(folder: Instance, name: string, value: any): (boolean, string?)
	if PROTECTED[name] then
		return false, "protected"
	end

	local wantClass = classFor(value)
	if not wantClass then
		return false, "unsupported type"
	end
	if typeof(value) == "number" then
		wantClass = "NumberValue"
	end

	local child = folder:FindFirstChild(name)

	-- Replace a wrong-class holder (e.g. IntValue holding a fractional baseValue)
	if child and child.ClassName ~= wantClass then
		local old = child.Value
		child:Destroy()
		child = nil
		local replacement = Instance.new(wantClass)
		replacement.Name = name
		replacement.Value = value
		replacement.Parent = folder
		return true, ("%s -> %s (reclassed %s)"):format(tostring(old), tostring(value), wantClass)
	end

	if not child then
		local created = Instance.new(wantClass)
		created.Name = name
		created.Value = value
		created.Parent = folder
		return true, ("(missing) -> %s"):format(tostring(value))
	end

	local old = child.Value
	if typeof(value) == "number" and math.abs(old - value) < 0.001 then
		return false, nil -- already correct
	elseif old == value then
		return false, nil
	end

	child.Value = value
	return true, ("%s -> %s"):format(tostring(old), tostring(value))
end

-- ------------------------------------------------------------------ run
print("=== SeedData economy migration ===")

local changed, skipped, missing = 0, 0, 0

-- Stable ordering for a readable log
local seedNames = {}
for seedName in EconomyBalance.CROPS do
	table.insert(seedNames, seedName)
end
table.sort(seedNames)

for _, seedName in seedNames do
	local cfg = EconomyBalance.CROPS[seedName]
	local folder = seedDataFolder:FindFirstChild(seedName)

	if not folder then
		warn(("  MISSING SeedData folder: %s (skipped, not created)"):format(seedName))
		missing += 1
		continue
	end

	local lines = {}
	for _, field in FIELDS do
		local value = cfg[field.key]

		-- Crystal Blooms is bought with Fish Coins; its cash Price is not authoritative and
		-- writing 0 could make it look free to anything that reads SeedData.Price directly.
		if field.instance == "Price" and (value == nil or value == 0) then
			table.insert(lines, ("    %-11s skipped (non-cash currency)"):format(field.instance))
			continue
		end

		if value == nil then
			continue
		end

		local didChange, note = setValue(folder, field.instance, value)
		if didChange then
			changed += 1
			table.insert(lines, ("    %-11s %s"):format(field.instance, note))
		else
			skipped += 1
		end
	end

	if #lines > 0 then
		print(("  %s"):format(seedName))
		for _, line in lines do
			print(line)
		end
	end
end

print(("=== Done: %d field(s) changed, %d already correct, %d crop(s) missing ==="):format(
	changed, skipped, missing))

if missing > 0 then
	warn("Some crops have no SeedData folder. Run their tools/Integrate*.lua script first.")
end

print("Next: run tools/VerifyEconomyMath.lua to confirm SeedData matches EconomyBalance.")
print("Then Stop -> Play -> Ctrl+S so the change is saved into the place file.")
