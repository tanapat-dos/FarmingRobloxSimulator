local debris = game:GetService("Debris")
local replicatedStorage = game:GetService("ReplicatedStorage")

local modules = replicatedStorage.Modules
local remotes = replicatedStorage.RemoteEvents

local seedModule = require(modules.SeedData)
local fruitNameParser = require(modules.FruitNameParse)
local getFruitValue = require(modules.GetFruitValue)
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}
local random = Random.new()

function Service.getRandomGrowthMutation(seedData: Folder, number)

	-- Odds must stay rare: GetFruitValue pays x50 (Rainbow) / x20 (Golden).
	-- Rainbow: 1%
	if random:NextInteger(1, 100) <= 1 then
		return "Rainbow"
	end

	-- Golden: 5%
	if random:NextInteger(1, 100) <= 5 then
		return "Golden"
	end

	return ""
end

function Service.giveMutation(serverModel: Model, fruitNumber: number, mutationName: string)
	local serverConfiguration = serverModel:FindFirstChild("ServerConfiguration")
	if serverConfiguration then
		local fruitsFolder: Folder = serverConfiguration:FindFirstChild("Fruits")
		if fruitsFolder then
			local foundFruit = fruitsFolder:FindFirstChild(tostring(fruitNumber))
			if foundFruit then
				if string.find(foundFruit.Mutations.Value, mutationName) then
					return -- Already Have the Mutation
				end
				if foundFruit.Mutations.Value ~= "" then
					foundFruit.Mutations.Value = foundFruit.Mutations.Value .. "," .. mutationName
				else
					foundFruit.Mutations.Value = mutationName
				end
			end
		end
	end
end



return Service
