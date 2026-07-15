local replicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Service = {}

local assets = replicatedStorage:WaitForChild("Assets")
local modules = replicatedStorage:WaitForChild("Modules")

local seedDataModule = require(modules.SeedData)
local plantKeyUtil = require(modules.PlantKeyUtil)
local EconomyBalance = require(modules.EconomyBalance)

local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local PLOTS = EconomyBalance.PLOTS

function Service.getOwnedBedCount(player: Player): number
	local dataService = cachedModules.Cache.DataService
	local data = dataService and dataService.getData(player)
	local owned = data and data.PlotsOwned or PLOTS.startOwned
	return math.clamp(owned, 1, PLOTS.maxOwned)
end

function Service.getSoilBeds(plot: Model): { BasePart }
	local soil = plot:FindFirstChild("Soil")
	if not soil then
		return {}
	end

	local beds = {}
	for _, part in soil:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(beds, part)
		end
	end

	-- Deterministic order: closest to the garden entrance (TPPart) first,
	-- so the free starter bed is always the one by the gate.
	local ref = plot:FindFirstChild("TPPart")
	local refPos = ref and ref.Position or plot:GetPivot().Position
	table.sort(beds, function(a, b)
		local da = (a.Position - refPos).Magnitude
		local db = (b.Position - refPos).Magnitude
		if math.abs(da - db) > 0.01 then
			return da < db
		end
		if math.abs(a.Position.X - b.Position.X) > 0.01 then
			return a.Position.X < b.Position.X
		end
		return a.Position.Z < b.Position.Z
	end)
	return beds
end

function Service.locationIsWithinPlot(plot: Model, location: CFrame)
	if not (plot and location) then
		return false
	end

	-- Only beds the plot owner has unlocked accept new plants
	local unlocked = {}
	local owner = Players:GetPlayerByUserId(plot:GetAttribute("USERID") or 0)
	local ownedCount = owner and Service.getOwnedBedCount(owner) or 0
	for index, bed in Service.getSoilBeds(plot) do
		if index <= ownedCount then
			table.insert(unlocked, bed)
		end
	end
	if #unlocked == 0 then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = unlocked
	local result = workspace:Raycast(location.Position + Vector3.new(0, 5, 0), Vector3.new(0, -999999, 0), params)
	return result ~= nil
end

function Service.getMaxPlots()
	return #workspace.Plots:GetChildren()
end

function Service.getPlot(player:Player)
	for _, plot: Model in workspace.Plots:GetChildren() do
		if plot:GetAttribute("Taken") == true and plot:GetAttribute("USERID") == player.UserId then
			return plot
		end
	end
	return nil
end

function Service.getAvailablePlot(player:Player)
	for i = 1, Service.getMaxPlots() do
		local correspondingPlot: Model = workspace.Plots[tostring(i)]
		if correspondingPlot:GetAttribute("Taken") == true then
			continue
		end
		return correspondingPlot
	end
end

function Service.getHarvestPromptDistance(plantSize: number): number
	local size = plantSize or 1
	return math.clamp(14 + (size - 1) * 12, 18, 50)
end

function Service.alignHarvestAnchor(serverModel: Model, cropName: string, plantSize: number)
	local anchor = serverModel:FindFirstChild("HarvestAnchor")
	local plantFolder = assets.Plants:FindFirstChild(cropName)
	if not anchor or not plantFolder then
		return
	end

	local clientModel = plantFolder:FindFirstChild("ClientModel")
	if not clientModel then
		return
	end

	local scale = plantSize or 1
	local finalMesh = clientModel:FindFirstChild("SM_" .. cropName)
	if finalMesh and finalMesh:IsA("BasePart") then
		local anchorY = (finalMesh.Position.Y + finalMesh.Size.Y * 0.35) * scale
		anchor.CFrame = CFrame.new(0, anchorY, 0)
		return
	end

	local temp = clientModel:Clone()
	temp:ScaleTo(scale)
	local cf, size = temp:GetBoundingBox()
	local localPos = serverModel:GetPivot():ToObjectSpace(CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.35, 0)))
	anchor.CFrame = CFrame.new(0, localPos.Y, 0)
	temp:Destroy()
end

