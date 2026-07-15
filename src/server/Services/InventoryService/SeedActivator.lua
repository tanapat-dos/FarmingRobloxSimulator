local debris = game:GetService("Debris")
local replicatedStorage = game:GetService("ReplicatedStorage")

local remotes = replicatedStorage.RemoteEvents

local cachedModules = require(game.ServerScriptService.Server.CachedModules)
local plantKeyUtil = require(replicatedStorage.Modules.PlantKeyUtil)
local seedService = cachedModules.Cache.SeedShopService
local plotService = cachedModules.Cache.PlotService

local Activator = {}

local Tool: Tool = script.Parent
local Player: Player = Tool.Parent.Parent

Tool.Activated:Connect(function()
	if Player:FindFirstChild("SeedPlantDebounce") then
		return
	end
	
	local playerPlot: Model = plotService.getPlot(Player)
	local db = Instance.new("BoolValue")
	db.Name = "SeedPlantDebounce"
	db.Parent = Player
	debris:AddItem(db,0.5)
	
	if playerPlot then

		local ok, mouseCFrame = pcall(function()
			return remotes.GetMouseCF:InvokeClient(Player)
		end)
		if ok and typeof(mouseCFrame) == "CFrame" then
			if not plotService.locationIsWithinPlot(playerPlot,mouseCFrame) then
				return
			end
			local seedName = Tool:GetAttribute("Name")
			if not seedName then
				return
			end

			local cropName = plantKeyUtil.resolveCropName(seedName)
			local plantModel = replicatedStorage.Assets.Plants:FindFirstChild(cropName)

			if plantModel then
				local mockPlantModel = plantModel.ServerModel:Clone()
				
				-- Plant Scale
				local PlantSize = seedService.getRandomPlantSize(Tool.Name, {})
				
				mockPlantModel:ScaleTo(PlantSize)
				
				local plotCFrame, plotSize = playerPlot.Soil:GetBoundingBox()
				
				local plotTopY = plotCFrame.Position.Y + plotSize.Y/2
				local plantHeightOffset = mockPlantModel.PrimaryPart.Size.Y/2
				
				local spawnPosition = Vector3.new(
					mouseCFrame.Position.X,
					plotTopY+plantHeightOffset,
					mouseCFrame.Position.Z
				)
				spawnPosition = CFrame.new(spawnPosition)
				
				mockPlantModel:Destroy()
				
				seedService.plantSeed(Player, seedName, spawnPosition, PlantSize)
			end
			
		end	
	end
	
end)

return Activator
