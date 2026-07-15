local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")

local player = players.LocalPlayer

local assets = replicatedStorage:WaitForChild("Assets")
local modules = replicatedStorage:WaitForChild("Modules")

local seedModule = require(modules.SeedData)
local plantKeyUtil = require(modules.PlantKeyUtil)
local EconomyBalance = require(modules.EconomyBalance)
local harvestRarityEffects = require(modules.HarvestRarityEffects)
local plantsfolder = assets.Plants

local world = workspace:WaitForChild("World", math.huge)
local plantedSeeds = world.Map.PlantedSeeds
local clientFolder = plantedSeeds.Client
local serverFolder = plantedSeeds.Server

local cachedMutations = {}
for _,v in modules.Mutations:GetChildren() do
	if v:IsA("ModuleScript") then
		cachedMutations[v.Name] = require(v)
	end
end

repeat task.wait() until player:GetAttribute("DataLoaded") == true

task.wait(1)

local function mutationsChanged(clientModel: Model, mutations: string, seed_data, serverFruitPart)
	for mutationName, effectModule in cachedMutations do
		if string.find(mutations, mutationName) then
			effectModule.applyEffect(clientModel,seed_data,serverFruitPart)
		else
			effectModule.removeEffect(clientModel,seed_data,serverFruitPart)
		end
	end
end

local function getHarvestRarityTarget(clientModel: Model, fruitNumber: string, multiHarvest: boolean): Model?
	if multiHarvest then
		return clientModel:FindFirstChild("fruit_" .. fruitNumber) :: Model?
	end
	return clientModel
end

local function syncHarvestRarity(serverModel: Model, clientModel: Model, fruitNumber: string, multiHarvest: boolean)
	local fruitFolder = serverModel.ServerConfiguration.Fruits:FindFirstChild(fruitNumber)
	if not fruitFolder then
		return
	end

	local rarityValue = fruitFolder:FindFirstChild("Rarity")
	local rarity = rarityValue and rarityValue.Value or "Common"
	local target = getHarvestRarityTarget(clientModel, fruitNumber, multiHarvest)
	if target then
		harvestRarityEffects.applyToPlantModel(target, rarity)
	end
end

local function clearHarvestRarity(clientModel: Model, fruitNumber: string, multiHarvest: boolean)
	local target = getHarvestRarityTarget(clientModel, fruitNumber, multiHarvest) or clientModel
	harvestRarityEffects.removeFromTarget(target)
end

local function waitForHarvestVisual(clientModel: Model, serverModel: Model)
	if clientModel:GetAttribute("FullyGrown") == true then
		return
	end

	local serverConfig = serverModel:FindFirstChild("ServerConfiguration")
	local deadline = os.clock() + 20
	while clientModel:GetAttribute("FullyGrown") ~= true do
		if serverConfig then
			local growth = serverConfig:FindFirstChild("GrowthPercentage")
			if growth and growth.Value >= 100 then
				clientModel:SetAttribute("FullyGrown", true)
				break
			end
		end
		if os.clock() >= deadline then
			break
		end
		task.wait(0.1)
	end
end

local function harvestableChanged(plantName: string, serverModel:Model, clientModel: Model, fruitNumber: string, harvestable: boolean, multiHarvest: boolean, sizeScaling: number, seed_data: Folder)
	task.spawn(function()
		
		if harvestable == true then
			waitForHarvestVisual(clientModel, serverModel)
			-- Enable prompt
			task.spawn(function()
				if multiHarvest then
					serverModel.FruitPrompts[fruitNumber].HarvestPrompt.Enabled = true
					
					if not clientModel:FindFirstChild("fruit_"..fruitNumber) then
						local clone = assets.Plants[plantName].ClientModel["fruit_"..fruitNumber]:Clone()
						clone:SetPrimaryPartCFrame(serverModel.FruitPrompts[fruitNumber].CFrame)
						clone:ScaleTo(sizeScaling)
						clone.Parent = clientModel

						-- Mutations.Changed is wired once per fruit in childAdded;
						-- reconnecting here leaked a connection every regrow cycle.
						mutationsChanged(clientModel,serverModel.ServerConfiguration.Fruits[fruitNumber].Mutations.Value,seed_data, serverModel.FruitPrompts[fruitNumber])

						syncHarvestRarity(serverModel, clientModel, fruitNumber, true)

						local objectValue = Instance.new("ObjectValue")
						objectValue.Name = "CorrespondingAdornee"
						objectValue.Value = clone
						objectValue.Parent = serverModel.FruitPrompts:WaitForChild(tostring(fruitNumber)).HarvestPrompt
					else
						syncHarvestRarity(serverModel, clientModel, fruitNumber, true)
					end
				else
					local harvestHost = serverModel:FindFirstChild("HarvestAnchor") or serverModel.PrimaryPart
					local harvestPrompt = harvestHost:WaitForChild("HarvestPrompt")
					local objectValue = Instance.new("ObjectValue")
					objectValue.Name = "CorrespondingAdornee"
					objectValue.Value = clientModel
					objectValue.Parent = harvestPrompt
					harvestPrompt.Enabled = true

					mutationsChanged(clientModel,serverModel.ServerConfiguration.Fruits[fruitNumber].Mutations.Value,seed_data, serverModel.PrimaryPart)
					syncHarvestRarity(serverModel, clientModel, fruitNumber, false)
				end
			end)

		else
			-- disable prompt
			task.spawn(function()
				if multiHarvest then
					serverModel.FruitPrompts[fruitNumber].HarvestPrompt.Enabled = false
					local foundObjectValue = serverModel.FruitPrompts[fruitNumber].HarvestPrompt:FindFirstChildWhichIsA("ObjectValue")
					if foundObjectValue then
						foundObjectValue:Destroy()
					end
					
					local foundFruitModel = clientModel:FindFirstChild("fruit_"..fruitNumber)
					if foundFruitModel then
						harvestRarityEffects.removeFromTarget(foundFruitModel)
						foundFruitModel:Destroy()
					end
				else
					clearHarvestRarity(clientModel, fruitNumber, false)
					local harvestHost = serverModel:FindFirstChild("HarvestAnchor") or serverModel.PrimaryPart
					local harvestPrompt = harvestHost:FindFirstChild("HarvestPrompt")
					if harvestPrompt then
						harvestPrompt.Enabled = false
					end
				end
			end)
		end
	end)
