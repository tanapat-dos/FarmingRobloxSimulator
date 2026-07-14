local players = game:GetService("Players")
local RunService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local profileTemplate = require(script.Template)
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local IS_STUDIO = RunService:IsStudio()

-- Only load ProfileStore when running on a real server (not Studio local test)
local PlayerStore
if not IS_STUDIO then
	local profileStore = require(script.ProfileStore)
	PlayerStore = profileStore.New("PlayerStore_069", profileTemplate)
end

local Service = {
	Profiles = {}
}

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

function Service.getData(target: Player)
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		warn("❌ getData was called with an invalid argument:", target)
	end
	if not target:GetAttribute("DataLoaded") then return nil end
	local profile = Service.Profiles[target]
	if profile then
		return profile.Data
	end
	return nil
end

function Service.init()
	local moneyService = cachedModules.Cache.MoneyService
	local plotService = cachedModules.Cache.PlotService
	local inventoryService = cachedModules.Cache.InventoryService

	local function onCharacterAdded(character: Model)
		inventoryService.characterAdded(character)
	end

	local function dataLoaded(player: Player)
		local profile = Service.Profiles[player]
		if profile then
			moneyService.dataLoaded(player)
			plotService.dataLoaded(player)

			if player.Character then
				onCharacterAdded(player.Character)
			end
			player.CharacterAdded:Connect(onCharacterAdded)
		end
	end

	local function playerAdded(player: Player)
		if IS_STUDIO then
			-- Studio mock: give every player a fresh in-memory profile instantly
			local mockData = deepCopy(profileTemplate)
			Service.Profiles[player] = { Data = mockData }
			print(`[Studio] Mock profile loaded for {player.DisplayName}`)
			player:SetAttribute("DataLoaded", true)
			dataLoaded(player)
			return
		end

		-- Live server: use ProfileStore
		local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
			Cancel = function()
				return player.Parent ~= players
			end,
		})

		if profile ~= nil then
			profile:AddUserId(player.UserId)
			profile:Reconcile()

			profile.OnSessionEnd:Connect(function()
				Service.Profiles[player] = nil
				player:Kick("Profile session end - Please rejoin")
			end)

			if player.Parent == players then
				Service.Profiles[player] = profile
				print(`Profile loaded for {player.DisplayName}!`)
				player:SetAttribute("DataLoaded", true)
				dataLoaded(player)
			else
				profile:EndSession()
			end
		else
			player:Kick("Profile load fail - Please rejoin")
		end
	end

	local function playerRemoved(player: Player)
		local profile = Service.Profiles[player]
		if profile ~= nil then
			plotService.playerRemoved(player)
			if not IS_STUDIO then
				profile:EndSession()
			end
			Service.Profiles[player] = nil
		end
	end

	players.PlayerAdded:Connect(playerAdded)
	players.PlayerRemoving:Connect(playerRemoved)

	for _, player in players:GetPlayers() do
		playerAdded(player)
	end
end

return Service
