--[[
	MAP POLISH — paste into Studio Command Bar (View → Command Bar) and press Enter.

	Idempotent: everything this script creates lives in workspace.MapPolish
	(or is tagged with a "MapPolish" attribute); re-running deletes and
	rebuilds, so tune the CONFIG table and run again freely.

	What it does:
	  1. Lighting pass — warm sun, soft shadows, atmosphere, bloom, color grade.
	  2. Soil pass — consistent tilled-soil look + wooden trim around each plot.
	  3. Plot corners — lantern posts with warm light at each plot's corners.
	  4. Shop lamps — a lamp post beside each shop teleport pad.
	  5. Report — prints what it found, changed, and skipped.

	Save the place after running.
]]

local Lighting = game:GetService("Lighting")

local CONFIG = {
	-- Lighting
	clockTime = 13.5,
	brightness = 2.2,
	shadowSoftness = 0.35,
	ambient = Color3.fromRGB(96, 100, 104),
	outdoorAmbient = Color3.fromRGB(128, 132, 138),
	-- Soil
	soilMaterial = Enum.Material.Ground,
	soilColor = Color3.fromRGB(92, 68, 52),
	trimMaterial = Enum.Material.WoodPlanks,
	trimColor = Color3.fromRGB(124, 92, 60),
	trimHeight = 0.9,
	trimThickness = 0.55,
	-- Lantern posts
	postMaterial = Enum.Material.Wood,
	postColor = Color3.fromRGB(105, 78, 52),
	lampColor = Color3.fromRGB(255, 214, 150),
	lampBrightness = 0.9,
	lampRange = 14,
}

local report = {}
local function log(line)
	table.insert(report, line)
end

-- ------------------------------------------------------------ scaffolding
local polishFolder = workspace:FindFirstChild("MapPolish")
if polishFolder then
	polishFolder:Destroy()
	log("Removed previous MapPolish folder (rebuilding).")
end
polishFolder = Instance.new("Folder")
polishFolder.Name = "MapPolish"
polishFolder.Parent = workspace

