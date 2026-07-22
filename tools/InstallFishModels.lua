--[[
	INSTALL FISH MODELS
	Paste into Studio Command Bar and press Enter.

	Copies named meshes from the saltwater fish pack (asset 10851288693)
	into ReplicatedStorage.Assets.FishModels for the fishing minigame UI.
	Strips demo scripts from the source pack.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSET_ID = 10851288693
local FISH_MODEL_NAMES = {
	"Saupe Fish",
	"Blue Fish",
	"Mullet",
	"Cod",
	"Red Snapper",
	"Tuna",
	"Amberjack",
	"Barracuda ",
	"Bicolor Blenny",
	"Boxfish",
	"Cobia",
	"Grouper",
	"Longbill Spearfish",
	"Octopus",
	"opah",
	"pompano",
	"Rooster Fish",
	"Yellowtail Barracuda ",
	"clown trigger fish",
}

local function stripScripts(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = ReplicatedStorage

local fishModels = assets:FindFirstChild("FishModels") or Instance.new("Folder")
fishModels.Name = "FishModels"
fishModels.Parent = assets

local sourcePack = workspace:FindFirstChild("FishPackPreview")
if not sourcePack then
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(ASSET_ID)
	end)
	if ok and asset then
		sourcePack = asset:FindFirstChildWhichIsA("Model", true)
	end
end

if not sourcePack then
	error("[InstallFishModels] Could not find fish pack. Insert asset 10851288693 first.")
end

local root = sourcePack:FindFirstChild("Saltwater fish pack") or sourcePack
stripScripts(root)

local installed = 0
for _, modelName in FISH_MODEL_NAMES do
	local source = root:FindFirstChild(modelName)
	if source and source:IsA("MeshPart") then
		local existing = fishModels:FindFirstChild(modelName)
		if existing then
			existing:Destroy()
		end

		local clone = source:Clone()
		clone.Name = modelName
		clone.Anchored = true
		clone.CanCollide = false
		clone.Parent = fishModels
		installed += 1
	end
end

print(string.format("[InstallFishModels] Installed %d fish meshes under ReplicatedStorage.Assets.FishModels", installed))
