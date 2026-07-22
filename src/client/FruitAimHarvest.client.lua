--!strict
-- Harvest multi-harvest fruits by aiming at the visible fruit model and pressing E.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FruitHarvestConfig = require(ReplicatedStorage:WaitForChild("Modules").FruitHarvestConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local world = workspace:WaitForChild("World")
local plantedSeeds = world:WaitForChild("Map"):WaitForChild("PlantedSeeds")
local clientFolder = plantedSeeds:WaitForChild("Client")
local serverFolder = plantedSeeds:WaitForChild("Server")

local lastHarvestClock = 0

local function getPlantKeyAndFruitNumber(hit: Instance): (string?, string?)
	local current: Instance? = hit
	while current and current ~= workspace do
		if current:IsA("Model") then
			local fruitIndex = string.match(current.Name, "^fruit_(%d+)$")
			if fruitIndex then
				local clientPlant = current.Parent
				if clientPlant and clientPlant:IsA("Model") and clientPlant.Parent == clientFolder then
					return clientPlant.Name, fruitIndex
				end
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function canHarvestServerPlant(serverModel: Model, fruitNumber: string): boolean
	if serverModel:GetAttribute("Owner") ~= player.UserId then
		return false
	end

	local serverConfig = serverModel:FindFirstChild("ServerConfiguration")
	if not serverConfig then
		return false
	end

	local growth = serverConfig:FindFirstChild("GrowthPercentage")
	if not growth or growth.Value < 100 then
		return false
	end

	local fruitFolder = serverConfig:FindFirstChild("Fruits") and serverConfig.Fruits:FindFirstChild(fruitNumber)
	if not fruitFolder then
		return false
	end

	local canHarvest = fruitFolder:FindFirstChild("CanHarvest")
	if not canHarvest or canHarvest.Value ~= true then
		return false
	end

	local fruitPrompts = serverModel:FindFirstChild("FruitPrompts")
	local fruitPart = fruitPrompts and fruitPrompts:FindFirstChild(fruitNumber)
	local prompt = fruitPart and fruitPart:FindFirstChild("HarvestPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
		return false
	end

	return true
end

local function tryHarvestUnderMouse()
	if UserInputService:GetFocusedTextBox() then
		return
	end

	local now = os.clock()
	if now - lastHarvestClock < FruitHarvestConfig.CLIENT_DEBOUNCE then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { serverFolder }
	local character = player.Character
	if character then
		table.insert(exclude, character)
	end
	params.FilterDescendantsInstances = exclude

	local result = workspace:Raycast(ray.Origin, ray.Direction * FruitHarvestConfig.RAYCAST_DISTANCE, params)
	if not result then
		return
	end

	local plantKey, fruitNumber = getPlantKeyAndFruitNumber(result.Instance)
	if not plantKey or not fruitNumber then
		return
	end

	local serverModel = serverFolder:FindFirstChild(plantKey)
	if not serverModel or not serverModel:IsA("Model") then
		return
	end

	if not canHarvestServerPlant(serverModel, fruitNumber) then
		return
	end

	lastHarvestClock = now
	remotes.Harvest:FireServer(plantKey, fruitNumber)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.E then
		tryHarvestUnderMouse()
	end
end)
