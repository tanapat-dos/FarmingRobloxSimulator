--[[
	Studio Play Test — paste in Command Bar while playing.
	Sets your cash to EconomyBalance.STARTING_CASH and refreshes leaderstats.
]]
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local player = Players:GetPlayers()[1]
if not player then
	error("[GrantTestCash] No player in game — start Play Test first")
end

local services = ServerScriptService:FindFirstChild("Services")
local dataModule = services and services:FindFirstChild("DataService")
if not dataModule then
	error("[GrantTestCash] DataService not found — is the server running?")
end

local DataService = require(dataModule)
local data = DataService.getData(player)
if not data then
	error("[GrantTestCash] Data not loaded yet for " .. player.Name)
end

local EconomyBalance = require(game.ReplicatedStorage.Modules.EconomyBalance)
data.Cash = EconomyBalance.STARTING_CASH

local MoneyService = require(services.MoneyService)
MoneyService.updateCashCount(player)

print("[GrantTestCash]", player.Name, "cash set to", data.Cash)
