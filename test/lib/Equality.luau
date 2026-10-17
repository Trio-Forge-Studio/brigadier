--!strict

-- Java's equality as the tests see it: Object.equals for classes that define it, element by element
-- for lists and key by key for maps.

local Equality = {}

local function hasEquals(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local ok, method = pcall(function()
		return (value :: any).equals
	end)
	return ok and type(method) == "function"
end

local function isPlainTable(value: unknown): boolean
	return type(value) == "table" and getmetatable(value :: any) == nil
end

function Equality.equals(a: unknown, b: unknown): boolean
	if rawequal(a, b) then
		return true
	end
	if a == nil or b == nil then
		return false
	end
	if type(a) == "number" and type(b) == "number" then
		return a == b
	end
	if hasEquals(a) then
		return (a :: any):equals(b)
	end
	if isPlainTable(a) and isPlainTable(b) then
		local left = a :: { [unknown]: unknown }
		local right = b :: { [unknown]: unknown }
		for key, value in left do
			if not Equality.equals(value, right[key]) then
				return false
			end
		end
		for key in right do
			if left[key] == nil then
				return false
			end
		end
		return true
	end
	return false
end

local function describeTable(value: { [unknown]: unknown }, seen: { [unknown]: boolean }): string
	if seen[value] then
		return "<cycle>"
	end
	seen[value] = true
	local parts = {}
	local count = #value
	for index = 1, count do
		table.insert(parts, Equality.describe(value[index], seen))
	end
	local keys = {}
	for key in value do
		if not (type(key) == "number" and key >= 1 and key <= count and key % 1 == 0) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(x, y)
		return tostring(x) < tostring(y)
	end)
	for _, key in keys do
		table.insert(parts, `{Equality.describe(key, seen)}={Equality.describe(value[key], seen)}`)
	end
	seen[value] = nil
	return "[" .. table.concat(parts, ", ") .. "]"
end

function Equality.describe(value: unknown, seen: { [unknown]: boolean }?): string
	if type(value) == "string" then
		return `"{value}"`
	end
	if isPlainTable(value) then
		return describeTable(value :: any, seen or {})
	end
	return tostring(value)
end

return Equality
