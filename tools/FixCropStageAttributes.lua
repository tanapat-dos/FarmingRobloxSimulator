--[[
	FIX CROP STAGE ATTRIBUTES
	Paste into Studio Command Bar and press Enter.

	Sets AppearPercentage + HideAtPercentage on every stage MeshPart
	in ReplicatedStorage/Assets/Plants/*/ClientModel so growth cycles
	animate correctly (seed -> stage1 -> ... -> harvest).
--]]

local plantsFolder = game.ReplicatedStorage.Assets.Plants

local STAGE_RULES = {
	{ pattern = "_Seed$",   appear = 0,   hideAt = 20  },
	{ pattern = "_Stage1$", appear = 20,  hideAt = 40  },
	{ pattern = "_Stage2$", appear = 40,  hideAt = 60  },
	{ pattern = "_Stage3$", appear = 60,  hideAt = 80  },
	{ pattern = "_Stage4$", appear = 80,  hideAt = 100 },
}

local function applyStageAttributes(part: BasePart)
	if part.Name == "PrimaryPart" then
		return
	end

	for _, rule in ipairs(STAGE_RULES) do
		if part.Name:match(rule.pattern) then
			part:SetAttribute("AppearPercentage", rule.appear)
			part:SetAttribute("HideAtPercentage", rule.hideAt)
			return
		end
	end

	-- Final harvest mesh (e.g. SM_Strawberry, SM_Wheat)
	if part.Name:match("^SM_") and not part.Name:match("_Seed") and not part.Name:match("_Stage") then
		part:SetAttribute("AppearPercentage", 100)
		part:SetAttribute("HideAtPercentage", nil)
	end
end

local fixed = 0
for _, plantFolder in plantsFolder:GetChildren() do
	local clientModel = plantFolder:FindFirstChild("ClientModel")
	if not clientModel then
		continue
	end

	for _, child in clientModel:GetChildren() do
		if child:IsA("BasePart") then
			applyStageAttributes(child)
			fixed += 1
		end
	end
end

print(string.format("[FixCropStageAttributes] Updated %d stage parts.", fixed))
