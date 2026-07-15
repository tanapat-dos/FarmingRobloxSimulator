--[[
	INSTALL PLOT ASSET — paste into Studio Command Bar (View → Command Bar).

	Loads Creator asset rbxassetid://113841779686169 and swaps garden plots.

	WHY THIS EXISTS
	  Plot visuals live in the place file (Workspace.Plots), not in Rojo src/.
	  PlotService expects fixed child names — the new asset must be wired once,
	  then cloned to every plot slot.

	REQUIRED ON EACH PLOT MODEL (names must match exactly)
	  Soil          — Folder/Model with 8 BasePart beds (planting surfaces)
	  TPPart        — Part players teleport to (Garden HUD button)
	  ReferencePoint — Part used for saved plant positions
	  PlayerSign    — Sign with Main → SurfaceGui → TextLabel + ImageLabel
	  Owner_Tag     — Part for the floating avatar billboard

	WORKFLOW
	  1. Set MODE = "preview" and run — inserts the asset at the first plot.
	  2. Wire/rename parts in Explorer so the preview has all REQUIRED children.
	     If the asset has soil meshes, group 8 plantable parts under a folder named Soil.
	  3. Move the finished preview to ServerStorage and name it PlotTemplate.
	  4. Set MODE = "swap" and run — replaces every child of Workspace.Plots with
	     a clone of PlotTemplate (keeps plot name, position, Taken/USERID attributes).
	  5. Play-test: plant a seed, harvest, buy a bed, teleport to garden.
	  6. Save Latest Farming Simulator.rbxl
]]

local InsertService = game:GetService("InsertService")

local CONFIG = {
	ASSET_ID = 113841779686169,
	MODE = "preview", -- "preview" | "swap"
	TEMPLATE_NAME = "PlotTemplate",
}

local REQUIRED = { "Soil", "TPPart", "ReferencePoint", "PlayerSign", "Owner_Tag" }

local plotsFolder = workspace:FindFirstChild("Plots")
if not plotsFolder then
	error("[InstallPlotAsset] Workspace.Plots not found.")
end

local function log(...)
	print("[InstallPlotAsset]", ...)
end

local function validatePlot(model: Model): (boolean, string?)
	for _, name in REQUIRED do
		if not model:FindFirstChild(name) then
			return false, ("Missing %s"):format(name)
		end
	end

	local soil = model:FindFirstChild("Soil")
	local bedCount = 0
	for _, child in soil:GetChildren() do
		if child:IsA("BasePart") then
			bedCount += 1
		end
	end
	if bedCount < 8 then
		return false, ("Soil needs 8 BasePart beds (found %d)"):format(bedCount)
	end

	local sign = model.PlayerSign
	local main = sign:FindFirstChild("Main")
	local surfaceGui = main and main:FindFirstChild("SurfaceGui")
	local textLabel = surfaceGui and surfaceGui:FindFirstChild("TextLabel")
	if not textLabel then
		return false, "PlayerSign.Main.SurfaceGui.TextLabel missing"
	end

	return true, nil
end

local function loadAssetModel(): Model
	local ok, container = pcall(function()
		return InsertService:LoadAsset(CONFIG.ASSET_ID)
	end)
	if not ok or not container then
		error(("[InstallPlotAsset] LoadAsset(%d) failed: %s"):format(
			CONFIG.ASSET_ID,
			tostring(container)
		))
	end

	local model = container:FindFirstChildWhichIsA("Model", true)
	if not model then
		container:Destroy()
		error("[InstallPlotAsset] Asset did not contain a Model.")
	end

	local clone = model:Clone()
	container:Destroy()
	return clone
end

local function getTemplate(): Model
	local template = game.ServerStorage:FindFirstChild(CONFIG.TEMPLATE_NAME)
	if not template or not template:IsA("Model") then
		error(("[InstallPlotAsset] Put a wired plot in ServerStorage.%s first."):format(CONFIG.TEMPLATE_NAME))
	end
	local ok, reason = validatePlot(template)
	if not ok then
		error(("[InstallPlotAsset] PlotTemplate invalid: %s"):format(reason))
	end
	return template
end

local function preservePlotState(oldPlot: Model, newPlot: Model)
	newPlot.Name = oldPlot.Name

	local pivot = oldPlot:GetPivot()
	newPlot:PivotTo(pivot)

	for _, attr in { "Taken", "USERID" } do
		local value = oldPlot:GetAttribute(attr)
		if value ~= nil then
			newPlot:SetAttribute(attr, value)
		else
			newPlot:SetAttribute(attr, nil)
		end
	end

	-- Keep sign text if this plot was assigned
	local oldSign = oldPlot:FindFirstChild("PlayerSign")
	local newSign = newPlot:FindFirstChild("PlayerSign")
	if oldSign and newSign then
		local oldGui = oldSign:FindFirstChild("Main")
			and oldSign.Main:FindFirstChild("SurfaceGui")
		local newGui = newSign:FindFirstChild("Main")
			and newSign.Main:FindFirstChild("SurfaceGui")
		if oldGui and newGui then
			local oldLabel = oldGui:FindFirstChild("TextLabel")
			local newLabel = newGui:FindFirstChild("TextLabel")
			if oldLabel and newLabel and oldLabel:IsA("TextLabel") and newLabel:IsA("TextLabel") then
				newLabel.Text = oldLabel.Text
			end
			local oldImg = oldGui:FindFirstChild("ImageLabel")
			local newImg = newGui:FindFirstChild("ImageLabel")
			if oldImg and newImg and oldImg:IsA("ImageLabel") and newImg:IsA("ImageLabel") then
				newImg.Image = oldImg.Image
				newImg.ImageTransparency = oldImg.ImageTransparency
			end
		end
	end
end

if CONFIG.MODE == "preview" then
	local anchorPlot = plotsFolder:FindFirstChild("1") or plotsFolder:GetChildren()[1]
	if not anchorPlot or not anchorPlot:IsA("Model") then
		error("[InstallPlotAsset] No plot model found to anchor preview.")
	end

	local existing = workspace:FindFirstChild("PlotAssetPreview")
	if existing then
		existing:Destroy()
	end

	local preview = loadAssetModel()
	preview.Name = "PlotAssetPreview"
	preview:PivotTo(anchorPlot:GetPivot())
	preview.Parent = workspace

	log(("Preview inserted: rbxassetid://%d"):format(CONFIG.ASSET_ID))
	log("Wire these children on PlotAssetPreview:", table.concat(REQUIRED, ", "))
	log("Soil must contain 8 BasePart beds. Then move it to ServerStorage.PlotTemplate and run MODE = swap.")
	log("Hierarchy snapshot:")
	for _, child in preview:GetChildren() do
		log(" ", child.Name, child.ClassName)
	end
elseif CONFIG.MODE == "swap" then
	local template = getTemplate()
	local swapped = 0

	for _, oldPlot in plotsFolder:GetChildren() do
		if not oldPlot:IsA("Model") then
			continue
		end

		local newPlot = template:Clone()
		preservePlotState(oldPlot, newPlot)
		newPlot.Parent = plotsFolder
		oldPlot:Destroy()
		swapped += 1
		log("Swapped plot", newPlot.Name)
	end

	log(("Done — replaced %d plot(s). Play-test planting, then save the place."):format(swapped))
else
	error(('[InstallPlotAsset] Unknown MODE "%s" (use preview or swap).'):format(CONFIG.MODE))
end
