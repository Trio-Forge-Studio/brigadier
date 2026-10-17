--!strict

-- Classes are metatables: an instance's metatable is its class, and a subclass's metatable has
-- `__index` set to its parent class.

local Class = {}

function Class.isInstance(value: unknown, class: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local current: any = getmetatable(value :: any)
	while type(current) == "table" do
		if rawequal(current, class) then
			return true
		end
		local parent = getmetatable(current)
		current = if type(parent) == "table" then rawget(parent, "__index") else nil
	end
	return false
end

-- Makes `parent` the superclass of `class`, and copies the metamethods instances look up directly
-- on their metatable, which `__index` doesn't inherit.
function Class.extend<T>(class: T, parent: any): T
	setmetatable(class :: any, { __index = parent })
	for _, metamethod in { "__tostring", "__eq", "__lt", "__le" } do
		if rawget(class :: any, metamethod) == nil and parent[metamethod] ~= nil then
			(class :: any)[metamethod] = parent[metamethod]
		end
	end
	return class
end

return Class