local function rollHarvestRarityForCrop(cropName: string): string
	local rarityService = cachedModules.Cache.RarityService
	if not rarityService then
		local rarityModule = script.Parent:FindFirstChild("RarityService")
		if rarityModule and rarityModule:IsA("ModuleScript") then
			local ok, loaded = pcall(require, rarityModule)
			if ok then
				rarityService = loaded
				cachedModules.Cache.RarityService = loaded
			end
		end
	end

	if rarityService and typeof(rarityService.rollHarvestRarity) == "function" then
		local ok, result = pcall(rarityService.rollHarvestRarity, cropName)
		if ok and typeof(result) == "string" and result ~= "" then
			return result
		end
	end

	return "Common"
end

local function darken(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local function notify(player: Player, message: string, kind: string?)
	local remote = replicatedStorage.RemoteEvents:FindFirstChild("Notify")
	if remote then
		remote:FireClient(player, message, kind or "info")
	end
end

function Service.buyBed(buyer: Player, plot: Model, bedIndex: number)
	local dataService = cachedModules.Cache.DataService
	local moneyService = cachedModules.Cache.MoneyService

	if plot:GetAttribute("USERID") ~= buyer.UserId then
		notify(buyer, "You can only buy plots in your own garden!", "error")
		return
	end

	local data = dataService.getData(buyer)
	if not data then
		return
	end

	local owned = Service.getOwnedBedCount(buyer)
	if owned >= PLOTS.maxOwned then
		return
	end
	if bedIndex ~= owned + 1 then
		notify(buyer, "Buy plots in order — the next one is highlighted.", "error")
		return
	end

	local price = PLOTS.prices[bedIndex]
	if typeof(price) ~= "number" or price <= 0 then
		return
	end
	if not moneyService.removeCash(buyer, price) then
		notify(buyer, ("You need $%d for this plot."):format(price), "error")
		return
	end

	data.PlotsOwned = owned + 1
	Service.setupBeds(buyer, plot)
	notify(buyer, ("Plot %d unlocked! You can now grow %d crops."):format(
		data.PlotsOwned, data.PlotsOwned * PLOTS.cropsPerPlot), "success")
end

function Service.setupBeds(player: Player, plot: Model)
	local owned = Service.getOwnedBedCount(player)

	for index, bed in Service.getSoilBeds(plot) do
		bed:SetAttribute("BedIndex", index)

		local originalColor = bed:GetAttribute("OriginalColor")
		if not originalColor then
			originalColor = bed.Color
			bed:SetAttribute("OriginalColor", originalColor)
		end

		local oldLock = bed:FindFirstChild("PlotLock")
		if oldLock then
			oldLock:Destroy()
		end

		if index <= owned then
			bed.Color = originalColor
		elseif index <= PLOTS.maxOwned then
			bed.Color = darken(originalColor, 0.55)

			local lock = Instance.new("Folder")
			lock.Name = "PlotLock"

			local billboard = Instance.new("BillboardGui")
			billboard.Name = "LockSign"
			billboard.Size = UDim2.fromOffset(150, 40)
			billboard.StudsOffset = Vector3.new(0, 4, 0)
			billboard.AlwaysOnTop = true
			billboard.MaxDistance = 70
			billboard.Parent = lock

			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
			label.BackgroundTransparency = 0.3
			label.TextColor3 = Color3.fromRGB(255, 216, 120)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.Text = ("🔒 Plot %d — $%d"):format(index, PLOTS.prices[index] or 0)
			label.Parent = billboard

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = label

			-- Only the NEXT bed gets a working prompt; later ones just show price
			if index == owned + 1 then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "BuyPrompt"
				prompt.ActionText = ("Buy Plot — $%d"):format(PLOTS.prices[index] or 0)
				prompt.ObjectText = "Locked Plot"
				prompt.HoldDuration = 0.4
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = lock

				prompt.Triggered:Connect(function(buyer)
					Service.buyBed(buyer, plot, index)
				end)
			end

			lock.Parent = bed
		else
			-- Reserved beds beyond maxOwned: dark, no purchase path (yet)
			bed.Color = darken(originalColor, 0.4)
		end
	end
end

function Service.clearBeds(plot: Model)
	for _, bed in Service.getSoilBeds(plot) do
		local lock = bed:FindFirstChild("PlotLock")
		if lock then
			lock:Destroy()
		end
		local originalColor = bed:GetAttribute("OriginalColor")
		if originalColor then
			bed.Color = originalColor
		end
		bed:SetAttribute("BedIndex", nil)
	end
end

function Service.createServerModel(player: Player, key: string, data: any)
	local dataService = cachedModules.Cache.DataService
	local playerData = dataService.getData(player)

	local plotData = playerData.PlotData
	local saveData = plotData[key]

	local trueName = plantKeyUtil.resolveCropName(key)
	local correspondingFolder = assets.Plants:FindFirstChild(trueName)

	local seedData = seedDataModule.getData(plantKeyUtil.getSeedName(key))

	if correspondingFolder and saveData and seedData then
		local serverModel: Model = correspondingFolder.ServerModel:Clone()
		serverModel.Name = key
		serverModel:SetAttribute("Owner", player.UserId)
		serverModel:SetAttribute("Plot", Service.getPlot(player).Name)

		-- Scaling
		serverModel:ScaleTo(data.PlantSize)
		Service.alignHarvestAnchor(serverModel, trueName, data.PlantSize)

		local serverConfig = script.ServerModelConfig:Clone()
		serverConfig.Name = "ServerConfiguration"

		serverConfig.DatePlanted.Value = data.DatePlanted
		serverConfig.GrowthPercentage.Value = data.GrowthPercentage
		serverConfig.LastGrowthIncrement.Value = data.LastGrowthIncrement
		serverConfig.PlantSize.Value = data.PlantSize

		for index: number, fruitData: any in data.Fruits do
			if fruitData.Rarity == nil then
				fruitData.Rarity = "Common"
			end

			local fruitConfig = script.FruitConfigTemplate:Clone()
			fruitConfig.Name = tostring(index)

			fruitConfig.CanHarvest.Value = fruitData.CanHarvest
			fruitConfig.LastHarvest.Value = fruitData.LastHarvest
			fruitConfig.Mutations.Value = fruitData.Mutations
			fruitConfig.SizeScaling.Value = fruitData.SizeScaling
			if fruitConfig:FindFirstChild("Rarity") then
				fruitConfig.Rarity.Value = fruitData.Rarity or "Common"
			end

			fruitConfig.Parent = serverConfig.Fruits

			for _,v in fruitConfig:GetChildren() do
				if not v:IsA("Folder") then
					v.Changed:Connect(function()
						if saveData.Fruits[index][v.Name] ~= nil then
							saveData.Fruits[index][v.Name] = v.Value
						end
					end)
				end
			end	
		end

		-- Creating Proximity Prompts
		if seedData.MultiHarvest.Value then
			local fruitsPrompts = serverModel:FindFirstChild("FruitPrompts")
			if fruitsPrompts then
				for _,v in serverConfig.Fruits:GetChildren() do
					local correspondingPart: Part = fruitsPrompts:FindFirstChild(v.Name)
					if correspondingPart then
						local harvestPrompt = script.HarvestPrompt:Clone()
						harvestPrompt.ActionText = "Harvest"
						harvestPrompt.ObjectText = trueName
						harvestPrompt.HoldDuration = 0
						harvestPrompt.Enabled = false
						harvestPrompt.Parent = correspondingPart
					end
				end
			end
		else
			local harvestHost = serverModel:FindFirstChild("HarvestAnchor") or serverModel.PrimaryPart
			local harvestPrompt = script.HarvestPrompt:Clone()
			harvestPrompt.ActionText = "Harvest"
			harvestPrompt.ObjectText = trueName
			harvestPrompt.HoldDuration = 0
			harvestPrompt.Enabled = false
			harvestPrompt.RequiresLineOfSight = false
			harvestPrompt.MaxActivationDistance = Service.getHarvestPromptDistance(data.PlantSize)
			harvestPrompt.Parent = harvestHost
		end

		-- Updating Service Config Folder
		for _,v in serverConfig:GetChildren() do
			if not v:IsA("Folder") then
				v.Changed:Connect(function()
					if saveData[v.Name] ~= nil then
						saveData[v.Name] = v.Value
					end
				end)
			end
		end

		serverConfig.Parent = serverModel

		-- Deserialize CFrame, preserving rotation
		local deserializedCFrame = CFrame.new(table.unpack(data.Location))

		-- Transform relative to plot's ReferencePoint
		local plot = Service.getPlot(player)
		if not plot then
			warn("No plot found for player:", player.Name)
			return
		end
		deserializedCFrame = plot.ReferencePoint.CFrame:ToWorldSpace(deserializedCFrame)

		-- Snap to soil surface using raycast
		local soil = plot:FindFirstChild("Soil")
		if soil then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = {soil}
			local result = workspace:Raycast(deserializedCFrame.Position + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), params)
			if result and result.Instance:IsDescendantOf(soil) then
				-- Adjust Y-position to snap to soil surface
				deserializedCFrame = CFrame.new(result.Position) * CFrame.new(0, serverModel.PrimaryPart.Size.Y / 2, 0) * CFrame.Angles(0, deserializedCFrame:ToEulerAnglesXYZ())
			else
				warn("No soil hit for plant at:", deserializedCFrame.Position)
			end
		else
			warn("No soil found in plot:", plot.Name)
		end

		-- Apply position and parent
		serverModel:PivotTo(deserializedCFrame)
		serverModel.Parent = workspace.World.Map.PlantedSeeds.Server
	else
		warn(
			"[PlotService] Failed to spawn plant",
			key,
			"crop=",
			trueName,
			"folder=",
			correspondingFolder ~= nil,
			"save=",
			saveData ~= nil,
			"seed=",
			seedData ~= nil
		)
	end
