local base = getgenv().DiscolorationSource or "https://raw.githubusercontent.com/Chrobah/DiscolorationDOORS/main/"

if getgenv().Discoloration then
	getgenv().Discoloration.stop()
end

local loaded = {}

local function import(name)
	if loaded[name] == nil then
		loaded[name] = assert(loadstring(game:HttpGet(base .. name .. ".lua"), "@" .. name))(import, base)
	end
	return loaded[name]
end

getgenv().Discoloration = import("entities/discoloration/init").start()
print("Armed Discoloration")
