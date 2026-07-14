
local debris = game:GetService("Debris")
local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local assets = replicatedStorage:WaitForChild("Assets")
local plantEffect = assets.PlantEffect

return function(Data)
	local location:CFrame = Data.Location
	local clone = plantEffect:Clone()
	
	clone.PrimaryPart.Anchored = true
	clone:SetPrimaryPartCFrame(CFrame.new(location.Position)*CFrame.fromEulerAngles(0,0,math.rad(90)))
	clone.Parent = workspace.World.Visuals
	
	local scaleValue = Instance.new("NumberValue")
	scaleValue.Name = "Scale"
	scaleValue.Value = 0.1
	scaleValue.Parent = clone
	
	clone:ScaleTo(scaleValue.Value)
	
	tweenService:Create(scaleValue,TweenInfo.new(0.5,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),
		{
		Value = 1
		}
	):Play()
	
	task.delay(3,function()
		tweenService:Create(scaleValue,TweenInfo.new(0.5,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),
			{
				Value = 0.001
			}
		):Play()
	end)
	
	scaleValue.Changed:Connect(function()
		clone:ScaleTo(scaleValue.Value)
	end)
	
	debris:AddItem(clone,5)
	
end
