local players = game:GetService("Players")
local storage = game:GetService("ReplicatedStorage")

local plr = players.LocalPlayer
local remotes = storage:WaitForChild("RemotesFolder")

local folder = "discoloration"

local death = {}

local function tally(cause)
	if not isfolder(folder) then
		makefolder(folder)
	end
	local file = folder .. "/" .. cause:lower() .. "_deaths.txt"
	local count = (isfile(file) and tonumber(readfile(file)) or 0) + 1
	writefile(file, tostring(count))
	return count
end

function death.kill(cause, tiers, style)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end

	local undo = {}

	local stats = storage.GameStats:FindFirstChild("Player_" .. plr.Name)
	for _, value in stats and stats:GetDescendants() or {} do
		if value.Name == "DeathCause" and value:IsA("StringValue") then
			value.Value = cause
			local link = value.Changed:Connect(function()
				value.Value = cause
			end)
			table.insert(undo, function()
				link:Disconnect()
			end)
		end
	end

	local lines = tiers[math.min(tally(cause), #tiers)]
	for _, link in getconnections(remotes.DeathHint.OnClientEvent) do
		if link.Function and debug.info(link.Function, "s"):find("%.Health$") then
			link.Function(lines, style)
			link:Disable()
			table.insert(undo, function()
				link:Enable()
			end)
		end
	end

	plr.CharacterAdded:Once(function()
		for _, fix in undo do
			fix()
		end
	end)

	char:SetAttribute("DeathCause", cause)
	hum.Health = 0
end

return death
