--!strict

-- java.util.Objects.equals, with Java's collection equality for arrays and maps.

local Objects = {}

local function definesEquals(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local metatable = getmetatable(value :: any)
	return type(metatable) == "table" and type((value :: any).equals) == "function"
end

function Objects.equals(a: unknown, b: unknown): boolean
	if rawequal(a, b) then
		return true
	end
	if a == nil or b == nil then
		return false
	end
	if definesEquals(a) then
		return (a :: any):equals(b)
	end
	if
		type(a) == "table"
		and type(b) == "table"
		and getmetatable(a :: any) == nil
		and getmetatable(b :: any) == nil
	then
		local left = a :: { [unknown]: unknown }
		local right = b :: { [unknown]: unknown }
		for key, value in left do
			if not Objects.equals(value, right[key]) then
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
	return a == b
end

return Objects
