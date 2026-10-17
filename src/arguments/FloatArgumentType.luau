--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local CommandSyntaxException = require("../exceptions/CommandSyntaxException")
local JavaFormat = require("../util/JavaFormat")

type FloatArgumentType = Types.FloatArgumentType & {
	_minimum: number,
	_maximum: number,
}

local EXAMPLES = { "0", "1.2", ".5", "-1", "-.5", "-1234.56" }

local MIN_VALUE = -3.4028234663852886e38
local MAX_VALUE = 3.4028234663852886e38

local FloatArgumentType = {}
FloatArgumentType.__index = FloatArgumentType

function FloatArgumentType.floatArg(min: number?, max: number?): Types.FloatArgumentType
	local self: FloatArgumentType = setmetatable({
		-- The parameters are floats in Java, so the bounds are rounded to single precision.
		_minimum = JavaFormat.toFloat(min or MIN_VALUE),
		_maximum = JavaFormat.toFloat(max or MAX_VALUE),
	}, FloatArgumentType) :: any
	return self
end

function FloatArgumentType.isInstance(value: unknown): boolean
	return Class.isInstance(value, FloatArgumentType)
end

function FloatArgumentType.getFloat(context: Types.CommandContext<any>, name: string): number
	return context:getArgument(name, "number")
end

function FloatArgumentType.getMinimum(self: FloatArgumentType): number
	return self._minimum
end

function FloatArgumentType.getMaximum(self: FloatArgumentType): number
	return self._maximum
end

function FloatArgumentType.parse(self: FloatArgumentType, reader: Types.StringReader, _source: any?): number
	local start = reader:getCursor()
	local result = reader:readFloat()
	if result < self._minimum then
		reader:setCursor(start)
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:floatTooLow():createWithContext(reader, result, self._minimum))
	end
	if result > self._maximum then
		reader:setCursor(start)
		error(
			CommandSyntaxException.BUILT_IN_EXCEPTIONS:floatTooHigh():createWithContext(reader, result, self._maximum)
		)
	end
	return result
end

function FloatArgumentType.equals(self: FloatArgumentType, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not FloatArgumentType.isInstance(other) then
		return false
	end

	local that = other :: FloatArgumentType
	return self._maximum == that._maximum and self._minimum == that._minimum
end

function FloatArgumentType.__tostring(self: FloatArgumentType): string
	if self._minimum == MIN_VALUE and self._maximum == MAX_VALUE then
		return "float()"
	elseif self._maximum == MAX_VALUE then
		return "float(" .. JavaFormat.float(self._minimum) .. ")"
	else
		return "float(" .. JavaFormat.float(self._minimum) .. ", " .. JavaFormat.float(self._maximum) .. ")"
	end
end

function FloatArgumentType.getExamples(_self: FloatArgumentType): { string }
	return EXAMPLES
end

return FloatArgumentType
