--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local JavaString = require("../util/JavaString")

type BoolArgumentType = Types.BoolArgumentType

local EXAMPLES = { "true", "false" }

local BoolArgumentType = {}
BoolArgumentType.__index = BoolArgumentType

function BoolArgumentType.bool(): Types.BoolArgumentType
	return setmetatable({}, BoolArgumentType) :: any
end

function BoolArgumentType.isInstance(value: unknown): boolean
	return Class.isInstance(value, BoolArgumentType)
end

function BoolArgumentType.getBool(context: Types.CommandContext<any>, name: string): boolean
	return context:getArgument(name, "boolean")
end

function BoolArgumentType.parse(_self: BoolArgumentType, reader: Types.StringReader, _source: any?): boolean
	return reader:readBoolean()
end

function BoolArgumentType.listSuggestions(
	_self: BoolArgumentType,
	_context: Types.CommandContext<any>,
	builder: Types.SuggestionsBuilder
): Types.CompletableFuture<Types.Suggestions>
	if JavaString.startsWith("true", builder:getRemainingLowerCase()) then
		builder:suggest("true")
	end
	if JavaString.startsWith("false", builder:getRemainingLowerCase()) then
		builder:suggest("false")
	end
	return builder:buildFuture()
end

function BoolArgumentType.getExamples(_self: BoolArgumentType): { string }
	return EXAMPLES
end

return BoolArgumentType