end

function Service.updatePlot(player:Player, action: string, data: any)
	local playerData = cachedModules.Cache.DataService.getData(player)
	if playerData then
		if action == "seedPlanted" then
			local itemKey: string = data.itemKey
			print(itemKey)
			if itemKey then
				local newItemData = playerData.PlotData[itemKey]
				if newItemData then
					Service.createServerModel(player,itemKey,newItemData)
				end
			end
		end
	end 
end

function Service.dataLoaded(player: Player)
	local plot = Service.getAvailablePlot(player)
	if not plot then return end

	-- 🔧 Mark plot as taken
	plot:SetAttribute("Taken", true)
	plot:SetAttribute("USERID", player.UserId)
	plot:WaitForChild("PlayerSign").Main.SurfaceGui.TextLabel.Text = player.Name .. "'s Garden"

	-- 🧱 Setup Owner_Tag
	local ownerTag = plot:FindFirstChild("Owner_Tag")
	if not ownerTag then
		warn("Owner_Tag part not found in plot: " .. plot.Name)
		return
	end

	-- 🔄 Cleanup any old UI/script
	local existingBillboard = ownerTag:FindFirstChild("AvatarGui")
	if existingBillboard then existingBillboard:Destroy() end

	local existingScript = ownerTag:FindFirstChild("OwnerTagScript")
	if existingScript then existingScript:Destroy() end

	local importantFolder = ownerTag:FindFirstChild("Important") or Instance.new("Folder")
	importantFolder.Name = "Important"
	importantFolder.Parent = ownerTag

	local dataFolder = importantFolder:FindFirstChild("Data") or Instance.new("Folder")
	dataFolder.Name = "Data"
	dataFolder.Parent = importantFolder

	local ownerValue = dataFolder:FindFirstChild("Owner") or Instance.new("StringValue")
	ownerValue.Name = "Owner"
	ownerValue.Value = player.Name
	ownerValue.Parent = dataFolder

	-- 🧍‍♂️ Create Avatar BillboardGui
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "AvatarGui"
	billboardGui.Size = UDim2.new(15, 0, 15, 0)
	billboardGui.StudsOffset = Vector3.new(0, 4, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.MaxDistance = 100
	billboardGui.Parent = ownerTag

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Size = UDim2.new(1, 0, 1, 0)
	imageLabel.BackgroundTransparency = 1

	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size420x420
	local content, isReady = Players:GetUserThumbnailAsync(player.UserId, thumbType, thumbSize)
	imageLabel.Image = (isReady and content) or ""
	imageLabel.ImageTransparency = 0

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0.5, 0)
	uiCorner.Parent = imageLabel

	imageLabel.Parent = billboardGui

	-- 🪪 Update Sign Image
	local ImgLbl: ImageLabel = plot.PlayerSign.Main.SurfaceGui:FindFirstChild("ImageLabel")
	if ImgLbl then
		ImgLbl.ImageTransparency = 0
		local content, isReady = Players:GetUserThumbnailAsync(player.UserId, thumbType, thumbSize)
		ImgLbl.Image = (isReady and content) or ""
	end

	-- 🌱 Plot progression: lock beds the player hasn't bought yet
	Service.setupBeds(player, plot)

	-- 🌱 Load player plants
	local plotData = cachedModules.Cache.DataService.getData(player).PlotData
	task.spawn(function()
		for key: string, data: any in plotData do
			Service.createServerModel(player, key, data)
		end
	end)

	--warn(player, plotData)
