--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local CommandSyntaxException = require("../exceptions/CommandSyntaxException")
local JavaFormat = require("../util/JavaFormat")

type LongArgumentType = Types.LongArgumentType & {
	_minimum: number,
	_maximum: number,
}

local EXAMPLES = { "0", "123", "-123" }

local MIN_VALUE = -2 ^ 63
local MAX_VALUE = 2 ^ 63

local LongArgumentType = {}
LongArgumentType.__index = LongArgumentType

function LongArgumentType.longArg(min: number?, max: number?): Types.LongArgumentType
	local self: LongArgumentType = setmetatable({
		_minimum = min or MIN_VALUE,
		_maximum = max or MAX_VALUE,
	}, LongArgumentType) :: any
	return self
end

function LongArgumentType.isInstance(value: unknown): boolean
	return Class.isInstance(value, LongArgumentType)
end

function LongArgumentType.getLong(context: Types.CommandContext<any>, name: string): number
	return context:getArgument(name, "number")
end

function LongArgumentType.getMinimum(self: LongArgumentType): number
	return self._minimum
end

function LongArgumentType.getMaximum(self: LongArgumentType): number
	return self._maximum
end

function LongArgumentType.parse(self: LongArgumentType, reader: Types.StringReader, _source: any?): number
	local start = reader:getCursor()
	local result = reader:readLong()
	if result < self._minimum then
		reader:setCursor(start)
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:longTooLow():createWithContext(reader, result, self._minimum))
	end
	if result > self._maximum then
		reader:setCursor(start)
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:longTooHigh():createWithContext(reader, result, self._maximum))
	end
	return result
end

function LongArgumentType.equals(self: LongArgumentType, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not LongArgumentType.isInstance(other) then
		return false
	end

	local that = other :: LongArgumentType
	return self._maximum == that._maximum and self._minimum == that._minimum
end

function LongArgumentType.__tostring(self: LongArgumentType): string
	if self._minimum == MIN_VALUE and self._maximum == MAX_VALUE then
		return "longArg()"
	elseif self._maximum == MAX_VALUE then
		return "longArg(" .. JavaFormat.integer(self._minimum) .. ")"
	else
		return "longArg(" .. JavaFormat.integer(self._minimum) .. ", " .. JavaFormat.integer(self._maximum) .. ")"
	end
end

function LongArgumentType.getExamples(_self: LongArgumentType): { string }
	return EXAMPLES
end

return LongArgumentType
