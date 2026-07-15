local replicatedStorage = game:GetService("ReplicatedStorage")
local debris = game:GetService("Debris")
local Players = game:GetService("Players")

local cachedModules = require(script.Parent.Parent.Server.CachedModules)
local modules = replicatedStorage:WaitForChild("Modules")

local seedModule = require(modules.SeedData)
local fruitParser = require(modules.FruitNameParse)
local getFruitValue = require(modules.GetFruitValue)

local remotes = replicatedStorage:WaitForChild("RemoteEvents")

local Service = {}

local MAX_FRIENDS = 4 -- Max friends that give boosts 
local BOOST_PER_FRIEND = 0.10 -- 10% per friend

local function round(n, decimals)
	decimals = decimals or 0
	local multiplier = 10^decimals
	return math.floor(n * multiplier + 0.5) / multiplier
end

local function getFruitInventoryString(tool: Tool, inventorySave: any): string?
	local fruitId = tool:GetAttribute("fruitID")
	if fruitId and inventorySave[fruitId] then
		return inventorySave[fruitId]
	end
	return tool:GetAttribute("DisplayName")
end

local function findFruitInSave(tool: Tool, inventorySave: any): (any?, string?)
	local fruitId = tool:GetAttribute("fruitID")
	if typeof(fruitId) == "string" and inventorySave[fruitId] then
		return inventorySave[fruitId], fruitId
	end

	if tool:GetAttribute("isSeed") == true then
		return nil, nil
	end

	local displayName = tool:GetAttribute("DisplayName")
	if typeof(displayName) == "string" and displayName ~= "" then
		for key, value in inventorySave do
			if value == displayName then
				return value, key
			end
		end
	end

	return nil, nil
end

local function isSellableFruitTool(tool: Tool): boolean
	if not tool:IsA("Tool") or tool:GetAttribute("Favorited") then
		return false
	end
	if tool:GetAttribute("isSeed") == true then
		return false
	end
	if tool:GetAttribute("isFruit") == true then
		return true
	end
	return typeof(tool:GetAttribute("DisplayName")) == "string"
		and tool:GetAttribute("DisplayName") ~= ""
end

local function updateFriendBoost(player: Player)
	local friendsInGame = 0
	local success, friends = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)

	if success then
		for _, friend in friends:GetCurrentPage() do
			if friendsInGame >= MAX_FRIENDS then
				break
			end
			local friendPlayer = Players:GetPlayerByUserId(friend.Id)
			if friendPlayer and friendPlayer ~= player then
				friendsInGame += 1
			end
		end
	end

	local boostMultiplier = 1 + (friendsInGame * BOOST_PER_FRIEND)
	local boostPercentage = math.floor((boostMultiplier - 1) * 100)
	player:SetAttribute("FriendBoost", boostMultiplier)

	remotes.UpdateFriendBoost:FireClient(player, boostPercentage)
end

function Service.updateCashCount(player: Player)
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(player)

	if profileData then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and leaderstats:FindFirstChild("Cash") then
			leaderstats.Cash.Value = profileData.Cash
		end
	end
end

function Service.dataLoaded(player: Player)
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = profileData and profileData.Rebirths or 0
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
	player:SetAttribute("FriendBoost", 1)
	player:SetAttribute("PetBoost", 1)
	player:SetAttribute("PetGrowthReduction", 0)
	player:SetAttribute("Rebirths", profileData and profileData.Rebirths or 0)
	Service.updateCashCount(player)
	updateFriendBoost(player)
end

function Service.getCashMultiplier(target: Player): number
	local EconomyBalance = require(modules.EconomyBalance)
	local rebirths = target:GetAttribute("Rebirths")
	if typeof(rebirths) ~= "number" then
		rebirths = 0
	end
	local rebirthMultiplier = 1 + rebirths * EconomyBalance.REBIRTH.boostPerRebirth
	return (target:GetAttribute("FriendBoost") or 1)
		* (target:GetAttribute("PetBoost") or 1)
		* rebirthMultiplier
end

function Service.giveMoney(target: Player, amount: number)
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData and typeof(amount) == "number" and amount > 0 then
		-- Keep cash integral: leaderstats is an IntValue and fractional profile
		-- cash accumulates float noise across sells.
		local boostedAmount = math.floor(amount * Service.getCashMultiplier(target) + 0.5)
		profileData.Cash += boostedAmount
		Service.updateCashCount(target)
		return boostedAmount
	end
	return 0
end

function Service.removeCash(target: Player, amount: number): boolean
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if typeof(amount) ~= "number" or amount <= 0 then
		return false
	end
	amount = math.floor(amount)

	if profileData and profileData.Cash >= amount then
		profileData.Cash -= amount
		Service.updateCashCount(target)
		return true
	end
	return false
end

function Service.hasEnoughCash(target: Player, amount: number): boolean
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if typeof(amount) ~= "number" then
		return false
	end

	if profileData and profileData.Cash >= amount then
		return true
	end
	return false
