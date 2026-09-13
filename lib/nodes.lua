local rooms = workspace:WaitForChild("CurrentRooms")

local lift = Vector3.new(0, 3, 0)

local nodes = {}
local saved = {}

local path = {}
path.__index = path

local function grab(room)
	local folder = room:FindFirstChild("PathfindNodes")
	if not folder then
		return saved[room]
	end
	local list = folder:GetChildren()
	table.sort(list, function(a, b)
		return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
	end)
	local spots = {}
	for _, node in list do
		table.insert(spots, node.Position + lift)
	end
	saved[room] = spots
	return spots
end

local function watch(room)
	task.spawn(function()
		if room:WaitForChild("PathfindNodes", 10) then
			grab(room)
		end
	end)
end

local added = rooms.ChildAdded:Connect(watch)
local removed = rooms.ChildRemoved:Connect(function(room)
	saved[room] = nil
end)

for _, room in rooms:GetChildren() do
	watch(room)
end

function nodes.new()
	return setmetatable({spots = {}, marks = {}, rooms = {}, length = 0}, path)
end

function path:add(spot)
	local last = self.spots[#self.spots]
	if last then
		local gap = (spot - last).Magnitude
		if gap < 0.5 then
			return
		end
		self.length += gap
	end
	table.insert(self.spots, spot)
	table.insert(self.marks, self.length)
end

function path:at(dist)
	local spots, marks = self.spots, self.marks
	for i = 2, #spots do
		if marks[i] >= dist then
			return spots[i - 1]:Lerp(spots[i], math.max(dist - marks[i - 1], 0) / (marks[i] - marks[i - 1]))
		end
	end
	return spots[#spots]
end

function nodes.between(first, last)
	local route = nodes.new()
	for number = first, last do
		local room = rooms:FindFirstChild(tostring(number))
		if room then
			route.rooms[number] = route.length
			local entrance = room:FindFirstChild("RoomEntrance")
			local exit = room:FindFirstChild("RoomExit")
			if entrance then
				route:add(entrance.Position)
			end
			for _, spot in grab(room) or {} do
				route:add(spot)
			end
			if exit then
				route:add(exit.Position)
			end
		end
	end
	return route
end

function nodes.stop()
	added:Disconnect()
	removed:Disconnect()
end

return nodes
