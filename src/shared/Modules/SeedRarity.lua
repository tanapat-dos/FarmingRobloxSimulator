local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GradientFolder = ReplicatedStorage:WaitForChild("RarityGradients")

local SeedRarity = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(86, 144, 78),
	Rare = Color3.fromRGB(0, 164, 235),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(242, 250, 10),
	Mythical = Color3.fromRGB(206, 26, 237),
	Divine = Color3.fromRGB(233, 135, 0),
	Prismatic = GradientFolder:WaitForChild("Prismatic")
}

return SeedRarity
