--[[
	GIVE TEST CASH   (for testing pets / eggs / anything cash-gated)

	Paste into the Studio Command Bar WHILE PLAY-TESTING, with the Command Bar context
	dropdown set to  >>> Server <<<  (not Client). Start a playtest with F5 first.

	SESSION-ONLY: sets Cash directly via DataService, no economy files touched, nothing
	persists after you Stop the playtest. Re-run any time to top back up.
]]

--=============================== CONFIGURE ===============================
local CASH_AMOUNT = 10000
--=========================================================================

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local servicesFolder = ServerScriptService:FindFirstChild("Services")
if not servicesFolder then
	error("[GiveTestCash] ServerScriptService.Services not found — are you running in the SERVER context of a playtest?")
end

local okData, DataService = pcall(require, servicesFolder:WaitForChild("DataService"))
local okMoney, MoneyService = pcall(require, servicesFolder:WaitForChild("MoneyService"))
if not okData or not okMoney then
	error("[GiveTestCash] Could not load DataService/MoneyService. Make sure the playtest is running and the Command Bar context is set to Server.")
end

local players = Players:GetPlayers()
if #players == 0 then
	warn("[GiveTestCash] No players in the game yet — start the playtest first, then re-run.")
else
	for _, player in players do
		local data = DataService.getData(player)
		if data then
			data.Cash = CASH_AMOUNT
			if MoneyService.updateCashCount then
				MoneyService.updateCashCount(player)
			end
			print(("[GiveTestCash] Set %s cash to $%d."):format(player.Name, CASH_AMOUNT))
		else
			warn(("[GiveTestCash] %s data not loaded yet — try again in a second."):format(player.Name))
		end
	end
end
