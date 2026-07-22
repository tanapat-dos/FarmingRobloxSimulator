--[[ Paste in Command Bar (Edit mode, Play stopped).
	Checks whether EconomyBalance exposes Mango Seed (cached vs fresh require).
--]]
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if RunService:IsRunning() then
	warn("Stop Play first.")
	return
end
local mod = RS.Modules.EconomyBalance
local function hasMango(eb)
	return eb.CROPS and eb.CROPS["Mango Seed"] ~= nil
end
local cached = require(mod)
print("[Verify] Cached require Mango:", hasMango(cached))
local clone = mod:Clone()
clone.Name = "EconomyBalance_VerifyFresh"
clone.Parent = mod.Parent
local fresh = require(clone)
clone:Destroy()
print("[Verify] Fresh clone require Mango:", hasMango(fresh))
if not hasMango(fresh) then
	warn("[Verify] EconomyBalance source missing Mango Seed — sync Rojo or paste src/shared/Modules/EconomyBalance.lua")
else
	print("[Verify] OK — re-run IntegrateMango.lua (full paste from tools/)")
end
