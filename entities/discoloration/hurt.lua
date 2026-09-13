local import = ...

local drain = import("entities/discoloration/drain")

local players = game:GetService("Players")
local storage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local plr = players.LocalPlayer

local recovery = 180
local doubling = 0.13
local grace = 0.1
local burst = 15
local spacing = 0.012
local soakGap = 0.17

local limbs = {
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	LeftUpperArm = "LeftArm",
	LeftLowerArm = "LeftArm",
	LeftHand = "LeftArm",
	RightUpperArm = "RightArm",
	RightLowerArm = "RightArm",
	RightHand = "RightArm",
	LeftUpperLeg = "LeftLeg",
	LeftLowerLeg = "LeftLeg",
	LeftFoot = "LeftLeg",
	RightUpperLeg = "RightLeg",
	RightLowerLeg = "RightLeg",
	RightFoot = "RightLeg",
}

local clothes = {
	Shirt = {property = "ShirtTemplate", limbs = {"Torso", "LeftArm", "RightArm"}},
	ShirtGraphic = {property = "Graphic", limbs = {"Torso"}},
	Pants = {property = "PantsTemplate", limbs = {"LeftLeg", "RightLeg"}},
}

local hurt = {}
local random = Random.new()
local order = {}
local colors = {}
local tints = {}
local stripped = {}
local dots = {}
local links = {}
local stain = 0
local bare = false
local lastHit = -math.huge
local soaked = -math.huge
local gui

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = random:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function bodies()
	local rigs = storage:FindFirstChild("PlayerRigs")
	return {plr.Character, rigs and rigs:FindFirstChild(plr.Name)}
end

local function limbOf(part)
	if part.Parent:IsA("Accessory") then
		local weld = part:FindFirstChildWhichIsA("JointInstance")
		local limb = weld and (weld.Part0 == part and weld.Part1 or weld.Part0)
		return limb and limbs[limb.Name]
	end
	return limbs[part.Name]
end

local function strip(thing, property, blank)
	if stripped[thing] then
		return
	end
	stripped[thing] = {property = property, value = thing[property], blank = blank}
	if bare then
		thing[property] = blank
	end
end

local function soak(key)
	for _, body in bodies() do
		for _, thing in body:GetDescendants() do
			local cloth = clothes[thing.ClassName]
			if thing:IsA("BasePart") and limbOf(thing) == key then
				colors[thing] = colors[thing] or thing.Color
				local mesh = thing:FindFirstChildWhichIsA("SpecialMesh")
				local look = thing:FindFirstChildWhichIsA("SurfaceAppearance")
				if thing:IsA("MeshPart") and thing.TextureID ~= "" then
					strip(thing, "TextureID", "")
				end
				if mesh and mesh.TextureId ~= "" then
					strip(mesh, "TextureId", "")
				end
				if look then
					strip(look, "Parent", nil)
				end
			elseif thing:IsA("BodyColors") then
				tints[thing] = tints[thing] or {}
				tints[thing][key] = tints[thing][key] or thing[key .. "Color3"]
			elseif cloth and table.find(cloth.limbs, key) then
				strip(thing, cloth.property, "")
			end
		end
	end
end

local function apply()
	for part, color in colors do
		part.Color = color:Lerp(drain.mono(color), stain)
	end
	for body, saved in tints do
		for key, color in saved do
			body[key .. "Color3"] = color:Lerp(drain.mono(color), stain)
		end
	end
	if bare ~= (stain >= 0.5) then
		bare = stain >= 0.5
		for thing, info in stripped do
			if info.property ~= "Parent" or info.value.Parent then
				thing[info.property] = if bare then info.blank else info.value
			end
		end
	end
	for _, dot in dots do
		dot.frame.BackgroundTransparency = 1 - stain
	end
end

local function speck()
	for _ = 1, 30 do
		local x, y = random:NextNumber(0.02, 0.98), random:NextNumber(0.02, 0.98)
		local taken = false
		for _, dot in dots do
			if math.abs(dot.x - x) < spacing and math.abs(dot.y - y) < spacing then
				taken = true
				break
			end
		end
		if not taken then
			local frame = Instance.new("Frame")
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromScale(x, y)
			frame.Size = UDim2.fromOffset(1, 1)
			frame.BackgroundColor3 = Color3.new(1, 1, 1)
			frame.BorderSizePixel = 0
			frame.Parent = gui
			table.insert(dots, {frame = frame, x = x, y = y, size = 1})
			return
		end
	end
end

local function step(dt)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local alive = hum ~= nil and hum.Health > 0
	gui.Enabled = alive
	if os.clock() - lastHit < grace then
		for _, dot in dots do
			dot.size *= 2 ^ (dt / doubling)
			dot.frame.Size = UDim2.fromOffset(math.floor(dot.size), math.floor(dot.size))
		end
	elseif alive then
		stain = math.max(stain - dt / recovery * (1 - drain.level()), 0)
		apply()
		if stain == 0 then
			hurt.clear()
		end
	end
end

function hurt.hit()
	lastHit = os.clock()
	stain = 1
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "Discoloration"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 100
		gui.Parent = gethui()
		order = shuffle({"LeftArm", "RightArm"})
		for _, key in shuffle({"Torso", "LeftLeg", "RightLeg", "Head"}) do
			table.insert(order, key)
		end
		table.insert(links, runService.RenderStepped:Connect(step))
		table.insert(links, plr.CharacterAdded:Connect(hurt.clear))
	end
	if os.clock() - soaked >= soakGap then
		soaked = os.clock()
		local key = table.remove(order, 1)
		if key then
			soak(key)
		end
	end
	for _ = 1, burst do
		speck()
	end
	apply()
end

function hurt.clear()
	stain = 0
	soaked = -math.huge
	apply()
	for _, link in links do
		link:Disconnect()
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	table.clear(links)
	table.clear(order)
	table.clear(colors)
	table.clear(tints)
	table.clear(stripped)
	table.clear(dots)
end

return hurt
