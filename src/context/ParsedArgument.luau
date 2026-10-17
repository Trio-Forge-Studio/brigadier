--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local Objects = require("../util/Objects")
local StringRange = require("./StringRange")

-- The source type, and the result type of an argument. The public types in Types.luau keep them
-- generic; the implementation uses `any`, which keeps the new solver from giving up on these
-- mutually recursive types.
type S = any
type T = any

type ParsedArgument = Types.ParsedArgument<S, T> & {
	_range: Types.StringRange,
	_result: T,
}

local ParsedArgument = {}
ParsedArgument.__index = ParsedArgument

function ParsedArgument.new(start: number, finish: number, result: T): Types.ParsedArgument<S, T>
	local self: ParsedArgument = setmetatable({
		_range = StringRange.between(start, finish),
		_result = result,
	}, ParsedArgument) :: any
	return self
end

function ParsedArgument.isInstance(value: unknown): boolean
	return Class.isInstance(value, ParsedArgument)
end

function ParsedArgument.getRange(self: ParsedArgument): Types.StringRange
	return self._range
end

function ParsedArgument.getResult(self: ParsedArgument): T
	return self._result
end

function ParsedArgument.equals(self: ParsedArgument, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not ParsedArgument.isInstance(other) then
		return false
	end
	local that = other :: ParsedArgument
	return Objects.equals(self._range, that._range) and Objects.equals(self._result, that._result)
end

return ParsedArgument
