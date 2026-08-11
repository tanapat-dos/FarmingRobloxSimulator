--!nocheck
--[[
	RemoveBackdoorScripts.lua
	Run in the Roblox Studio COMMAND BAR, in EDIT MODE (not during a playtest).

	WHAT THIS IS FOR
	----------------
	A Toolbox model brought a backdoor/scam script into this place. It lives at:

	    Workspace.WallTorch.Torch.End.Dependencies.Dependencies.CoreValidation   (x11 copies)

	On server start it:
	  1. Checks StarterPlayer.StarterCharacterScripts for its own tag. If found, it stays
	     silent (it is already installed and does not need to nag you again).
	  2. If NOT found, it clones a fake "Model Parse Error" ScreenGui into every player's
	     PlayerGui, destroys their character, and kicks them with "Error 500" after 1s.

	The dialog pressures you into pasting a Command Bar line that reparents an unknown
	Folder from rbxassetid://122845407827531 into StarterCharacterScripts — i.e. it makes
	YOU install the payload by hand. Do not run that line. It is not a Roblox error.

	This script finds and deletes the malware by SOURCE SIGNATURE (not by name), so
	renamed or relocated copies are caught too.

	HOW TO USE
	----------
	1. Edit mode. Set DRY_RUN = true (default) and paste the whole file into the Command Bar.
	2. Read the printed report. Confirm every listed script is junk you want gone.
	3. Set DRY_RUN = false, paste again.
	4. Ctrl+S, then Play. The fake dialog and the kick should be gone.

	PURGE_DEAD_TOOLBOX_SCRIPTS
	--------------------------
	Separate, optional. These are not malicious, just broken Toolbox loaders that spam the
	output with "lacking capability LoadUnownedAsset" / HTTP 403 because they try to
	require() assets this place does not own (qTexture, TextureConfiguration, Package,
	CoreSkyboxSystem, LightConfig, qPerfectionWeld, "READ MEEEE" notes). They do nothing
	useful here. Turn this on to clear the log noise. Off by default so the two concerns
	stay independent.
--]]

------------------------------------------------------------------ CONFIGURE
local DRY_RUN = true
local PURGE_DEAD_TOOLBOX_SCRIPTS = false
--------------------------------------------------------------- END CONFIGURE

local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")

-- Distinctive fragments of the backdoor. A script needs either a HARD hit, or 2+ SOFT hits.
local HARD_SIGNATURES = {
	"122845407827531", -- the payload asset id
	"__CoreCheckValidationRan", -- its single-run lock attribute
}

local SOFT_SIGNATURES = {
	"StarterCharacterScripts",
	"FindFirstChildWhichIsA",
	"Error 500",
	"GetObjects",
	"Model Parse Error",
	"Roblox Corporation", -- fake copyright header
}

-- Broken-but-harmless Toolbox loaders (matched on exact instance name).
local DEAD_TOOLBOX_NAMES = {
	["Package"] = true,
	["TextureConfiguration"] = true,
	["PoseTexture"] = true,
	["qTexture"] = true,
	["qPerfectionWeld"] = true,
	["CoreSkyboxSystem"] = true,
	["LightConfig"] = true,
	["READ MEEEE"] = true,
}

local SCRIPT_CLASSES = { Script = true, LocalScript = true, ModuleScript = true }

-- Never scan our own source tree; these are the game's real scripts.
local PROTECTED_ROOTS = {
	game:GetService("ServerScriptService"),
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerStorage"),
	StarterPlayer,
	game:GetService("StarterGui"),
}

local function isProtected(inst)
	for _, root in ipairs(PROTECTED_ROOTS) do
		if inst == root or inst:IsDescendantOf(root) then
			return true
		end
	end
	return false
end

local function countOccurrences(haystack, needle)
	local n, pos = 0, 1
	while true do
		local s = string.find(haystack, needle, pos, true)
		if not s then
			break
		end
		n += 1
		pos = s + 1
	end
	return n
end

