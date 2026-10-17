--!strict

local Types = require("./Types")
local Class = require("./util/Class")
local CommandContextBuilder = require("./context/CommandContextBuilder")
local CommandSyntaxException = require("./exceptions/CommandSyntaxException")
local CompletableFuture = require("./util/CompletableFuture")
local ContextChain = require("./context/ContextChain")
local JavaString = require("./util/JavaString")
local ParseResults = require("./ParseResults")
local RootCommandNode = require("./tree/RootCommandNode")
local Sort = require("./util/Sort")
local StringReader = require("./StringReader")
local Suggestions = require("./suggestion/Suggestions")
local SuggestionsBuilder = require("./suggestion/SuggestionsBuilder")

-- The source type. The public types in Types.luau keep it generic; the implementation uses `any`,
-- which keeps the new solver from giving up on these mutually recursive types.
type S = any

type CommandNode = Types.CommandNode<S>
type CommandDispatcher = Types.CommandDispatcher<S> & {
	_root: Types.RootCommandNode<S>,
	_consumer: Types.ResultConsumer<S>,
}

local ARGUMENT_SEPARATOR = " "
local ARGUMENT_SEPARATOR_CHAR = " "

local USAGE_OPTIONAL_OPEN = "["
local USAGE_OPTIONAL_CLOSE = "]"
local USAGE_REQUIRED_OPEN = "("
local USAGE_REQUIRED_CLOSE = ")"
local USAGE_OR = "|"

local CommandDispatcher = {}
CommandDispatcher.__index = CommandDispatcher
CommandDispatcher.ARGUMENT_SEPARATOR = ARGUMENT_SEPARATOR
CommandDispatcher.ARGUMENT_SEPARATOR_CHAR = ARGUMENT_SEPARATOR_CHAR

local function ignoreResult() end

function CommandDispatcher.new(root: Types.RootCommandNode<S>?): Types.CommandDispatcher<S>
	local self: CommandDispatcher = setmetatable({
		_root = root or RootCommandNode.new(),
		_consumer = ignoreResult,
	}, CommandDispatcher) :: any
	return self
end

function CommandDispatcher.isInstance(value: unknown): boolean
	return Class.isInstance(value, CommandDispatcher)
end

function CommandDispatcher.register(
	self: CommandDispatcher,
	command: Types.LiteralArgumentBuilder<S>
): Types.LiteralCommandNode<S>
	local build = command:build()
	self._root:addChild(build)
	return build
end

function CommandDispatcher.setConsumer(self: CommandDispatcher, consumer: Types.ResultConsumer<S>)
	self._consumer = consumer
end

local function executeParse(self: CommandDispatcher, parse: Types.ParseResults<S>): number
	if parse:getReader():canRead() then
		local exceptions = parse:getExceptions()
		local first, exception = next(exceptions)
		if first ~= nil and next(exceptions, first) == nil then
			error(exception)
		elseif parse:getContext():getRange():isEmpty() then
			error(
				CommandSyntaxException.BUILT_IN_EXCEPTIONS
					:dispatcherUnknownCommand()
					:createWithContext(parse:getReader())
			)
		else
			error(
				CommandSyntaxException.BUILT_IN_EXCEPTIONS
					:dispatcherUnknownArgument()
					:createWithContext(parse:getReader())
			)
		end
	end

	local command = parse:getReader():getString()
	local original = parse:getContext():build(command)

	local flatContext = ContextChain.tryFlatten(original)
	if flatContext == nil then
		self._consumer(original, false, 0)
		error(
			CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand():createWithContext(parse:getReader())
		)
	end

	return flatContext:executeAll(original:getSource(), self._consumer)
end

-- execute(String, S), execute(StringReader, S) and execute(ParseResults).
function CommandDispatcher.execute(
	self: CommandDispatcher,
	input: string | Types.StringReader | Types.ParseResults<S>,
	source: S?
): number
	if ParseResults.isInstance(input) then
		return executeParse(self, input :: Types.ParseResults<S>)
	end
	local reader = if type(input) == "string" then StringReader.new(input) else input :: Types.StringReader
	local parse = self:parse(reader, source :: S)
	return executeParse(self, parse)
end

local parseNodes

function CommandDispatcher.parse(
	self: CommandDispatcher,
	command: string | Types.StringReader,
	source: S
): Types.ParseResults<S>
	local reader = if type(command) == "string" then StringReader.new(command) else command
	local context = CommandContextBuilder.new(self, source, self._root, reader:getCursor())
	return parseNodes(self, self._root, reader, context)
end

-- The message of an error that isn't a CommandSyntaxException, as Java's RuntimeException.getMessage.
local function messageOf(err: unknown): string?
	if type(err) == "table" and type((err :: any).getMessage) == "function" then
		return (err :: any):getMessage()
	end
	return tostring(err)
end

