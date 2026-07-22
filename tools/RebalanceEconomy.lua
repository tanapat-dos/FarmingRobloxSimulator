--[[
	ECONOMY REBALANCE — paste into Studio Command Bar (View → Command Bar) and press Enter.

	Applies seed prices / sell values / growth times from ReplicatedStorage.Modules.EconomyBalance
	to every SeedData folder. **Gameplay grow timers use SeedData.GrowthTime IntValues**, not
	EconomyBalance alone — run this after changing growth times in Rojo.

	Save the place after running.
]]

local EconomyBalance = require(game.ReplicatedStorage.Modules.EconomyBalance)
local seedDataRoot = game.ReplicatedStorage.Modules.SeedData

local function setValue(folder: Instance, name: string, value: any)
	local child = folder:FindFirstChild(name)
	if not child then
		if typeof(value) == "number" then
			if math.floor(value) == value then
				child = Instance.new("IntValue")
			else
				child = Instance.new("NumberValue")
			end
		elseif typeof(value) == "string" then
			child = Instance.new("StringValue")
		elseif typeof(value) == "boolean" then
			child = Instance.new("BoolValue")
		else
			warn("[RebalanceEconomy] Unsupported type for", name, typeof(value))
			return
		end
		child.Name = name
		child.Parent = folder
	end
	child.Value = value
end

local updated = 0
for seedName, cfg in pairs(EconomyBalance.CROPS) do
	local folder = seedDataRoot:FindFirstChild(seedName)
	if folder then
		setValue(folder, "Price", cfg.price)
		setValue(folder, "BaseValue", cfg.baseValue)
		setValue(folder, "GrowthTime", cfg.growthTime)
		setValue(folder, "Rarity", cfg.rarity)
		if cfg.multiHarvest ~= nil then
			setValue(folder, "MultiHarvest", cfg.multiHarvest)
		end
		if cfg.harvestCount ~= nil then
			setValue(folder, "HarvestCount", cfg.harvestCount)
		end
		if cfg.harvestInterval ~= nil then
			setValue(folder, "HarvestInterval", cfg.harvestInterval)
		end
		updated += 1
		print(string.format(
			"[RebalanceEconomy] %s → $%d seed, base $%d, %ds, %s",
			seedName,
			cfg.price,
			cfg.baseValue,
			cfg.growthTime,
			cfg.rarity
		))
	else
		warn("[RebalanceEconomy] Missing SeedData folder:", seedName)
	end
end

print(string.format(
	"[RebalanceEconomy] Done — %d crops updated. Starting cash = $%d",
	updated,
	EconomyBalance.STARTING_CASH
))
print("[RebalanceEconomy] Egg costs:", EconomyBalance.EGG_ORDER[1], EconomyBalance.EGGS["Common Egg"].cost, "→", EconomyBalance.EGG_ORDER[#EconomyBalance.EGG_ORDER], EconomyBalance.EGGS["Divine Egg"].cost)
