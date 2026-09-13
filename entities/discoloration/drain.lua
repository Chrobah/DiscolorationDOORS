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
local routed = {}
local links = {}
local amount = 0
local screen, hush, ambience, loop

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

local function reroute(thing)
	if thing:IsA("Sound") and not thing.SoundGroup then
		routed[thing] = true
		thing.SoundGroup = sounds.Main
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
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local here = plr:GetAttribute("CurrentRoom")
	if not hum or hum.Health <= 0 or typeof(here) ~= "number" then
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
	hush:Destroy()
	ambience:Destroy()
end

local function start()
	amount = 0

	screen = Instance.new("ColorCorrectionEffect")
	screen.Name = "Discoloration"
	screen.Parent = lighting

	hush = Instance.new("EqualizerSoundEffect")
	hush.Name = "Discoloration"
	hush.HighGain, hush.MidGain, hush.LowGain = 0, 0, 0
	hush.Parent = sounds.Main

	ambience = Instance.new("Sound")
	ambience.Name = "Discoloration"
	ambience.SoundId = "rbxassetid://132917229044801"
	ambience.Looped = true
	ambience.Volume = 0
	ambience.Parent = sounds
	ambience:Play()

	loop = runService.RenderStepped:Connect(function(dt)
		amount += (goal() - amount) * math.min(dt * 1.5, 1)
		local gain = math.max(20 * math.log10(math.max(1 - amount, 0.0001)), -80)
		screen.Saturation = -amount
		screen.Contrast = amount * 0.1
		hush.HighGain, hush.MidGain, hush.LowGain = gain, gain, gain
		ambience.Volume = amount * loudest
		if not next(drained) and amount < 0.005 then
			quiet()
		end
	end)
end

local function mark(number)
	local list = {}
	local room = rooms:FindFirstChild(tostring(number))
	if not room then
		return list
	end
	local fresh = not drained[number]
	drained[number] = true
	local entrance = room:FindFirstChild("RoomEntrance")
	local from = entrance and entrance.Position or room:GetPivot().Position
	for _, thing in room:GetDescendants() do
		local spot = where(thing)
		if spot then
			table.insert(list, {thing = thing, key = (spot - from).Magnitude})
		elseif fresh then
			reroute(thing)
		end
	end
	table.sort(list, function(a, b)
		return a.key < b.key
	end)
	if fresh then
		links[room] = room.DescendantAdded:Connect(function(thing)
			reroute(thing)
			if where(thing) then
				paint(thing)
			end
		end)
	end
	if not loop then
		start()
	end
	return list
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
		routed[thing] = nil
		if links[thing] then
			links[thing]:Disconnect()
			links[thing] = nil
		end
	end
end)

drain.mono = mono

function drain.level()
	return loop and amount or 0
end

function drain.spread(route)
	local lists, cursors = {}, {}
	return function(dist)
		local budget = 300
		local done = true
		for number, start in route.rooms do
			if dist < start then
				done = false
				continue
			end
			local list = lists[number]
			if not list then
				list = mark(number)
				lists[number] = list
				cursors[number] = 1
			end
			local index = cursors[number]
			while budget > 0 and list[index] and start + list[index].key <= dist do
				if list[index].thing.Parent then
					paint(list[index].thing)
				end
				index += 1
				budget -= 1
			end
			cursors[number] = index
			if list[index] then
				done = false
			end
		end
		return done
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
	for thing in routed do
		thing.SoundGroup = nil
	end
	table.clear(links)
	table.clear(colors)
	table.clear(originals)
	table.clear(routed)
	table.clear(drained)
	if loop then
		quiet()
	end
end

return drain
