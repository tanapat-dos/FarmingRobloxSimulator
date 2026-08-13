local debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(game.ServerScriptService.Server.CachedModules)
local plotService = cachedModules.Cache.PlotService
local inventoryService = cachedModules.Cache.InventoryService

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

	local Sound = tool.Handle:FindFirstChild("Sound")
	if Sound then
		Sound:Play()
	end

	local playerPlot: Model = plotService.getPlot(Player)
	if not playerPlot then
		return
	end

	-- The client serves this RemoteFunction: pcall + type-check so a
	-- malicious/erroring client can't hang or crash this server thread,
	-- and never trust the returned value's type.
	local ok, mouseCFrame = pcall(function()
		return remotes.GetMouseCF:InvokeClient(Player)
	end)
	if not ok or typeof(mouseCFrame) ~= "CFrame" then
		return
	end

	-- Consume a charge only when the gear actually did something.
	local used = false

	if toolName == "Shovel" then
		print("SHOVEL TIME!")
		used = true
	elseif toolName == "WateringCan" then
		print("💧 Watering plants!")
		used = true
	elseif toolName == "Trowel" then
		print("⛏️ Digging with trowel!")
		used = true
	elseif toolName == "RecallWrench" then
		local tpPart = playerPlot:FindFirstChild("TPPart")
		local character = Player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if tpPart and hrp then
			hrp.Position = tpPart.Position
			used = true
		end
	else
		warn("⚠️ Gear not recognized:", toolName)
	end

	if used then
		inventoryService.removeItem(Player, toolName, 1)
	end

end)

return Activator
