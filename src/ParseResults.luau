--!strict

local Types = require("./Types")
local Class = require("./util/Class")
local StringReader = require("./StringReader")

-- The source type. The public types in Types.luau keep it generic; the implementation uses `any`,
-- which keeps the new solver from giving up on these mutually recursive types.
type S = any

type ParseResults = Types.ParseResults<S> & {
	_context: Types.CommandContextBuilder<S>,
	_exceptions: { [Types.CommandNode<S>]: Types.CommandSyntaxException },
	_reader: Types.ImmutableStringReader,
}

local ParseResults = {}
ParseResults.__index = ParseResults

function ParseResults.new(
	context: Types.CommandContextBuilder<S>,
	reader: Types.ImmutableStringReader?,
	exceptions: { [Types.CommandNode<S>]: Types.CommandSyntaxException }?
): Types.ParseResults<S>
	local self: ParseResults = setmetatable({
		_context = context,
		_reader = reader or StringReader.new(""),
		_exceptions = exceptions or {},
	}, ParseResults) :: any
	return self
end

function ParseResults.isInstance(value: unknown): boolean
	return Class.isInstance(value, ParseResults)
end

function ParseResults.getContext(self: ParseResults): Types.CommandContextBuilder<S>
	return self._context
end

function ParseResults.getReader(self: ParseResults): Types.ImmutableStringReader
	return self._reader
end

function ParseResults.getExceptions(self: ParseResults): { [Types.CommandNode<S>]: Types.CommandSyntaxException }
	return self._exceptions
end

return ParseResults