end

local function growthCelebration(clientModel: Model)
	-- Small one-shot sparkle burst when a plant finishes growing.
	local host = clientModel.PrimaryPart or clientModel:FindFirstChildWhichIsA("BasePart", true)
	if not host then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "GrownCelebration"

	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 255, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 250, 180)),
	})
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Lifetime = NumberRange.new(0.5, 0.9)
	burst.Speed = NumberRange.new(3, 6)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.LightEmission = 0.6
	burst.Parent = attachment

	attachment.Parent = host
	burst:Emit(14)
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

local function growthPercentageUpdated(clientModel: Model, newValue: number)
	task.spawn(function()
		for _,v in clientModel:GetDescendants() do
			local isTweened = v:GetAttribute("IsTweened")
			local originalSize = v:GetAttribute("OriginalSize")
			local appearPercentage = v:GetAttribute("AppearPercentage")
			local originalCFrame = v:GetAttribute("OriginalCFrame")
			local hideAtPercentage = v:GetAttribute("HideAtPercentage")

			task.spawn(function()
				if isTweened ~= nil and originalSize and appearPercentage ~= nil then
					-- Stage-transition crops: hide this stage once the next one should appear
					if hideAtPercentage and newValue >= hideAtPercentage then
						if isTweened == true then
							v.Transparency = 1
							v.Size = Vector3.new(0.01, 0.01, 0.01)
							v:SetAttribute("IsTweened", false)
						end
					elseif isTweened == false then
						if newValue >= appearPercentage then
							v:SetAttribute("IsTweened", true)
							tweenService:Create(v, TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
								{
									Size = originalSize,
									["CFrame"] = originalCFrame,
									Transparency = 0
								}
							):Play()
						end
					end
				end
			end)
			task.wait(0.05)
		end

		if newValue >= 100 then
			if clientModel:GetAttribute("FullyGrown") ~= true then
				clientModel:SetAttribute("FullyGrown", true)
				growthCelebration(clientModel)
			end
		end

	end)
end

local function formatGrowthTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	if minutes > 0 then
		return string.format("%d:%02d", minutes, secs)
	end
	return secs .. "s"
end

local function setupGrowthTimer(clientModel: Model, serverModel: Model, seed_data: Folder)
	local serverConfig = serverModel:FindFirstChild("ServerConfiguration")
	if not serverConfig or not seed_data then
		return
	end

	local growthPercentage = serverConfig:FindFirstChild("GrowthPercentage")
	local datePlanted = serverConfig:FindFirstChild("DatePlanted")
	local growthTimeValue = seed_data:FindFirstChild("GrowthTime")
	if not growthPercentage or not datePlanted or not growthTimeValue then
		return
	end

	if growthPercentage.Value >= 100 then
		return
	end

	local adornee = clientModel.PrimaryPart or clientModel:FindFirstChildWhichIsA("BasePart", true)
	if not adornee then
		return
	end

	local existingTimer = clientModel:FindFirstChild("GrowthTimer")
	if existingTimer then
		existingTimer:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GrowthTimer"
	-- Keep the timer subtle: small tag, only readable when standing nearby.
	billboard.Size = UDim2.fromOffset(72, 20)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 35
	billboard.Adornee = adornee
	billboard.Parent = clientModel

	local label = Instance.new("TextLabel")
	label.Name = "TimerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.35
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	local function refresh()
		if not billboard.Parent then
			return
		end

		if growthPercentage.Value >= 100 then
			billboard:Destroy()
			return
		end

		local totalTime = math.max(1, growthTimeValue.Value)
		local growthReduction = player:GetAttribute("PetGrowthReduction")
		if typeof(growthReduction) ~= "number" then
			growthReduction = 0
		end
		local effectiveTime = EconomyBalance.getEffectiveGrowthTime(totalTime, growthReduction)
		local remaining = effectiveTime * (1 - growthPercentage.Value / 100)
		remaining = math.max(0, remaining)
		if remaining <= 0 and growthPercentage.Value < 100 then
			label.Text = "🌱 Almost ready..."
		else
			label.Text = "🌱 " .. formatGrowthTime(remaining)
		end
	end

	refresh()
	growthPercentage.Changed:Connect(refresh)
	player:GetAttributeChangedSignal("PetGrowthReduction"):Connect(refresh)

	task.spawn(function()
		while billboard.Parent and growthPercentage.Value < 100 do
			task.wait(1)
			refresh()
		end
	end)
