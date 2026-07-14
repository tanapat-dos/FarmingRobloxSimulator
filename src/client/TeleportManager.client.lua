local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Buttons = PlayerGui:WaitForChild("Main"):WaitForChild("Buttons"):GetChildren()

local function teleportTo(position)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
end

for _, button in ipairs(Buttons) do
	button.MouseButton1Click:Connect(function()
		if button.Name == "GardenTeleport" then
			for _, plot in ipairs(workspace.Plots:GetChildren()) do
				if plot:GetAttribute("USERID") == player.UserId then
					teleportTo(plot.TPPart.Position)
					return
				end
			end

		elseif button.Name == "SeedsTeleport" then
			teleportTo(workspace.Shops.SeedShop.TPPart.Position)

		elseif button.Name == "SellTeleport" then
			teleportTo(workspace.Shops.SellStuff.TPPart.Position)

		elseif button.Name == "PetsTeleport" then
			teleportTo(workspace.Shops.PetShop.TPPart.Position)
		end
	end)
end