local function compareParses(a: Types.ParseResults<S>, b: Types.ParseResults<S>): number
	if not a:getReader():canRead() and b:getReader():canRead() then
		return -1
	end
	if a:getReader():canRead() and not b:getReader():canRead() then
		return 1
	end
	if next(a:getExceptions()) == nil and next(b:getExceptions()) ~= nil then
		return -1
	end
	if next(a:getExceptions()) ~= nil and next(b:getExceptions()) == nil then
		return 1
	end
	return 0
end

function parseNodes(
	self: CommandDispatcher,
	node: CommandNode,
	originalReader: Types.StringReader,
	contextSoFar: Types.CommandContextBuilder<S>
): Types.ParseResults<S>
	local source = contextSoFar:getSource()
	local errors: { [CommandNode]: Types.CommandSyntaxException }? = nil
	local potentials: { Types.ParseResults<S> }? = nil
	local cursor = originalReader:getCursor()

	for _, child in node:getRelevantNodes(originalReader) do
		if not child:canUse(source) then
			continue
		end
		local context = contextSoFar:copy()
		local reader = StringReader.new(originalReader)
		-- Java throws these exceptions and catches them right away; the port records them directly.
		local exception: Types.CommandSyntaxException? = nil
		local parsed, parseError = pcall(child.parse, child, reader, context)
		if not parsed then
			if CommandSyntaxException.isInstance(parseError) then
				exception = parseError :: any
			else
				exception = CommandSyntaxException.BUILT_IN_EXCEPTIONS
					:dispatcherParseException()
					:createWithContext(reader, messageOf(parseError))
			end
		elseif reader:canRead() then
			if reader:peek() ~= ARGUMENT_SEPARATOR_CHAR then
				exception = CommandSyntaxException.BUILT_IN_EXCEPTIONS
					:dispatcherExpectedArgumentSeparator()
					:createWithContext(reader)
			end
		end
		if exception ~= nil then
			if errors == nil then
				errors = {}
			end
			(errors :: { [CommandNode]: Types.CommandSyntaxException })[child] = exception
			reader:setCursor(cursor)
			continue
		end

		context:withCommand(child:getCommand())
		local redirect = child:getRedirect()
		if reader:canRead(if redirect == nil then 2 else 1) then
			reader:skip()
			if redirect ~= nil then
				local childContext = CommandContextBuilder.new(self, source, redirect, reader:getCursor())
				local parse = parseNodes(self, redirect, reader, childContext)
				context:withChild(parse:getContext())
				return ParseResults.new(context, parse:getReader(), parse:getExceptions())
			else
				local parse = parseNodes(self, child, reader, context)
				if potentials == nil then
					potentials = {}
				end
				table.insert(potentials :: { Types.ParseResults<S> }, parse)
			end
		else
			if potentials == nil then
				potentials = {}
			end
			table.insert(potentials :: { Types.ParseResults<S> }, ParseResults.new(context, reader, {}))
		end
	end

	if potentials ~= nil then
		if #potentials > 1 then
			Sort.sort(potentials, compareParses)
		end
		return potentials[1]
	end

	return ParseResults.new(contextSoFar, originalReader, errors or {})
end

local getAllUsageRecursive

function CommandDispatcher.getAllUsage(
	self: CommandDispatcher,
	node: CommandNode,
	source: S,
	restricted: boolean
): { string }
	local result = {}
	getAllUsageRecursive(self, node, source, result, "", restricted)
	return result
end

function getAllUsageRecursive(
	self: CommandDispatcher,
	node: CommandNode,
	source: S,
	result: { string },
	prefix: string,
	restricted: boolean
)
	if restricted and not node:canUse(source) then
		return
	end

	if node:getCommand() ~= nil then
		table.insert(result, prefix)
	end

	local redirect = node:getRedirect()
	if redirect ~= nil then
		local redirectText = if rawequal(redirect, self._root) then "..." else "-> " .. redirect:getUsageText()
		table.insert(
			result,
			if prefix == ""
				then node:getUsageText() .. ARGUMENT_SEPARATOR .. redirectText
				else prefix .. ARGUMENT_SEPARATOR .. redirectText
		)
	elseif #node:getChildren() > 0 then
		for _, child in node:getChildren() do
			getAllUsageRecursive(
				self,
				child,
				source,
				result,
				if prefix == "" then child:getUsageText() else prefix .. ARGUMENT_SEPARATOR .. child:getUsageText(),
				restricted
			)
		end
	end
end

local getSmartUsageRecursive

function CommandDispatcher.getSmartUsage(
	self: CommandDispatcher,
	node: CommandNode,
	source: S
): { [CommandNode]: string }
	local result = {}

	local optional = node:getCommand() ~= nil
	for _, child in node:getChildren() do
		local usage = getSmartUsageRecursive(self, child, source, optional, false)
		if usage ~= nil then
			result[child] = usage
		end
	end
	return result
end

