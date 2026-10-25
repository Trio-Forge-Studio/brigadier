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

return Class
