--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local JavaFormat = require("../util/JavaFormat")
local Suggestion = require("./Suggestion")

type IntegerSuggestion = Types.IntegerSuggestion & {
	_range: Types.StringRange,
	_text: string,
	_tooltip: Types.Message?,
	_value: number,
}

local IntegerSuggestion = {}
IntegerSuggestion.__index = IntegerSuggestion
Class.extend(IntegerSuggestion, Suggestion)

function IntegerSuggestion.new(
	range: Types.StringRange,
	value: number,
	tooltip: Types.Message?
): Types.IntegerSuggestion
	local self: IntegerSuggestion = setmetatable({}, IntegerSuggestion) :: any
	Suggestion.init(self, range, JavaFormat.integer(value), tooltip)
	self._value = value
	return self
end

function IntegerSuggestion.isInstance(value: unknown): boolean
	return Class.isInstance(value, IntegerSuggestion)
end

function IntegerSuggestion.getValue(self: IntegerSuggestion): number
	return self._value
end

function IntegerSuggestion.equals(self: IntegerSuggestion, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not IntegerSuggestion.isInstance(other) then
		return false
	end
	local that = other :: IntegerSuggestion
	return self._value == that._value and Suggestion.equals(self :: any, other)
end

function IntegerSuggestion.__tostring(self: IntegerSuggestion): string
	return "IntegerSuggestion{value="
		.. JavaFormat.integer(self._value)
		.. ", range="
		.. tostring(self._range)
		.. ", text='"
		.. self._text
		.. "', tooltip='"
		.. Suggestion.describeTooltip(self._tooltip)
		.. "'}"
end

function IntegerSuggestion.compareTo(self: IntegerSuggestion, other: Types.Suggestion): number
	if IntegerSuggestion.isInstance(other) then
		local value = (other :: IntegerSuggestion)._value
		return if self._value < value then -1 elseif self._value == value then 0 else 1
	end
	return Suggestion.compareTo(self :: any, other)
end

function IntegerSuggestion.compareToIgnoreCase(self: IntegerSuggestion, other: Types.Suggestion): number
	return self:compareTo(other)
end

return IntegerSuggestion
