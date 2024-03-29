DebugToolsHelpers = {}

function DebugToolsHelpers.tableCount(tbl)
	local count = 0
	for _ in pairs(tbl) do count = count + 1 end
	return count
end

function DebugToolsHelpers.stringSplit(txt, pat)
	local parts = {}  -- NOTE: use {n = 0} in Lua-5.0
	local fPat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = string.find(txt, fPat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(parts, cap)
		end
		last_end = e + 1
		s, e, cap = string.find(txt, fPat, last_end)
	end
	if last_end <= #txt then
		cap = string.sub(txt, last_end)
		table.insert(parts, cap)
	end
	return parts
end
