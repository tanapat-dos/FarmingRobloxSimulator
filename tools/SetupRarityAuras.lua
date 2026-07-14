-- Command bar: adds Rarity StringValue to PlotService FruitConfigTemplate if missing.
-- Harvest rarity glow is code-only (Highlight + PointLight) — no aura asset needed.

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

print("[SetupRarityAuras] Harvest glow uses Highlight + PointLight (no aura mesh required)")
