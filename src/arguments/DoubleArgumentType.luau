--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local CommandSyntaxException = require("../exceptions/CommandSyntaxException")
local JavaFormat = require("../util/JavaFormat")

type DoubleArgumentType = Types.DoubleArgumentType & {
	_minimum: number,
	_maximum: number,
}

local EXAMPLES = { "0", "1.2", ".5", "-1", "-.5", "-1234.56" }

local MIN_VALUE = -1.7976931348623157e308
local MAX_VALUE = 1.7976931348623157e308

local DoubleArgumentType = {}
DoubleArgumentType.__index = DoubleArgumentType

function DoubleArgumentType.doubleArg(min: number?, max: number?): Types.DoubleArgumentType
	local self: DoubleArgumentType = setmetatable({
		_minimum = min or MIN_VALUE,
		_maximum = max or MAX_VALUE,
	}, DoubleArgumentType) :: any
	return self
end

function DoubleArgumentType.isInstance(value: unknown): boolean
	return Class.isInstance(value, DoubleArgumentType)
end

function DoubleArgumentType.getDouble(context: Types.CommandContext<any>, name: string): number
	return context:getArgument(name, "number")
end

function DoubleArgumentType.getMinimum(self: DoubleArgumentType): number
	return self._minimum
end

function DoubleArgumentType.getMaximum(self: DoubleArgumentType): number
	return self._maximum
end

function DoubleArgumentType.parse(self: DoubleArgumentType, reader: Types.StringReader, _source: any?): number
	local start = reader:getCursor()
	local result = reader:readDouble()
	if result < self._minimum then
		reader:setCursor(start)
		error(
			CommandSyntaxException.BUILT_IN_EXCEPTIONS:doubleTooLow():createWithContext(reader, result, self._minimum)
		)
	end
	if result > self._maximum then
		reader:setCursor(start)
		error(
			CommandSyntaxException.BUILT_IN_EXCEPTIONS:doubleTooHigh():createWithContext(reader, result, self._maximum)
		)
	end
	return result
end

function DoubleArgumentType.equals(self: DoubleArgumentType, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not DoubleArgumentType.isInstance(other) then
		return false
	end

	local that = other :: DoubleArgumentType
	return self._maximum == that._maximum and self._minimum == that._minimum
end

function DoubleArgumentType.__tostring(self: DoubleArgumentType): string
	if self._minimum == MIN_VALUE and self._maximum == MAX_VALUE then
		return "double()"
	elseif self._maximum == MAX_VALUE then
		return "double(" .. JavaFormat.double(self._minimum) .. ")"
	else
		return "double(" .. JavaFormat.double(self._minimum) .. ", " .. JavaFormat.double(self._maximum) .. ")"
	end
end

function DoubleArgumentType.getExamples(_self: DoubleArgumentType): { string }
	return EXAMPLES
end

return DoubleArgumentType
