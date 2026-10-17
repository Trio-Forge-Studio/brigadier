--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local CompletableFuture = require("../util/CompletableFuture")
local Objects = require("../util/Objects")
local Sort = require("../util/Sort")
local StringRange = require("../context/StringRange")

type Suggestions = Types.Suggestions & {
	_range: Types.StringRange,
	_suggestions: { Types.Suggestion },
}

local Suggestions = {}
Suggestions.__index = Suggestions

function Suggestions.new(range: Types.StringRange, suggestions: { Types.Suggestion }): Types.Suggestions
	local self: Suggestions = setmetatable({ _range = range, _suggestions = suggestions }, Suggestions) :: any
	return self
end

local EMPTY = Suggestions.new(StringRange.at(0), {})

function Suggestions.isInstance(value: unknown): boolean
	return Class.isInstance(value, Suggestions)
end

function Suggestions.getRange(self: Suggestions): Types.StringRange
	return self._range
end

function Suggestions.getList(self: Suggestions): { Types.Suggestion }
	return self._suggestions
end

function Suggestions.isEmpty(self: Suggestions): boolean
	return #self._suggestions == 0
end

function Suggestions.equals(self: Suggestions, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not Suggestions.isInstance(other) then
		return false
	end
	local that = other :: Suggestions
	return Objects.equals(self._range, that._range) and Objects.equals(self._suggestions, that._suggestions)
end

function Suggestions.__tostring(self: Suggestions): string
	local parts = {}
	for _, suggestion in self._suggestions do
		table.insert(parts, tostring(suggestion))
	end
	return "Suggestions{range=" .. tostring(self._range) .. ", suggestions=[" .. table.concat(parts, ", ") .. "]}"
end

function Suggestions.empty(): Types.CompletableFuture<Types.Suggestions>
	return CompletableFuture.completedFuture(EMPTY)
end

-- Adds to a HashSet<Suggestion>: keeps the first of each group of equal suggestions. Java finds
-- duplicates by hashCode and then equals. Equal suggestions share their range and text, and a
-- Suggestion and an IntegerSuggestion never share a hash code, so range, text and class key the
-- buckets that `equals` searches.
type Buckets = { [any]: { [string]: { Types.Suggestion } } }

local function addToSet(set: { Types.Suggestion }, buckets: Buckets, suggestion: Types.Suggestion)
	local class = getmetatable(suggestion :: any)
	local byKey = buckets[class]
	if byKey == nil then
		byKey = {}
		buckets[class] = byKey
	end
	local range = suggestion:getRange()
	local key = `{range:getStart()}:{range:getEnd()}:{suggestion:getText()}`
	local bucket = byKey[key]
	if bucket == nil then
		bucket = {}
		byKey[key] = bucket
	end
	for _, existing in bucket do
		if existing:equals(suggestion) then
			return
		end
	end
	table.insert(bucket, suggestion)
	table.insert(set, suggestion)
end

function Suggestions.merge(command: string, input: { Types.Suggestions }): Types.Suggestions
	if #input == 0 then
		return EMPTY
	elseif #input == 1 then
		return input[1]
	end

	local texts = {}
	local buckets: Buckets = {}
	for _, suggestions in input do
		for _, suggestion in suggestions:getList() do
			addToSet(texts, buckets, suggestion)
		end
	end
	return Suggestions.create(command, texts)
end

function Suggestions.create(command: string, suggestions: { Types.Suggestion }): Types.Suggestions
	if #suggestions == 0 then
		return EMPTY
	end
	local start = math.huge
	local finish = -math.huge
	for _, suggestion in suggestions do
		start = math.min(suggestion:getRange():getStart(), start)
		finish = math.max(suggestion:getRange():getEnd(), finish)
	end
	local range = StringRange.new(start, finish)
	local texts = {}
	local buckets: Buckets = {}
	for _, suggestion in suggestions do
		addToSet(texts, buckets, suggestion:expand(command, range))
	end
	Sort.sort(texts, function(a, b)
		return a:compareToIgnoreCase(b)
	end)
	return Suggestions.new(range, texts)
end

return Suggestions