end

function Service.playerRemoved(player:Player)
	local foundPlot = Service.getPlot(player)

	if foundPlot then
		Service.clearBeds(foundPlot)
		foundPlot:SetAttribute("Taken", nil)
		foundPlot:SetAttribute("USERID", nil)
		foundPlot:WaitForChild("PlayerSign").Main.SurfaceGui.TextLabel.Text = "Empty Garden"

		-- 🧹 FULL CLEANUP OF Owner_Tag
		local ownerTag = foundPlot:FindFirstChild("Owner_Tag")
		if ownerTag then
			for _, child in ownerTag:GetChildren() do
				child:Destroy()
			end
		end

		-- Clear image from PlayerSign
		local ImgLbl:ImageLabel = foundPlot.PlayerSign.Main.SurfaceGui.ImageLabel
		ImgLbl.ImageTransparency = 1
		ImgLbl.Image = ""

		-- Remove any plants by that player
		for _, plant: Model in workspace.World.Map.PlantedSeeds.Server:GetChildren() do
			if plant:GetAttribute("Owner") == player.UserId then
				plant:Destroy()
			end
		end
	end
end

function Service.init()
	local dataService = cachedModules.Cache.DataService
	local seedService = cachedModules.Cache.SeedShopService

	-- Clear stale plot ownership from any previous session saved into the place file
	for _, plot in workspace.Plots:GetChildren() do
		plot:SetAttribute("Taken", nil)
		plot:SetAttribute("USERID", nil)
		local sign = plot:FindFirstChild("PlayerSign")
		if sign then
			local label = sign:FindFirstChild("Main") and sign.Main:FindFirstChild("SurfaceGui") and sign.Main.SurfaceGui:FindFirstChild("TextLabel")
			if label then label.Text = "Empty Garden" end
			local img = sign:FindFirstChild("Main") and sign.Main:FindFirstChild("SurfaceGui") and sign.Main.SurfaceGui:FindFirstChild("ImageLabel")
			if img then img.ImageTransparency = 1 img.Image = "" end
		end
	end

	-- Growing seeds/making fruits/offline growing
	task.spawn(function()
		while task.wait(1) do
			for _, crop: Model in workspace.World.Map.PlantedSeeds.Server:GetChildren() do
				local ok, err = pcall(function()
					local plotNumber = crop:GetAttribute("Plot")
					local owner = crop:GetAttribute("Owner")

					local player = Players:GetPlayerByUserId(owner)
					if not player then
						return
					end

					local playerData = dataService.getData(player)
					local serverConfig = crop:FindFirstChild("ServerConfiguration")

					if not serverConfig then
						return
					end

					local growthPercentage = serverConfig.GrowthPercentage
					local lastGrowthInc = serverConfig.LastGrowthIncrement
					local datePlanted = serverConfig.DatePlanted

					local seedName = plantKeyUtil.getSeedName(crop.Name)
					local foundSeed = seedDataModule.getData(seedName)
					if not (plotNumber and owner and foundSeed) then
						return
					end

					local harvestInterval = foundSeed.HarvestInterval.Value

					if growthPercentage.Value >= 100 then
						-- Harvest
						if foundSeed.MultiHarvest.Value then
							for _, fruit in serverConfig.Fruits:GetChildren() do
								local lastHarvest = fruit.LastHarvest
								local canHarvest = fruit.CanHarvest

								if os.time() - lastHarvest.Value >= harvestInterval then
									if not canHarvest.Value then
										fruit.SizeScaling.Value = seedService.getRandomFruitSize(seedName, {})
										if fruit:FindFirstChild("Rarity") then
											fruit.Rarity.Value = rollHarvestRarityForCrop(plantKeyUtil.resolveCropName(crop.Name))
										end
										canHarvest.Value = true
									end
								else
									canHarvest.Value = false
								end
							end
						else
							local folder = serverConfig.Fruits:FindFirstChild("1")
							if not folder then
								return
							end
							if folder.CanHarvest.Value then
								return
							end
							if folder:FindFirstChild("Rarity") then
								folder.Rarity.Value = rollHarvestRarityForCrop(plantKeyUtil.resolveCropName(crop.Name))
							end
							folder.CanHarvest.Value = true
						end
					else
						local baseGrowthTime = math.max(1, foundSeed.GrowthTime.Value)
						local growthReduction = player:GetAttribute("PetGrowthReduction")
						if typeof(growthReduction) ~= "number" then
							growthReduction = 0
						end
						local growthTime = EconomyBalance.getEffectiveGrowthTime(baseGrowthTime, growthReduction)
						if os.time() - lastGrowthInc.Value >= 1 then
							lastGrowthInc.Value = os.time()
							growthPercentage.Value = math.clamp(
								((os.time() - datePlanted.Value) / growthTime) * 100,
								0,
								100
							)
						end
					end
				end)

				if not ok then
					warn("[PlotService] Growth tick failed for", crop.Name, err)
				end
			end
		end
	end)
end

return Service
