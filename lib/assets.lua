local folder = "discoloration"
local cache = {}

return function(url)
	if cache[url] then
		return cache[url]
	end
	if not isfolder(folder) then
		makefolder(folder)
	end
	local file = folder .. "/" .. url:match("[^/]+$")
	if not isfile(file) then
		writefile(file, game:HttpGet(url))
	end
	cache[url] = getcustomasset(file)
	return cache[url]
end
