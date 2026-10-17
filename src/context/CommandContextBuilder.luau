--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local CommandContext = require("./CommandContext")
local ParsedCommandNode = require("./ParsedCommandNode")
local RuntimeException = require("../util/RuntimeException")
local StringRange = require("./StringRange")
local SuggestionContext = require("./SuggestionContext")

-- The source type. The public types in Types.luau keep it generic; the implementation uses `any`,
-- which keeps the new solver from giving up on these mutually recursive types.
type S = any

type CommandContextBuilder = Types.CommandContextBuilder<S> & {
	_arguments: { [string]: Types.ParsedArgument<S, any> },
	_rootNode: Types.CommandNode<S>,
	_nodes: { Types.ParsedCommandNode<S> },
	_dispatcher: Types.CommandDispatcher<S>,
	_source: S,
	_command: Types.Command<S>?,
	_child: Types.CommandContextBuilder<S>?,
	_range: Types.StringRange,
	_modifier: Types.RedirectModifier<S>?,
	_forks: boolean,
}

local CommandContextBuilder = {}
CommandContextBuilder.__index = CommandContextBuilder

function CommandContextBuilder.new(
	dispatcher: Types.CommandDispatcher<S>,
	source: S,
	rootNode: Types.CommandNode<S>,
	start: number
): Types.CommandContextBuilder<S>
	local self: CommandContextBuilder = setmetatable({
		_arguments = {},
		_rootNode = rootNode,
		_nodes = {},
		_dispatcher = dispatcher,
		_source = source,
		_command = nil,
		_child = nil,
		_range = StringRange.at(start),
		_modifier = nil,
		_forks = false,
	}, CommandContextBuilder) :: any
	return self
end

function CommandContextBuilder.isInstance(value: unknown): boolean
	return Class.isInstance(value, CommandContextBuilder)
end

function CommandContextBuilder.withSource(self: CommandContextBuilder, source: S): Types.CommandContextBuilder<S>
	self._source = source
	return self
end

function CommandContextBuilder.getSource(self: CommandContextBuilder): S
	return self._source
end

function CommandContextBuilder.getRootNode(self: CommandContextBuilder): Types.CommandNode<S>
	return self._rootNode
end

function CommandContextBuilder.withArgument(
	self: CommandContextBuilder,
	name: string,
	argument: Types.ParsedArgument<S, any>
): Types.CommandContextBuilder<S>
	self._arguments[name] = argument
	return self
end

function CommandContextBuilder.getArguments(self: CommandContextBuilder): { [string]: Types.ParsedArgument<S, any> }
	return self._arguments
end

function CommandContextBuilder.withCommand(
	self: CommandContextBuilder,
	command: Types.Command<S>?
): Types.CommandContextBuilder<S>
	self._command = command
	return self
end

function CommandContextBuilder.withNode(
	self: CommandContextBuilder,
	node: Types.CommandNode<S>,
	range: Types.StringRange
): Types.CommandContextBuilder<S>
	table.insert(self._nodes, ParsedCommandNode.new(node, range))
	self._range = StringRange.encompassing(self._range, range)
	self._modifier = node:getRedirectModifier()
	self._forks = node:isFork()
	return self
end

-- Java's copy() leaves the modifier at its initial null; the port does the same.
function CommandContextBuilder.copy(self: CommandContextBuilder): Types.CommandContextBuilder<S>
	local copy =
		CommandContextBuilder.new(self._dispatcher, self._source, self._rootNode, self._range:getStart()) :: CommandContextBuilder
	copy._command = self._command
	for name, argument in self._arguments do
		copy._arguments[name] = argument
	end
	table.move(self._nodes, 1, #self._nodes, 1, copy._nodes)
	copy._child = self._child
	copy._range = self._range
	copy._forks = self._forks
	return copy
end

function CommandContextBuilder.withChild(
	self: CommandContextBuilder,
	child: Types.CommandContextBuilder<S>
): Types.CommandContextBuilder<S>
	self._child = child
	return self
end

function CommandContextBuilder.getChild(self: CommandContextBuilder): Types.CommandContextBuilder<S>?
	return self._child
end

function CommandContextBuilder.getLastChild(self: CommandContextBuilder): Types.CommandContextBuilder<S>
	local result: Types.CommandContextBuilder<S> = self
	while true do
		local child = result:getChild()
		if child == nil then
			return result
		end
		result = child
	end
end

function CommandContextBuilder.getCommand(self: CommandContextBuilder): Types.Command<S>?
	return self._command
end

function CommandContextBuilder.getNodes(self: CommandContextBuilder): { Types.ParsedCommandNode<S> }
	return self._nodes
end

function CommandContextBuilder.build(self: CommandContextBuilder, input: string): Types.CommandContext<S>
	local child = self._child
	return CommandContext.new(
		self._source,
		input,
		self._arguments,
		self._command,
		self._rootNode,
		self._nodes,
		self._range,
		if child == nil then nil else child:build(input),
		self._modifier,
		self._forks
	)
end

function CommandContextBuilder.getDispatcher(self: CommandContextBuilder): Types.CommandDispatcher<S>
	return self._dispatcher
end

function CommandContextBuilder.getRange(self: CommandContextBuilder): Types.StringRange
	return self._range
end

function CommandContextBuilder.findSuggestionContext(
	self: CommandContextBuilder,
	cursor: number
): Types.SuggestionContext<S>
	if self._range:getStart() <= cursor then
		if self._range:getEnd() < cursor then
			local child = self._child
			if child ~= nil then
				return child:findSuggestionContext(cursor)
			elseif #self._nodes > 0 then
				local last = self._nodes[#self._nodes]
				return SuggestionContext.new(self, last:getNode(), last:getRange():getEnd() + 1)
			else
				return SuggestionContext.new(self, self._rootNode, self._range:getStart())
			end
		else
			local prev: Types.CommandNode<S>? = self._rootNode
			for _, node in self._nodes do
				local nodeRange = node:getRange()
				if nodeRange:getStart() <= cursor and cursor <= nodeRange:getEnd() then
					return SuggestionContext.new(self, prev :: Types.CommandNode<S>, nodeRange:getStart())
				end
				prev = node:getNode()
			end
			if prev == nil then
				error(RuntimeException.IllegalStateException.new("Can't find node before cursor"))
			end
			return SuggestionContext.new(self, prev, self._range:getStart())
		end
	end
	error(RuntimeException.IllegalStateException.new("Can't find node before cursor"))
end

return CommandContextBuilder
