--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local JavaString = require("../util/JavaString")

type StringRange = Types.StringRange & { _start: number, _end: number }

local StringRange = {}
StringRange.__index = StringRange

function StringRange.new(start: number, finish: number): Types.StringRange
	local self: StringRange = setmetatable({ _start = start, _end = finish }, StringRange) :: any
	return self
end

function StringRange.isInstance(value: unknown): boolean
	return Class.isInstance(value, StringRange)
end

function StringRange.at(pos: number): Types.StringRange
	return StringRange.new(pos, pos)
end

function StringRange.between(start: number, finish: number): Types.StringRange
	return StringRange.new(start, finish)
end

function StringRange.encompassing(a: Types.StringRange, b: Types.StringRange): Types.StringRange
	return StringRange.new(math.min(a:getStart(), b:getStart()), math.max(a:getEnd(), b:getEnd()))
end

function StringRange.getStart(self: StringRange): number
	return self._start
end

function StringRange.getEnd(self: StringRange): number
	return self._end
end

function StringRange.get(self: StringRange, readerOrString: Types.ImmutableStringReader | string): string
	local text = if type(readerOrString) == "string" then readerOrString else readerOrString:getString()
	return JavaString.substring(text, self._start, self._end)
end

function StringRange.isEmpty(self: StringRange): boolean
	return self._start == self._end
end

function StringRange.getLength(self: StringRange): number
	return self._end - self._start
end

function StringRange.equals(self: StringRange, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not StringRange.isInstance(other) then
		return false
	end
	local that = other :: StringRange
	return self._start == that._start and self._end == that._end
end

function StringRange.__tostring(self: StringRange): string
	return `StringRange\{start={self._start}, end={self._end}}`
end

return StringRange