local function classify(scriptInst)
	local ok, src = pcall(function()
		return scriptInst.Source
	end)
	if not ok or type(src) ~= "string" then
		return nil, "source unreadable"
	end

	local hard = {}
	for _, sig in ipairs(HARD_SIGNATURES) do
		if countOccurrences(src, sig) > 0 then
			table.insert(hard, sig)
		end
	end

	local soft = {}
	for _, sig in ipairs(SOFT_SIGNATURES) do
		if countOccurrences(src, sig) > 0 then
			table.insert(soft, sig)
		end
	end

	if #hard > 0 then
		return "malware", ("HARD: %s"):format(table.concat(hard, ", "))
	end
	if #soft >= 2 then
		return "malware", ("SOFT x%d: %s"):format(#soft, table.concat(soft, ", "))
	end
	return nil, nil
end

local malware, deadToolbox, unreadable = {}, {}, {}

for _, inst in ipairs(game:GetDescendants()) do
	if SCRIPT_CLASSES[inst.ClassName] and not isProtected(inst) then
		local verdict, why = classify(inst)
		if verdict == "malware" then
			table.insert(malware, { inst = inst, why = why })
		elseif why == "source unreadable" then
			table.insert(unreadable, inst)
		elseif PURGE_DEAD_TOOLBOX_SCRIPTS and DEAD_TOOLBOX_NAMES[inst.Name] then
			table.insert(deadToolbox, inst)
		end
	end
end

print("=== Backdoor scan ===")
print(("  malware matches: %d"):format(#malware))
for _, entry in ipairs(malware) do
	print(("    %-16s %s   [%s]"):format(entry.inst.ClassName, entry.inst:GetFullName(), entry.why))
end

if PURGE_DEAD_TOOLBOX_SCRIPTS then
	print(("  dead Toolbox loaders: %d"):format(#deadToolbox))
	for _, inst in ipairs(deadToolbox) do
		print(("    %-16s %s"):format(inst.ClassName, inst:GetFullName()))
	end
end

if #unreadable > 0 then
	print(("  NOTE: %d script(s) had unreadable Source and were skipped."):format(#unreadable))
end

-- Anything already sitting in StarterCharacterScripts is the installed payload.
local scsChildren = StarterPlayer:FindFirstChild("StarterCharacterScripts")
	and StarterPlayer.StarterCharacterScripts:GetChildren()
	or {}
print(("  StarterCharacterScripts contents: %d"):format(#scsChildren))
for _, child in ipairs(scsChildren) do
	print(("    %-16s %s   <-- REVIEW THIS, the payload installs here"):format(child.ClassName, child.Name))
end

if DRY_RUN then
	print("[RemoveBackdoor] DRY_RUN - nothing changed. Set DRY_RUN = false to apply.")
	return
end

local removed = 0
for _, entry in ipairs(malware) do
	local path = entry.inst:GetFullName()
	local ok, err = pcall(function()
		entry.inst:Destroy()
	end)
	if ok then
		removed += 1
	else
		warn(("[RemoveBackdoor] failed to delete %s: %s"):format(path, tostring(err)))
	end
end

local removedDead = 0
for _, inst in ipairs(deadToolbox) do
	if pcall(function()
		inst:Destroy()
	end) then
		removedDead += 1
	end
end

-- Clear the single-run lock so a leftover copy cannot hide behind it.
pcall(function()
	workspace:SetAttribute("__CoreCheckValidationRan", nil)
end)

print(("[RemoveBackdoor] Deleted %d malware script(s), %d dead Toolbox script(s)."):format(removed, removedDead))
print("  Lighting.Blur was intentionally NOT touched - it is the game's own shop-UI blur.")

task.delay(1, function()
	local left = 0
	for _, inst in ipairs(game:GetDescendants()) do
		if SCRIPT_CLASSES[inst.ClassName] and not isProtected(inst) then
			local verdict = classify(inst)
			if verdict == "malware" then
				left += 1
				warn(("  STILL PRESENT: %s"):format(inst:GetFullName()))
			end
		end
	end
	print("[SelfCheck +1s]")
	print(("    malware scripts remaining: %d"):format(left))
	print(("    StarterCharacterScripts children: %d (must be 0)"):format(
		#(StarterPlayer:FindFirstChild("StarterCharacterScripts") and StarterPlayer.StarterCharacterScripts:GetChildren() or {})
	))
	print(("    Lighting.Blur present: %s (expected true)"):format(tostring(Lighting:FindFirstChild("Blur") ~= nil)))
	print("  Now Ctrl+S, then Play. No 'Model Parse Error' dialog and no Error 500 kick.")
end)
