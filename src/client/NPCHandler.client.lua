local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local MAX_DISTANCE = 50
local MAX_ANGLE = math.rad(60)
local SMOOTHING = 0.1


------------------Head Tracking--------------------------------

local function getTrackableNPCs()
	local folder = workspace:WaitForChild("Shops", 10)
	if not folder then
		warn("❌ Shops folder not found")
		return {}
	end

	local characters = folder:WaitForChild("Characters", 10)
	if not characters then
		warn("❌ Characters folder not found in Shops")
		return {}
	end

	local npcs = {}
	for _, npc in pairs(characters:GetChildren()) do
		local hrp = npc:WaitForChild("HumanoidRootPart")
		local head = npc:WaitForChild("Head")
		local neck = head and head:WaitForChild("Neck")

		if hrp and head and neck then
			table.insert(npcs, {
				Model = npc,
				HRP = hrp,
				Head = head,
				Neck = neck,
				OriginalC0 = neck.C0
			})
		else
			warn("⚠️ Missing parts in NPC:", npc.Name)
		end
	end

	return npcs
end

local npcs = getTrackableNPCs()

RunService.RenderStepped:Connect(function()
	local playerChar = LocalPlayer.Character
	if not playerChar then return end

	local playerHrp = playerChar:WaitForChild("HumanoidRootPart")
	if not playerHrp then return end

	for _, npc in pairs(npcs) do
		local hrp = npc.HRP
		local head = npc.Head
		local neck = npc.Neck
		local originalC0 = npc.OriginalC0

		local dist = (playerHrp.Position - hrp.Position).Magnitude
		if dist < MAX_DISTANCE then
			local dir = (playerHrp.Position - hrp.Position).Unit
			local vecA = Vector2.new(dir.X, dir.Z)
			local vecB = Vector2.new(hrp.CFrame.LookVector.X, hrp.CFrame.LookVector.Z)
			local dot = vecA:Dot(vecB)
			local cross = vecA.X * vecB.Y - vecA.Y * vecB.X
			local yAngle = math.atan2(cross, dot)
			yAngle = math.clamp(yAngle, -MAX_ANGLE, MAX_ANGLE)

			local verticalOffset = playerHrp.Position.Y - head.Position.Y
			local angleDistance = (playerHrp.Position - head.Position).Magnitude
			local xAngle = math.atan2(verticalOffset, angleDistance)

			local targetC0 = originalC0 * CFrame.Angles(xAngle, yAngle, 0)
			neck.C0 = neck.C0:Lerp(targetC0, SMOOTHING)
		else
			neck.C0 = neck.C0:Lerp(originalC0, SMOOTHING)
		end
	end
end)

-----------------Proximity Prompt--------------------------------
