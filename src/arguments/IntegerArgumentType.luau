--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local CommandSyntaxException = require("../exceptions/CommandSyntaxException")
local JavaFormat = require("../util/JavaFormat")

type IntegerArgumentType = Types.IntegerArgumentType & {
	_minimum: number,
	_maximum: number,
}

local EXAMPLES = { "0", "123", "-123" }

local MIN_VALUE = -2147483648
local MAX_VALUE = 2147483647

local IntegerArgumentType = {}
IntegerArgumentType.__index = IntegerArgumentType

function IntegerArgumentType.integer(min: number?, max: number?): Types.IntegerArgumentType
	local self: IntegerArgumentType = setmetatable({
		_minimum = min or MIN_VALUE,
		_maximum = max or MAX_VALUE,
	}, IntegerArgumentType) :: any
	return self
end

function IntegerArgumentType.isInstance(value: unknown): boolean
	return Class.isInstance(value, IntegerArgumentType)
end

function IntegerArgumentType.getInteger(context: Types.CommandContext<any>, name: string): number
	return context:getArgument(name, "number")
end

function IntegerArgumentType.getMinimum(self: IntegerArgumentType): number
	return self._minimum
end

function IntegerArgumentType.getMaximum(self: IntegerArgumentType): number
	return self._maximum
end

function IntegerArgumentType.parse(self: IntegerArgumentType, reader: Types.StringReader, _source: any?): number
	local start = reader:getCursor()
	local result = reader:readInt()
	if result < self._minimum then
		reader:setCursor(start)
		error(
			CommandSyntaxException.BUILT_IN_EXCEPTIONS:integerTooLow():createWithContext(reader, result, self._minimum)
		)
	end
	if result > self._maximum then
		reader:setCursor(start)
		error(
			CommandSyntaxException.BUILT_IN_EXCEPTIONS:integerTooHigh():createWithContext(reader, result, self._maximum)
		)
	end
	return result
end

function IntegerArgumentType.equals(self: IntegerArgumentType, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not IntegerArgumentType.isInstance(other) then
		return false
	end

	local that = other :: IntegerArgumentType
	return self._maximum == that._maximum and self._minimum == that._minimum
end

function IntegerArgumentType.__tostring(self: IntegerArgumentType): string
	if self._minimum == MIN_VALUE and self._maximum == MAX_VALUE then
		return "integer()"
	elseif self._maximum == MAX_VALUE then
		return "integer(" .. JavaFormat.integer(self._minimum) .. ")"
	else
		return "integer(" .. JavaFormat.integer(self._minimum) .. ", " .. JavaFormat.integer(self._maximum) .. ")"
	end
end

function IntegerArgumentType.getExamples(_self: IntegerArgumentType): { string }
	return EXAMPLES
end

return IntegerArgumentType
