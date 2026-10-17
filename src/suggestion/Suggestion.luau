--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local JavaString = require("../util/JavaString")
local Objects = require("../util/Objects")
local Sort = require("../util/Sort")

type Suggestion = Types.Suggestion & {
	_range: Types.StringRange,
	_text: string,
	_tooltip: Types.Message?,
}

local Suggestion = {}
Suggestion.__index = Suggestion

-- Sets the fields of a new Suggestion or subclass instance, as Java's constructor does for super().
function Suggestion.init(self: any, range: Types.StringRange, text: string, tooltip: Types.Message?)
	self._range = range
	self._text = text
	self._tooltip = tooltip
end

function Suggestion.new(range: Types.StringRange, text: string, tooltip: Types.Message?): Types.Suggestion
	local self: Suggestion = setmetatable({}, Suggestion) :: any
	Suggestion.init(self, range, text, tooltip)
	return self
end

function Suggestion.isInstance(value: unknown): boolean
	return Class.isInstance(value, Suggestion)
end

function Suggestion.getRange(self: Suggestion): Types.StringRange
	return self._range
end

function Suggestion.getText(self: Suggestion): string
	return self._text
end

function Suggestion.getTooltip(self: Suggestion): Types.Message?
	return self._tooltip
end

function Suggestion.apply(self: Suggestion, input: string): string
	if self._range:getStart() == 0 and self._range:getEnd() == #input then
		return self._text
	end
	local result = ""
	if self._range:getStart() > 0 then
		result ..= JavaString.substring(input, 0, self._range:getStart())
	end
	result ..= self._text
	if self._range:getEnd() < #input then
		result ..= JavaString.substring(input, self._range:getEnd())
	end
	return result
end

function Suggestion.equals(self: Suggestion, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not Suggestion.isInstance(other) then
		return false
	end
	local that = other :: Suggestion
	return Objects.equals(self._range, that._range)
		and Objects.equals(self._text, that._text)
		and Objects.equals(self._tooltip, that._tooltip)
end

local function describeTooltip(tooltip: Types.Message?): string
	return if tooltip == nil then "null" else tostring(tooltip)
end

function Suggestion.__tostring(self: Suggestion): string
	return "Suggestion{range="
		.. tostring(self._range)
		.. ", text='"
		.. self._text
		.. "', tooltip='"
		.. describeTooltip(self._tooltip)
		.. "'}"
end

function Suggestion.compareTo(self: Suggestion, other: Types.Suggestion): number
	return Sort.compareStrings(self._text, other:getText())
end

function Suggestion.compareToIgnoreCase(self: Suggestion, other: Types.Suggestion): number
	return Sort.compareStrings(string.lower(self._text), string.lower(other:getText()))
end

function Suggestion.expand(self: Suggestion, command: string, range: Types.StringRange): Types.Suggestion
	if range:equals(self._range) then
		return self
	end
	local result = ""
	if range:getStart() < self._range:getStart() then
		result ..= JavaString.substring(command, range:getStart(), self._range:getStart())
	end
	result ..= self._text
	if range:getEnd() > self._range:getEnd() then
		result ..= JavaString.substring(command, self._range:getEnd(), range:getEnd())
	end
	return Suggestion.new(range, result, self._tooltip)
end

Suggestion.describeTooltip = describeTooltip

return Suggestion
