local players = game:GetService("Players")
local lighting = game:GetService("Lighting")
local runService = game:GetService("RunService")
local sounds = game:GetService("SoundService")
local collection = game:GetService("CollectionService")

local plr = players.LocalPlayer
local rooms = workspace:WaitForChild("CurrentRooms")

local inside = 30
local outside = 60
local loudest = 0.18

local drain = {}
local drained = {}
local colors = {}
local originals = {}
local links = {}
local amount = 0
local screen, ambience, loop

local function mono(color)
	local shade = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	return Color3.new(shade, shade, shade)
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function guard(thing)
	local original = thing:GetAttribute("OriginalColor")
	if typeof(original) == "Color3" then
		originals[thing] = original
		thing:SetAttribute("OriginalColor", mono(original))
	end
	links[thing] = thing:GetPropertyChangedSignal("Color"):Connect(function()
		local color = thing.Color
		if math.abs(color.R - color.G) + math.abs(color.G - color.B) > 0.01 then
			thing.Color = mono(color)
		end
	end)
end

local function paint(thing)
	if colors[thing] then
		return
	end
	if thing:IsA("Decal") then
		colors[thing] = thing.Color3
		thing.Color3 = mono(thing.Color3)
		return
	end
	colors[thing] = thing.Color
	thing.Color = mono(thing.Color)
	if thing:IsA("Light") or collection:HasTag(thing, "ArchivesLight") then
		guard(thing)
	end
end

local function where(thing)
	if thing:IsA("BasePart") then
		return (thing.Transparency < 1 or collection:HasTag(thing, "ArchivesLight")) and thing.Position
	end
	if thing:IsA("Light") or thing:IsA("Decal") then
		local holder = thing.Parent
		if holder:IsA("Attachment") then
			return holder.WorldPosition
		elseif holder:IsA("BasePart") then
			return holder.Position
		end
	end
end

local function door(number, name)
	local room = rooms:FindFirstChild(tostring(number))
	return room and room:FindFirstChild(name)
end

local function edge(part, flip)
	if not part then
		return nil
	end
	local offset = workspace.CurrentCamera.CFrame.Position - part.Position
	if offset:Dot(part.CFrame.LookVector) * flip > 0 then
		return 0.5 - 0.5 * smooth(offset.Magnitude / outside)
	end
	return 0.5 + 0.5 * smooth(offset.Magnitude / inside)
end

local function goal()
	local here = plr:GetAttribute("CurrentRoom")
	if typeof(here) ~= "number" then
		return 0
	end
	if drained[here] then
		local ahead = drained[here + 1] and 1 or edge(door(here, "RoomExit"), 1) or 1
		local behind = (drained[here - 1] or not rooms:FindFirstChild(tostring(here - 1))) and 1
			or edge(door(here, "RoomEntrance"), -1)
			or 1
		return math.min(ahead, behind)
	end
	local back = drained[here - 1] and edge(door(here - 1, "RoomExit"), 1) or 0
	local front = drained[here + 1] and edge(door(here + 1, "RoomEntrance"), -1) or 0
	return math.max(back, front)
end

local function quiet()
	loop:Disconnect()
	loop = nil
	screen:Destroy()
	ambience:Destroy()
end

local function start()
	amount = 0

	screen = Instance.new("ColorCorrectionEffect")
	screen.Name = "Discoloration"
	screen.Parent = lighting

	ambience = Instance.new("Sound")
	ambience.Name = "Discoloration"
	ambience.SoundId = "rbxassetid://132917229044801"
	ambience.Looped = true
	ambience.Volume = 0
	ambience.SoundGroup = sounds.Main.Ambience
	ambience.Parent = sounds
	ambience:Play()

	loop = runService.RenderStepped:Connect(function(dt)
		amount += (goal() - amount) * math.min(dt * 1.5, 1)
		screen.Saturation = -amount
		screen.Contrast = amount * 0.1
		ambience.Volume = amount * loudest
		if not next(drained) and amount < 0.005 then
			quiet()
		end
	end)
end

local function mark(number)
	drained[number] = true
	local room = rooms:FindFirstChild(tostring(number))
	if room then
		links[room] = room.DescendantAdded:Connect(function(thing)
			if where(thing) then
				paint(thing)
			end
		end)
	end
	if not loop then
		start()
	end
end

local unload = rooms.ChildRemoved:Connect(function(room)
	local number = tonumber(room.Name)
	if not drained[number] then
		return
	end
	drained[number] = nil
	if links[room] then
		links[room]:Disconnect()
		links[room] = nil
	end
	for _, thing in room:GetDescendants() do
		colors[thing] = nil
		originals[thing] = nil
		if links[thing] then
			links[thing]:Disconnect()
			links[thing] = nil
		end
	end
end)

function drain.spread(route)
	local list = {}
	for number, start in route.rooms do
		local room = rooms:FindFirstChild(tostring(number))
		if room then
			local entrance = room:FindFirstChild("RoomEntrance")
			local from = entrance and entrance.Position or room:GetPivot().Position
			for _, thing in room:GetDescendants() do
				local spot = where(thing)
				if spot then
					table.insert(list, {thing = thing, key = start + (spot - from).Magnitude})
				end
			end
			task.wait()
		end
	end
	table.sort(list, function(a, b)
		return a.key < b.key
	end)

	local index = 1
	return function(dist)
		for number, start in route.rooms do
			if start <= dist and not drained[number] then
				mark(number)
			end
		end
		local budget = index + 300
		while list[index] and list[index].key <= dist and index < budget do
			if list[index].thing.Parent then
				paint(list[index].thing)
			end
			index += 1
		end
		return list[index] == nil
	end
end

function drain.clear()
	unload:Disconnect()
	for _, link in links do
		link:Disconnect()
	end
	for thing, color in colors do
		if thing:IsA("Decal") then
			thing.Color3 = color
		else
			thing.Color = color
		end
	end
	for thing, original in originals do
		thing:SetAttribute("OriginalColor", original)
	end
	table.clear(links)
	table.clear(colors)
	table.clear(originals)
	table.clear(drained)
	if loop then
		quiet()
	end
end

return drain