end

function Service.SellLisenter(player: Player, action: string)
	local result = { success = false, msg = "Unknown error." }

	local dataService = cachedModules.Cache.DataService
	local inventoryService = cachedModules.Cache.InventoryService

	if not player:GetAttribute("DataLoaded") then return end

	local character = player.Character
	if character then
		local playerData = dataService.getData(player)
		if not playerData then return end

		local inventorySave = playerData.Inventory

		if player:FindFirstChild("sellDebounce") then
			return
		end

		local db = Instance.new("Folder")
		db.Name = "sellDebounce"
		db.Parent = player
		debris:AddItem(db, 1)

		if action == "itemSell" then
			local itemEquipped = character:FindFirstChildWhichIsA("Tool")
			if itemEquipped and isSellableFruitTool(itemEquipped) then
				local foundInSave, fruitKey = findFruitInSave(itemEquipped, inventorySave)

				if foundInSave and itemEquipped.Parent == character then
					local displayString = getFruitInventoryString(itemEquipped, inventorySave) or foundInSave
					local rarity, mutations, weight, fruitNameOnly = fruitParser(displayString)
					if weight and fruitNameOnly then
						local value = getFruitValue({
							Mutations = mutations,
							Weight = weight,
							FruitName = fruitNameOnly,
							Rarity = rarity,
						})

						local boostedValue = Service.giveMoney(player, value)
						inventoryService.removeItem(player, fruitKey, 1)

						boostedValue = round(boostedValue, 2)

						result.success = true
						result.msg = `Sold <font color="rgb(0,255,0)">{displayString}</font> for <font color="rgb(0,255,0)">${boostedValue}</font>`
					else
						result.msg = "Could not read this fruit's data."
					end
				else
					result.msg = "You must have fruits in your inventory."
				end
			else
				result.msg = "You must be holding a fruit to sell."
			end
		end

		if action == "howMuch" then
			local itemEquipped = character:FindFirstChildWhichIsA("Tool")
			if itemEquipped and isSellableFruitTool(itemEquipped) then
				local foundInSave = findFruitInSave(itemEquipped, inventorySave)

				if foundInSave and itemEquipped.Parent == character then
					local displayString = getFruitInventoryString(itemEquipped, inventorySave) or foundInSave
					local rarity, mutations, weight, fruitNameOnly = fruitParser(displayString)
					if weight and fruitNameOnly then
						local value = getFruitValue({
							Mutations = mutations,
							Weight = weight,
							FruitName = fruitNameOnly,
							Rarity = rarity,
						})
						local multiplier = Service.getCashMultiplier(player)
						local displayValue = round(value * multiplier, 2)
						result.success = true
						result.msg = `This <font color="rgb(0,255,0)">{displayString}</font> is worth <font color="rgb(0,255,0)">${displayValue}</font>`
					else
						result.msg = "Could not read this fruit's data."
					end
				else
					result.msg = "You must have a fruit."
				end
			else
				result.msg = "You must be holding a fruit."
			end
		end

		if action == "bulkSell" then
			local totalValue = 0
			local soldCount = 0
			local itemsToSell = {}

			local tool = character:FindFirstChildWhichIsA("Tool")
			if tool and isSellableFruitTool(tool) then
				table.insert(itemsToSell, tool)
			end

			for _, v: Tool in player.Backpack:GetChildren() do
				if isSellableFruitTool(v) then
					table.insert(itemsToSell, v)
				end
			end

			if #itemsToSell <= 0 then
				result.msg = "You have no fruits to sell."
			else
				for _, item: Tool in itemsToSell do
					local foundInSave, fruitKey = findFruitInSave(item, inventorySave)
					if foundInSave and fruitKey then
						local rarity, mutations, weight, fruitNameOnly = fruitParser(foundInSave)
						if weight and fruitNameOnly then
							local value = getFruitValue({
								Mutations = mutations,
								Weight = weight,
								FruitName = fruitNameOnly,
								Rarity = rarity,
							})
							local boostedValue = Service.giveMoney(player, value)
							totalValue += boostedValue
							soldCount += 1
							inventoryService.removeItem(player, fruitKey, 1)
						end
					end
				end

				totalValue = round(totalValue, 2)

				if soldCount > 0 then
					result.success = true
					result.msg = `Sold <font color="rgb(255,0,0)">{soldCount}</font> fruits for <font color="rgb(0,255,0)">${totalValue}</font>`
				else
					result.msg = "Nothing could be sold."
				end
			end
		end
	end

	return result
end

function Service.init()
	remotes.Sell.OnServerInvoke = Service.SellLisenter

	Players.PlayerAdded:Connect(function(player)
		updateFriendBoost(player)
		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer ~= player then
				updateFriendBoost(otherPlayer)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer ~= player then
				updateFriendBoost(otherPlayer)
			end
		end
	end)

	for _, player in Players:GetPlayers() do
		updateFriendBoost(player)
	end
end

return Service