function getSmartUsageRecursive(
	self: CommandDispatcher,
	node: CommandNode,
	source: S,
	optional: boolean,
	deep: boolean
): string?
	if not node:canUse(source) then
		return nil
	end

	local selfUsage = if optional
		then USAGE_OPTIONAL_OPEN .. node:getUsageText() .. USAGE_OPTIONAL_CLOSE
		else node:getUsageText()
	local childOptional = node:getCommand() ~= nil
	local open = if childOptional then USAGE_OPTIONAL_OPEN else USAGE_REQUIRED_OPEN
	local close = if childOptional then USAGE_OPTIONAL_CLOSE else USAGE_REQUIRED_CLOSE

	if not deep then
		local redirect = node:getRedirect()
		if redirect ~= nil then
			local redirectText = if rawequal(redirect, self._root) then "..." else "-> " .. redirect:getUsageText()
			return selfUsage .. ARGUMENT_SEPARATOR .. redirectText
		else
			local children = {}
			for _, child in node:getChildren() do
				if child:canUse(source) then
					table.insert(children, child)
				end
			end
			if #children == 1 then
				local usage = getSmartUsageRecursive(self, children[1], source, childOptional, childOptional)
				if usage ~= nil then
					return selfUsage .. ARGUMENT_SEPARATOR .. usage
				end
			elseif #children > 1 then
				-- A LinkedHashSet<String>.
				local childUsage: { string } = {}
				for _, child in children do
					local usage = getSmartUsageRecursive(self, child, source, childOptional, true)
					if usage ~= nil and table.find(childUsage, usage) == nil then
						table.insert(childUsage, usage)
					end
				end
				if #childUsage == 1 then
					local usage = childUsage[1]
					return selfUsage
						.. ARGUMENT_SEPARATOR
						.. (if childOptional then USAGE_OPTIONAL_OPEN .. usage .. USAGE_OPTIONAL_CLOSE else usage)
				elseif #childUsage > 1 then
					local builder = open
					local count = 0
					for _, child in children do
						if count > 0 then
							builder ..= USAGE_OR
						end
						builder ..= child:getUsageText()
						count += 1
					end
					if count > 0 then
						builder ..= close
						return selfUsage .. ARGUMENT_SEPARATOR .. builder
					end
				end
			end
		end
	end

	return selfUsage
end

function CommandDispatcher.getCompletionSuggestions(
	_self: CommandDispatcher,
	parse: Types.ParseResults<S>,
	cursor: number?
): Types.CompletableFuture<Types.Suggestions>
	local cursorPosition = if cursor == nil then parse:getReader():getTotalLength() else cursor
	local context = parse:getContext()

	local nodeBeforeCursor = context:findSuggestionContext(cursorPosition)
	local parent = nodeBeforeCursor.parent
	local start = math.min(nodeBeforeCursor.startPos, cursorPosition)

	local fullInput = parse:getReader():getString()
	local truncatedInput = JavaString.substring(fullInput, 0, cursorPosition)
	local truncatedInputLowerCase = JavaString.toLowerCase(truncatedInput)
	local futures: { Types.CompletableFuture<Types.Suggestions> } = {}
	for _, node in parent:getChildren() do
		local future = Suggestions.empty()
		local ok, result = pcall(function()
			return node:listSuggestions(
				nodeBeforeCursor.context:build(truncatedInput),
				SuggestionsBuilder.new(truncatedInput, truncatedInputLowerCase, start)
			)
		end)
		if ok then
			future = result
		elseif not CommandSyntaxException.isInstance(result) then
			error(result, 0)
		end
		table.insert(futures, future)
	end

	local result: Types.CompletableFuture<Types.Suggestions> = CompletableFuture.new()
	CompletableFuture.allOf(futures):thenRun(function()
		local suggestions = {}
		for _, future in futures do
			table.insert(suggestions, future:join())
		end
		result:complete(Suggestions.merge(fullInput, suggestions))
	end)

	return result
end

function CommandDispatcher.getRoot(self: CommandDispatcher): Types.RootCommandNode<S>
	return self._root
end

local function addPaths(node: CommandNode, result: { { CommandNode } }, parents: { CommandNode })
	local current = table.clone(parents)
	table.insert(current, node)
	table.insert(result, current)

	for _, child in node:getChildren() do
		addPaths(child, result, current)
	end
end

function CommandDispatcher.getPath(self: CommandDispatcher, target: CommandNode): { string }
	local nodes: { { CommandNode } } = {}
	addPaths(self._root, nodes, {})

	for _, list in nodes do
		if rawequal(list[#list], target) then
			local result = {}
			for _, node in list do
				if not rawequal(node, self._root) then
					table.insert(result, node:getName())
				end
			end
			return result
		end
	end

	return {}
end

function CommandDispatcher.findNode(self: CommandDispatcher, path: { string }): CommandNode?
	local node: CommandNode? = self._root
	for _, name in path do
		node = (node :: CommandNode):getChild(name)
		if node == nil then
			return nil
		end
	end
	return node
end

function CommandDispatcher.findAmbiguities(self: CommandDispatcher, consumer: Types.AmbiguityConsumer<S>)
	self._root:findAmbiguities(consumer)
end

return CommandDispatcher
