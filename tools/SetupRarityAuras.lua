-- Command bar: adds Rarity StringValue to PlotService FruitConfigTemplate if missing.
-- Harvest rarity glow: Highlight + PointLight + ReplicatedStorage.Assets.RarityAuras.Generic sparkler.

local ServerScriptService = game:GetService("ServerScriptService")

local plotService = ServerScriptService:FindFirstChild("Services")
	and ServerScriptService.Services:FindFirstChild("PlotService")
local template = plotService and plotService:FindFirstChild("FruitConfigTemplate")
if template and not template:FindFirstChild("Rarity") then
	local rarity = Instance.new("StringValue")
	rarity.Name = "Rarity"
	rarity.Value = "Common"
	rarity.Parent = template
	print("[SetupRarityAuras] Added Rarity to FruitConfigTemplate")
else
	print("[SetupRarityAuras] FruitConfigTemplate.Rarity already exists")
end

print("[SetupRarityAuras] Ensure ReplicatedStorage.Assets.RarityAuras.Generic exists (Sparkles + Mist).")
