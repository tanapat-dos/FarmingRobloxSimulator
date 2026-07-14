local debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(game.ServerScriptService.Server.CachedModules)
local plotService = cachedModules.Cache.PlotService
local inventoryService = cachedModules.Cache.InventoryService
local ToolData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ToolData"))

local GearShop = Workspace:WaitForChild("Shops").GearShop:WaitForChild("TPPart")

local Activator = {}

local tool: Tool = script.Parent
local Player: Player = tool.Parent.Parent

tool.Activated:Connect(function()

	if Player:FindFirstChild("GearToolDebounce") then return end
	local db = Instance.new("BoolValue")
	db.Name = "GearToolDebounce"
	db.Parent = Player
	debris:AddItem(db, 0.5)
	
	local toolName = tool:GetAttribute("Name")
	
	local Sound = tool.Handle.Sound
	Sound:Play()

	local playerPlot: Model = plotService.getPlot(Player)
	if playerPlot then
		local mouseCFrame = remotes.GetMouseCF:InvokeClient(Player)
		if mouseCFrame then
			
			if toolName == "Shovel" then
				print("SHOVEL TIME!")
			elseif toolName == "WateringCan" then
				print("💧 Watering plants!")
			elseif toolName == "Trowel" then
				print("⛏️ Digging with trowel!")
			elseif toolName == "RecallWrench" then
				Player.Character:WaitForChild("HumanoidRootPart").Position = GearShop.Position
				print("Recalled")
			else
				warn("⚠️ Gear not recognized:", toolName)
			end
			
		end
	end
	
	inventoryService.removeItem(Player,toolName,1)
	
end)

return Activator
