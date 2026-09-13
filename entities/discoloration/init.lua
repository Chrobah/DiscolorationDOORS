local import = ...

local nodes = import("lib/nodes")
local death = import("lib/death")
local drain = import("entities/discoloration/drain")
local hurt = import("entities/discoloration/hurt")
local build = import("entities/discoloration/model")
local hints = import("entities/discoloration/hints")

local players = game:GetService("Players")
local storage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local collection = game:GetService("CollectionService")
local tweens = game:GetService("TweenService")

local plr = players.LocalPlayer
local rooms = workspace:WaitForChild("CurrentRooms")
local gameData = storage:WaitForChild("GameData")
local remotes = storage:WaitForChild("RemotesFolder")

local speed = 60
local reach = 12
local pace = 0.05
local lethal = 1.5
local lookback = 4
local warning = 2.5
local chance = 1 / 9
local breather = 12
local sector = "H"

local entity = {}
local links = {}
local random = Random.new()
local running
local lastSpawn = -math.huge

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function caught(model)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 or char:GetAttribute("Hiding") then
		return nil
	end
	local gap = root.Position - model.Position
	if gap.Magnitude > reach then
		return nil
	end
	params.FilterDescendantsInstances = {char, model}
	return workspace:Raycast(model.Position, gap, params) == nil and hum or nil
end

local function sectorOf(number)
	local room = rooms:FindFirstChild(tostring(number))
	local door = room and room:FindFirstChild("Door")
	local sign = door and door:FindFirstChild("Stinker", true)
	return sign and sign.Text:match("^(%u)%-")
end

function entity.spawn()
	if running then
		return
	end
	local latest = gameData.LatestRoom.Value
	local first = latest
	while first > latest - lookback and rooms:FindFirstChild(tostring(first - 1)) do
		first -= 1
	end
	local route = nodes.between(first, latest)
	if route.length < 30 then
		return
	end
	local token = {}
	running = token

	task.spawn(function()
		local here = plr:GetAttribute("CurrentRoom") or latest
		local wall = route.rooms[here + 1] or route.length
		local spread = drain.spread(route)

		local clock = 0
		while clock < warning and running == token do
			clock += task.wait()
			spread(wall * math.min(clock / warning, 1))
		end
		task.wait(random:NextNumber(1.5, 3))
		if running ~= token then
			return
		end

		local model = build()
		model.CFrame = CFrame.new(route:at(0))
		model:SetAttribute("DisturbRadius", 30)
		model:SetAttribute("DisturbBreakChance", 0)
		model.Parent = workspace
		collection:AddTag(model, "LightDisturber")
		model.Noise:Play()
		tweens:Create(model.Noise, TweenInfo.new(2), {Volume = 1.5}):Play()

		local dist, shake, sting = 0, 0, 0
		local last = latest
		while dist < route.length and running == token do
			local dt = runService.Heartbeat:Wait()
			while last < gameData.LatestRoom.Value and rooms:FindFirstChild(tostring(last + 1)) do
				last += 1
				route:room(last)
			end
			dist += speed * dt
			shake -= dt
			model.CFrame = CFrame.new(route:at(dist) + Vector3.new(0, math.sin(os.clock() * 2.5) * 0.35, 0))
			spread(math.max(wall, dist + 15))
			if shake <= 0 then
				shake = 0.2
				remotes.CamShakeRelativeClient:Fire(model.Position, 2, 12, 0, 0.5)
			end
			local hum = caught(model)
			sting = hum and sting + dt or 0
			while hum and sting >= pace do
				sting -= pace
				hurt.hit()
				death.hurt(hum.MaxHealth * pace / lethal, "Discoloration", hints, "Yellow")
			end
		end

		collection:RemoveTag(model, "LightDisturber")
		for _, thing in model:GetDescendants() do
			if thing:IsA("ParticleEmitter") then
				thing.Enabled = false
			end
		end
		tweens:Create(model.PointLight, TweenInfo.new(1), {Brightness = 0}):Play()
		tweens:Create(model.Noise, TweenInfo.new(1), {Volume = 0}):Play()
		task.wait(1.5)
		model:Destroy()

		while running == token and not spread(math.huge) do
			task.wait()
		end
		if running == token then
			running = nil
		end
	end)
end

function entity.start()
	table.insert(links, gameData.LatestRoom.Changed:Connect(function(latest)
		if running or latest - lastSpawn < breather or gameData.Floor.Value ~= "Archives" then
			return
		end
		local letter = sectorOf(latest - 1)
		local room = rooms:FindFirstChild(tostring(latest))
		if not letter or letter < sector or gameData.ChaseInSession.Value then
			return
		end
		if room and room:GetAttribute("HidingRoom") == false or random:NextNumber() > chance then
			return
		end
		lastSpawn = latest
		task.delay(random:NextNumber(2, 5), entity.spawn)
	end))
	return entity
end

function entity.stop()
	running = nil
	for _, link in links do
		link:Disconnect()
	end
	table.clear(links)
	nodes.stop()
	hurt.clear()
	drain.clear()
end

return entity
