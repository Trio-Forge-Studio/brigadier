--!strict

-- Guava's EqualsTester without the hashCode checks, since the port has no hashCode: every item equals
-- itself and the rest of its group, and nothing in another group, nil, or an unrelated object.

local Equality = require("./Equality")

local EqualsTester = {}
EqualsTester.__index = EqualsTester

export type EqualsTester = typeof(setmetatable({} :: { groups: { { unknown } } }, EqualsTester))

local NOT_AN_INSTANCE = setmetatable({}, {
	__tostring = function()
		return "NotAnInstance"
	end,
})

function EqualsTester.new(): EqualsTester
	return setmetatable({ groups = {} }, EqualsTester)
end

function EqualsTester.addEqualityGroup(self: EqualsTester, ...: unknown): EqualsTester
	local group = {}
	for index = 1, select("#", ...) do
		local item = select(index, ...)
		assert(item ~= nil, "EqualsTester: an equality group can't contain nil")
		table.insert(group, item)
	end
	assert(#group > 0, "EqualsTester: an equality group can't be empty")
	table.insert(self.groups, group)
	return self
end

local function equals(a: unknown, b: unknown): boolean
	if type(a) == "table" and type((a :: any).equals) == "function" then
		return (a :: any):equals(b)
	end
	return rawequal(a, b)
end

local function label(groupIndex: number, itemIndex: number, item: unknown): string
	return `[group {groupIndex}, item {itemIndex}] {Equality.describe(item)}`
end

function EqualsTester.testEquals(self: EqualsTester)
	for groupIndex, group in self.groups do
		for itemIndex, item in group do
			local name = label(groupIndex, itemIndex, item)
			if equals(item, nil) then
				error(`{name} must not be equal to nil`, 2)
			end
			if equals(item, NOT_AN_INSTANCE) then
				error(`{name} must not be equal to an arbitrary object of another class`, 2)
			end
			if not equals(item, item) then
				error(`{name} must be equal to itself`, 2)
			end
			for otherGroupIndex, otherGroup in self.groups do
				for otherIndex, other in otherGroup do
					if otherGroupIndex == groupIndex and otherIndex ~= itemIndex then
						if not equals(item, other) then
							error(`{name} must be equal to {label(otherGroupIndex, otherIndex, other)}`, 2)
						end
					elseif otherGroupIndex ~= groupIndex then
						if equals(item, other) then
							error(`{name} must not be equal to {label(otherGroupIndex, otherIndex, other)}`, 2)
						end
					end
				end
			end
		end
	end
end

return EqualsTester
