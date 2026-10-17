--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local CompletableFuture = require("../util/CompletableFuture")
local IntegerSuggestion = require("./IntegerSuggestion")
local JavaString = require("../util/JavaString")
local StringRange = require("../context/StringRange")
local Suggestion = require("./Suggestion")
local Suggestions = require("./Suggestions")

type SuggestionsBuilder = Types.SuggestionsBuilder & {
	_input: string,
	_inputLowerCase: string,
	_start: number,
	_remaining: string,
	_remainingLowerCase: string,
	_result: { Types.Suggestion },
}

local SuggestionsBuilder = {}
SuggestionsBuilder.__index = SuggestionsBuilder

function SuggestionsBuilder.new(
	input: string,
	inputLowerCaseOrStart: string | number,
	start: number?
): Types.SuggestionsBuilder
	local inputLowerCase: string, startPos: number
	if type(inputLowerCaseOrStart) == "number" then
		inputLowerCase, startPos = JavaString.toLowerCase(input), inputLowerCaseOrStart
	else
		assert(start ~= nil, "SuggestionsBuilder.new(input, inputLowerCase, start) needs a start")
		inputLowerCase, startPos = inputLowerCaseOrStart, start
	end
	local self: SuggestionsBuilder = setmetatable({
		_input = input,
		_inputLowerCase = inputLowerCase,
		_start = startPos,
		_remaining = JavaString.substring(input, startPos),
		_remainingLowerCase = JavaString.substring(inputLowerCase, startPos),
		_result = {},
	}, SuggestionsBuilder) :: any
	return self
end

function SuggestionsBuilder.isInstance(value: unknown): boolean
	return Class.isInstance(value, SuggestionsBuilder)
end

function SuggestionsBuilder.getInput(self: SuggestionsBuilder): string
	return self._input
end

function SuggestionsBuilder.getStart(self: SuggestionsBuilder): number
	return self._start
end

function SuggestionsBuilder.getRemaining(self: SuggestionsBuilder): string
	return self._remaining
end

function SuggestionsBuilder.getRemainingLowerCase(self: SuggestionsBuilder): string
	return self._remainingLowerCase
end

function SuggestionsBuilder.build(self: SuggestionsBuilder): Types.Suggestions
	return Suggestions.create(self._input, self._result)
end

function SuggestionsBuilder.buildFuture(self: SuggestionsBuilder): Types.CompletableFuture<Types.Suggestions>
	return CompletableFuture.completedFuture(self:build())
end

function SuggestionsBuilder.suggest(
	self: SuggestionsBuilder,
	textOrValue: string | number,
	tooltip: Types.Message?
): Types.SuggestionsBuilder
	local range = StringRange.between(self._start, #self._input)
	if type(textOrValue) == "number" then
		table.insert(self._result, IntegerSuggestion.new(range, textOrValue, tooltip))
		return self
	end
	if textOrValue == self._remaining then
		return self
	end
	table.insert(self._result, Suggestion.new(range, textOrValue, tooltip))
	return self
end

function SuggestionsBuilder.add(self: SuggestionsBuilder, other: Types.SuggestionsBuilder): Types.SuggestionsBuilder
	for _, suggestion in (other :: SuggestionsBuilder)._result do
		table.insert(self._result, suggestion)
	end
	return self
end

function SuggestionsBuilder.createOffset(self: SuggestionsBuilder, start: number): Types.SuggestionsBuilder
	return SuggestionsBuilder.new(self._input, self._inputLowerCase, start)
end

function SuggestionsBuilder.restart(self: SuggestionsBuilder): Types.SuggestionsBuilder
	return self:createOffset(self._start)
end

return SuggestionsBuilder
