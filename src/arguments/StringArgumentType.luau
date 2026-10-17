--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local StringReader = require("../StringReader")

type StringArgumentType = Types.StringArgumentType & {
	_type: Types.StringType,
}

-- The StringType enum: each constant has its name and examples.
local function stringType(name: string, examples: { string }): Types.StringType
	return table.freeze(setmetatable({
		name = function()
			return name
		end,
		getExamples = function()
			return examples
		end,
	}, {
		__tostring = function()
			return name
		end,
	})) :: any
end

local StringType = table.freeze({
	SINGLE_WORD = stringType("SINGLE_WORD", { "word", "words_with_underscores" }),
	QUOTABLE_PHRASE = stringType("QUOTABLE_PHRASE", { '"quoted phrase"', "word", '""' }),
	GREEDY_PHRASE = stringType("GREEDY_PHRASE", { "word", "words with spaces", '"and symbols"' }),
})

local StringArgumentType = {}
StringArgumentType.__index = StringArgumentType
StringArgumentType.StringType = StringType

local function new(stringTypeValue: Types.StringType): Types.StringArgumentType
	local self: StringArgumentType = setmetatable({ _type = stringTypeValue }, StringArgumentType) :: any
	return self
end

function StringArgumentType.isInstance(value: unknown): boolean
	return Class.isInstance(value, StringArgumentType)
end

function StringArgumentType.word(): Types.StringArgumentType
	return new(StringType.SINGLE_WORD)
end

function StringArgumentType.string(): Types.StringArgumentType
	return new(StringType.QUOTABLE_PHRASE)
end

function StringArgumentType.greedyString(): Types.StringArgumentType
	return new(StringType.GREEDY_PHRASE)
end

function StringArgumentType.getString(context: Types.CommandContext<any>, name: string): string
	return context:getArgument(name, "string")
end

function StringArgumentType.getType(self: StringArgumentType): Types.StringType
	return self._type
end

function StringArgumentType.parse(self: StringArgumentType, reader: Types.StringReader, _source: any?): string
	if self._type == StringType.GREEDY_PHRASE then
		local text = reader:getRemaining()
		reader:setCursor(reader:getTotalLength())
		return text
	elseif self._type == StringType.SINGLE_WORD then
		return reader:readUnquotedString()
	else
		return reader:readString()
	end
end

function StringArgumentType.__tostring(_self: StringArgumentType): string
	return "string()"
end

function StringArgumentType.getExamples(self: StringArgumentType): { string }
	return self._type:getExamples()
end

local function escape(input: string): string
	local result = { '"' }

	for index = 1, #input do
		local c = string.sub(input, index, index)
		if c == "\\" or c == '"' then
			table.insert(result, "\\")
		end
		table.insert(result, c)
	end

	table.insert(result, '"')
	return table.concat(result)
end

function StringArgumentType.escapeIfRequired(input: string): string
	for index = 1, #input do
		if not StringReader.isAllowedInUnquotedString(string.sub(input, index, index)) then
			return escape(input)
		end
	end
	return input
end

return StringArgumentType