local function newPart(name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = polishFolder
	return part
end

-- --------------------------------------------------------------- lighting
do
	Lighting.Technology = Enum.Technology.ShadowMap
	Lighting.ClockTime = CONFIG.clockTime
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = CONFIG.brightness
	Lighting.ShadowSoftness = CONFIG.shadowSoftness
	Lighting.Ambient = CONFIG.ambient
	Lighting.OutdoorAmbient = CONFIG.outdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5

	local function ensureEffect(className: string, name: string, props: { [string]: any })
		local effect = Lighting:FindFirstChild(name)
		if not effect then
			effect = Instance.new(className)
			effect.Name = name
			effect.Parent = Lighting
		end
		for key, value in props do
			effect[key] = value
		end
		return effect
	end

	ensureEffect("Atmosphere", "MapAtmosphere", {
		Density = 0.3,
		Offset = 0.25,
		Color = Color3.fromRGB(199, 199, 199),
		Decay = Color3.fromRGB(106, 112, 125),
		Glare = 0.2,
		Haze = 1.2,
	})
	ensureEffect("BloomEffect", "MapBloom", {
		Intensity = 0.4,
		Size = 24,
		Threshold = 1.2,
	})
	ensureEffect("ColorCorrectionEffect", "MapColorGrade", {
		Brightness = 0.015,
		Contrast = 0.06,
		Saturation = 0.1,
		TintColor = Color3.fromRGB(255, 251, 244),
	})
	ensureEffect("SunRaysEffect", "MapSunRays", {
		Intensity = 0.08,
		Spread = 0.6,
	})

	log("Lighting: ShadowMap, warm afternoon sun, atmosphere/bloom/grade/sunrays.")
end

-- ------------------------------------------------------------- soil + trim
local plots = workspace:FindFirstChild("Plots")
if plots then
	local plotCount, soilParts = 0, 0
	for _, plot in plots:GetChildren() do
		local soil = plot:FindFirstChild("Soil")
		if not soil then
			log(("SKIP %s: no Soil child."):format(plot.Name))
			continue
		end
		plotCount += 1

		-- consistent tilled soil
		for _, part in soil:GetDescendants() do
			if part:IsA("BasePart") then
				part.Material = CONFIG.soilMaterial
				part.Color = CONFIG.soilColor
				soilParts += 1
			end
		end
		local soilAsPart = soil:IsA("BasePart") and soil
		if soilAsPart then
			soilAsPart.Material = CONFIG.soilMaterial
			soilAsPart.Color = CONFIG.soilColor
			soilParts += 1
		end

		-- wooden trim around the soil footprint
		local ok, cf, size = pcall(function()
			if soil:IsA("Model") then
				return soil:GetBoundingBox()
			end
			local boundsCf, boundsSize
			if soil:IsA("BasePart") then
				boundsCf, boundsSize = soil.CFrame, soil.Size
			else
				local temp = Instance.new("Model")
				for _, child in soil:GetChildren() do
					if child:IsA("BasePart") then
						local weldRef = Instance.new("ObjectValue")
						weldRef.Value = child
						weldRef.Parent = temp
					end
				end
				-- fall back: accumulate manually
				local minV, maxV
				for _, child in soil:GetChildren() do
					if child:IsA("BasePart") then
						local half = child.Size / 2
						local lo = child.Position - half
						local hi = child.Position + half
						minV = minV and Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) or lo
						maxV = maxV and Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) or hi
					end
				end
				temp:Destroy()
				if not minV then
					error("no soil parts")
				end
				boundsCf = CFrame.new((minV + maxV) / 2)
				boundsSize = maxV - minV
			end
			return boundsCf, boundsSize
		end)

		if ok and cf and size then
			local topY = cf.Position.Y + size.Y / 2
			local t = CONFIG.trimThickness
			local h = CONFIG.trimHeight
			local w = size.X + t * 2
			local d = size.Z + t * 2
			local yCenter = topY + h / 2 - 0.35

			local center = Vector3.new(cf.Position.X, yCenter, cf.Position.Z)
			newPart(plot.Name .. "_TrimN", Vector3.new(w, h, t), CFrame.new(center + Vector3.new(0, 0, -(d - t) / 2)), CONFIG.trimMaterial, CONFIG.trimColor)
			newPart(plot.Name .. "_TrimS", Vector3.new(w, h, t), CFrame.new(center + Vector3.new(0, 0, (d - t) / 2)), CONFIG.trimMaterial, CONFIG.trimColor)
			newPart(plot.Name .. "_TrimE", Vector3.new(t, h, d - t * 2), CFrame.new(center + Vector3.new((w - t) / 2, 0, 0)), CONFIG.trimMaterial, CONFIG.trimColor)
			newPart(plot.Name .. "_TrimW", Vector3.new(t, h, d - t * 2), CFrame.new(center + Vector3.new(-(w - t) / 2, 0, 0)), CONFIG.trimMaterial, CONFIG.trimColor)

			-- lantern posts on the 4 corners
			for ix = -1, 1, 2 do
				for iz = -1, 1, 2 do
					local cornerPos = Vector3.new(
						cf.Position.X + ix * (w / 2),
						topY,
						cf.Position.Z + iz * (d / 2)
					)
					local post = newPart(plot.Name .. "_Post", Vector3.new(0.5, 4.4, 0.5),
						CFrame.new(cornerPos + Vector3.new(0, 2.2, 0)), CONFIG.postMaterial, CONFIG.postColor)
					local lampHead = newPart(plot.Name .. "_Lamp", Vector3.new(0.9, 0.9, 0.9),
						CFrame.new(cornerPos + Vector3.new(0, 4.7, 0)), Enum.Material.Neon, CONFIG.lampColor)
					lampHead.CanCollide = false
					local light = Instance.new("PointLight")
					light.Color = CONFIG.lampColor
					light.Brightness = CONFIG.lampBrightness
					light.Range = CONFIG.lampRange
					light.Shadows = false
					light.Parent = lampHead
					local _ = post
				end
			end
		else
			log(("SKIP trim for %s: could not compute soil bounds."):format(plot.Name))
		end
	end
	log(("Plots: styled %d soil parts across %d plots; added trim + corner lanterns."):format(soilParts, plotCount))
else
	log("SKIP: workspace.Plots not found.")
end

-- -------------------------------------------------------------- shop lamps
local shops = workspace:FindFirstChild("Shops")
if shops then
	local lampCount = 0
	for _, shop in shops:GetChildren() do
		local pad = shop:FindFirstChild("TPPart", true)
		if pad and pad:IsA("BasePart") then
			local base = pad.Position + Vector3.new(pad.Size.X / 2 + 1.5, 0, 0)
			local ground = base.Y + pad.Size.Y / 2
			local post = newPart(shop.Name .. "_Lamp", Vector3.new(0.6, 7, 0.6),
				CFrame.new(base.X, ground + 3.5, base.Z), CONFIG.postMaterial, CONFIG.postColor)
			local head = newPart(shop.Name .. "_LampHead", Vector3.new(1.2, 1.2, 1.2),
				CFrame.new(base.X, ground + 7.4, base.Z), Enum.Material.Neon, CONFIG.lampColor)
			head.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color = CONFIG.lampColor
			light.Brightness = 1.1
			light.Range = 18
			light.Shadows = false
			light.Parent = head
			local _ = post
			lampCount += 1
		else
			log(("SKIP lamp for shop %s: no TPPart found."):format(shop.Name))
		end
	end
	log(("Shops: added %d lamp posts beside teleport pads."):format(lampCount))
else
	log("SKIP: workspace.Shops not found.")
end

-- ------------------------------------------------------------------ report
print("================ MAP POLISH REPORT ================")
for _, line in report do
	print("• " .. line)
end
print("Re-run any time — MapPolish rebuilds cleanly. Save the place when happy.")