end

local function childAdded(child: Instance)
	local identifier = child.Name
	
	if not clientFolder:FindFirstChild(identifier) then
		local trueName = plantKeyUtil.resolveCropName(identifier)
	
		local foundModel = plantsfolder:FindFirstChild(trueName)
		
		if foundModel then
			local serverConfig = child:WaitForChild("ServerConfiguration", 10)
			if not serverConfig then
				warn("[CropReplicator] Missing ServerConfiguration for", identifier)
				return
			end

			local clientModel: Model = foundModel.ClientModel:Clone()
			clientModel.Name = identifier
			
			clientModel:ScaleTo(serverConfig.PlantSize.Value)
			
			clientModel:PivotTo(child:GetPivot())
			
			-- Destroying Fruits
			
			for _,v in clientModel:GetChildren() do
				if string.find(v.Name, "fruit_") then
					v:Destroy()
				end
			end

			-- Visibility of Parts
			
			clientModel:SetAttribute("FullyGrown", false)
			
			for _,v in clientModel:GetDescendants() do
				local s,e = pcall(function()
					local t = v.Transparency
				end)
				
				if s then
					v.Transparency = 1
					v:SetAttribute("OriginalSize",v.Size)
					v:SetAttribute("OriginalCFrame",v.CFrame)
					v:SetAttribute("IsTweened",false)
					v.Size = Vector3.new(0.01,0.01,0.01)
					v.CFrame = clientModel:GetPivot()
				end
			end
			
			clientModel.Parent = clientFolder
			
			-- Visuals
			if serverConfig then
				local growthPercentage = serverConfig:WaitForChild("GrowthPercentage",math.huge)
				growthPercentage.Changed:Connect(function()
					growthPercentageUpdated(clientModel,growthPercentage.Value)
				end)
				growthPercentageUpdated(clientModel,growthPercentage.Value)
				
				local seed_data = seedModule.getData(plantKeyUtil.getSeedName(identifier))

				setupGrowthTimer(clientModel, child, seed_data)
				
				-- Handle Scaling
				
				-- Harvest Visual
				if seed_data then
					local fruitsFolder = serverConfig.Fruits
					for _,v in fruitsFolder:GetChildren() do
						
						
						-- Handling Visiblity of Prompts
						
						local canHarvest = v:FindFirstChild("CanHarvest")
						if canHarvest ~= nil then
							local rarityValue = v:FindFirstChild("Rarity")
							if rarityValue then
								rarityValue.Changed:Connect(function()
									if canHarvest.Value then
										syncHarvestRarity(child, clientModel, v.Name, seed_data.MultiHarvest.Value)
									end
								end)
							end

							local mutationsValue = v:FindFirstChild("Mutations")
							if mutationsValue then
								local multiHarvest = seed_data.MultiHarvest.Value
								mutationsValue.Changed:Connect(function()
									local fruitPart = multiHarvest
										and child:FindFirstChild("FruitPrompts")
										and child.FruitPrompts:FindFirstChild(v.Name)
										or child.PrimaryPart
									if fruitPart then
										mutationsChanged(clientModel, mutationsValue.Value, seed_data, fruitPart)
									end
								end)
							end

							canHarvest.Changed:Connect(function()
								harvestableChanged(trueName,child,clientModel,v.Name,canHarvest.Value,seed_data.MultiHarvest.Value,v.SizeScaling.Value, seed_data)
							end)
							if canHarvest.Value then
								harvestableChanged(trueName,child,clientModel,v.Name,canHarvest.Value,seed_data.MultiHarvest.Value,v.SizeScaling.Value, seed_data)
							end
						end
						
						
					end
				end
				
			end
			
		else
			warn("[CropReplicator] No plant assets for", identifier, "resolved crop:", trueName)
		end
	end
	
end

local function childRemoved(child: Instance)
	local identifier = child.Name
	local foundClientModel = clientFolder:FindFirstChild(identifier)
	
	if foundClientModel then
		foundClientModel:Destroy()
	end
end

serverFolder.ChildAdded:Connect(function(child)
	task.spawn(function()
		childAdded(child)
	end)
end)
serverFolder.ChildRemoved:Connect(childRemoved)

for _, child: Instance in serverFolder:GetChildren() do
	childAdded(child)
end
