--!strict

-- Nodes build builders (createBuilder) and builders build nodes (build), so the command nodes and
-- their builders live in one module; the files under tree/ and builder/ return them from here.

local Types = require("../Types")
local Class = require("../util/Class")
local CommandSyntaxException = require("../exceptions/CommandSyntaxException")
local JavaString = require("../util/JavaString")
local Objects = require("../util/Objects")
local ParsedArgument = require("../context/ParsedArgument")
local RuntimeException = require("../util/RuntimeException")
local Sort = require("../util/Sort")
local StringRange = require("../context/StringRange")
local StringReader = require("../StringReader")
local Suggestions = require("../suggestion/Suggestions")

-- The source type, and the result type of an argument. The public types in Types.luau keep them
-- generic; the implementation uses `any`, which keeps the new solver from giving up on these
-- mutually recursive types.
type S = any
type T = any

type Command = Types.Command<S>
type Predicate = Types.Predicate<S>
type RedirectModifier = Types.RedirectModifier<S>
type SuggestionProvider = Types.SuggestionProvider<S>
type ArgumentType<T> = Types.ArgumentType<T>

-- The fields every node has. Subclass fields are optional here so one shape covers all of them.
type Node = Types.CommandNode<S> & {
	_children: { [string]: Types.CommandNode<S> },
	_childList: { Types.CommandNode<S> },
	_literals: { [string]: Types.CommandNode<S> },
	_argumentList: { Types.CommandNode<S> },
	_requirement: Predicate,
	_redirect: Types.CommandNode<S>?,
	_modifier: RedirectModifier?,
	_forks: boolean,
	_command: Command?,
	-- LiteralCommandNode
	_literal: string,
	_literalLowerCase: string,
	-- ArgumentCommandNode
	_name: string,
	_type: ArgumentType<any>,
	_customSuggestions: SuggestionProvider?,
}

type Builder = {
	_arguments: Types.CommandNode<S>,
	_command: Command?,
	_requirement: Predicate,
	_target: Types.CommandNode<S>?,
	_modifier: RedirectModifier?,
	_forks: boolean,
	-- LiteralArgumentBuilder
	_literal: string,
	-- RequiredArgumentBuilder
	_name: string,
	_type: ArgumentType<any>,
	_suggestionsProvider: SuggestionProvider?,
	getThis: (self: any) -> any,
	build: (self: any) -> Types.CommandNode<S>,
}

local function always(): boolean
	return true
end

local function catchSyntax<T>(body: () -> T, onSyntaxException: (Types.CommandSyntaxException) -> T): T
	local ok, result = pcall(body)
	if ok then
		return result
	end
	if CommandSyntaxException.isInstance(result) then
		return onSyntaxException(result :: any)
	end
	error(result, 0)
end

local CommandNode = {}
CommandNode.__index = CommandNode

local RootCommandNode = {}
RootCommandNode.__index = RootCommandNode

local LiteralCommandNode = {}
LiteralCommandNode.__index = LiteralCommandNode

local ArgumentCommandNode = {}
ArgumentCommandNode.__index = ArgumentCommandNode

local ArgumentBuilder = {}
ArgumentBuilder.__index = ArgumentBuilder

local LiteralArgumentBuilder = {}
LiteralArgumentBuilder.__index = LiteralArgumentBuilder

local RequiredArgumentBuilder = {}
RequiredArgumentBuilder.__index = RequiredArgumentBuilder

-- CommandNode

-- The protected constructor: sets up a new node of any subclass.
function CommandNode.init(
	self: any,
	command: Command?,
	requirement: Predicate,
	redirect: Types.CommandNode<S>?,
	modifier: RedirectModifier?,
	forks: boolean
)
	self._children = {}
	self._childList = {}
	self._literals = {}
	self._argumentList = {}
	self._requirement = requirement
	self._redirect = redirect
	self._modifier = modifier
	self._forks = forks
	self._command = command
end

function CommandNode.isInstance(value: unknown): boolean
	return Class.isInstance(value, CommandNode)
end

function CommandNode.getCommand(self: Node): Command?
	return self._command
end

function CommandNode.getChildren(self: Node): { Types.CommandNode<S> }
	return self._childList
end

function CommandNode.getChild(self: Node, name: string): Types.CommandNode<S>?
	return self._children[name]
end

function CommandNode.getRedirect(self: Node): Types.CommandNode<S>?
	return self._redirect
end

function CommandNode.getRedirectModifier(self: Node): RedirectModifier?
	return self._modifier
end

function CommandNode.canUse(self: Node, source: S): boolean
	return self._requirement(source)
end

function CommandNode.addChild(self: Node, node: Types.CommandNode<S>)
	if RootCommandNode.isInstance(node) then
		error(
			RuntimeException.UnsupportedOperationException.new(
				"Cannot add a RootCommandNode as a child to any other CommandNode"
			)
		)
	end

	local child = self._children[node:getName()] :: Node?
	if child ~= nil then
		-- We've found something to merge onto
		local command = node:getCommand()
		if command ~= nil then
			child._command = command
		end
		for _, grandchild in node:getChildren() do
			child:addChild(grandchild)
		end
	else
		self._children[node:getName()] = node
		table.insert(self._childList, node)
		if LiteralCommandNode.isInstance(node) then
			self._literals[node:getName()] = node
		elseif ArgumentCommandNode.isInstance(node) then
			table.insert(self._argumentList, node)
		end
	end
end

-- A HashSet<String> of inputs, in the order they were found.
local function addInput(matches: { string }, input: string)
	if table.find(matches, input) == nil then
		table.insert(matches, input)
	end
end

function CommandNode.findAmbiguities(self: Node, consumer: Types.AmbiguityConsumer<S>)
	local matches: { string } = {}

	for _, child in self._childList do
		for _, sibling in self._childList do
			if rawequal(child, sibling) then
				continue
			end

			for _, input in child:getExamples() do
				if sibling:isValidInput(input) then
					addInput(matches, input)
				end
			end

			if #matches > 0 then
				consumer(self, child, sibling, matches)
				matches = {}
			end
		end

		child:findAmbiguities(consumer)
	end
end

function CommandNode.isValidInput(_self: Node, _input: string): boolean
	error("CommandNode.isValidInput is abstract")
end

-- Map.equals on the children: the same names, each mapped to an equal node.
local function childrenEqual(a: { [string]: Types.CommandNode<S> }, b: { [string]: Types.CommandNode<S> }): boolean
	for name, node in a do
		local other = b[name]
		if other == nil or not node:equals(other) then
			return false
		end
	end
	for name in b do
		if a[name] == nil then
			return false
		end
	end
	return true
end

function CommandNode.equals(self: Node, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not CommandNode.isInstance(other) then
		return false
	end

	local that = other :: Node

	if not childrenEqual(self._children, that._children) then
		return false
	end
	if if self._command ~= nil then not Objects.equals(self._command, that._command) else that._command ~= nil then
		return false
	end

	return true
end

function CommandNode.getRequirement(self: Node): Predicate
	return self._requirement
end

function CommandNode.getRelevantNodes(self: Node, input: Types.StringReader): { Types.CommandNode<S> }
	if next(self._literals) ~= nil then
		local cursor = input:getCursor()
		while input:canRead() and input:peek() ~= " " do
			input:skip()
		end
		local text = JavaString.substring(input:getString(), cursor, input:getCursor())
		input:setCursor(cursor)
		local literal = self._literals[text]
		if literal ~= nil then
			return { literal }
		else
			return self._argumentList
		end
	else
		return self._argumentList
	end
end

function CommandNode.compareTo(self: Node, other: Types.CommandNode<S>): number
	if LiteralCommandNode.isInstance(self) == LiteralCommandNode.isInstance(other) then
		return Sort.compareStrings(self:getSortedKey(), other:getSortedKey())
	end

	return if LiteralCommandNode.isInstance(other) then 1 else -1
end

function CommandNode.isFork(self: Node): boolean
	return self._forks
end

-- RootCommandNode

Class.extend(RootCommandNode, CommandNode)

local function sourceOfContext(context: Types.CommandContext<S>): { S }
	return { context:getSource() }
end

function RootCommandNode.new(): Types.RootCommandNode<S>
	local self = setmetatable({}, RootCommandNode) :: any
	CommandNode.init(self, nil, always, nil, sourceOfContext, false)
	return self
end

function RootCommandNode.isInstance(value: unknown): boolean
	return Class.isInstance(value, RootCommandNode)
end

function RootCommandNode.getName(_self: Node): string
	return ""
end

function RootCommandNode.getUsageText(_self: Node): string
	return ""
end

function RootCommandNode.parse(
	_self: Node,
	_reader: Types.StringReader,
	_contextBuilder: Types.CommandContextBuilder<S>
)
end

function RootCommandNode.listSuggestions(
	_self: Node,
	_context: Types.CommandContext<S>,
	_builder: Types.SuggestionsBuilder
): Types.CompletableFuture<Types.Suggestions>
	return Suggestions.empty()
end

function RootCommandNode.isValidInput(_self: Node, _input: string): boolean
	return false
end

function RootCommandNode.equals(self: Node, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not RootCommandNode.isInstance(other) then
		return false
	end
	return CommandNode.equals(self, other)
end

function RootCommandNode.createBuilder(_self: Node): Types.ArgumentBuilder<S>
	error(RuntimeException.IllegalStateException.new("Cannot convert root into a builder"))
end

function RootCommandNode.getSortedKey(_self: Node): string
	return ""
end

function RootCommandNode.getExamples(_self: Node): { string }
	return {}
end

function RootCommandNode.__tostring(_self: Node): string
	return "<root>"
end

-- LiteralCommandNode

Class.extend(LiteralCommandNode, CommandNode)

function LiteralCommandNode.new(
	literal: string,
	command: Command?,
	requirement: Predicate,
	redirect: Types.CommandNode<S>?,
	modifier: RedirectModifier?,
	forks: boolean
): Types.LiteralCommandNode<S>
	local self = setmetatable({}, LiteralCommandNode) :: any
	CommandNode.init(self, command, requirement, redirect, modifier, forks)
	local node = self
	node._literal = literal
	node._literalLowerCase = JavaString.toLowerCase(literal)
	return node
end

function LiteralCommandNode.isInstance(value: unknown): boolean
	return Class.isInstance(value, LiteralCommandNode)
end

function LiteralCommandNode.getLiteral(self: Node): string
	return self._literal
end

function LiteralCommandNode.getName(self: Node): string
	return self._literal
end

-- The private parse(StringReader): the end of the literal, or -1 when the input doesn't start with it.
local function parseLiteral(self: Node, reader: Types.StringReader): number
	local start = reader:getCursor()
	if reader:canRead(#self._literal) then
		local finish = start + #self._literal
		if JavaString.substring(reader:getString(), start, finish) == self._literal then
			reader:setCursor(finish)
			if not reader:canRead() or reader:peek() == " " then
				return finish
			else
				reader:setCursor(start)
			end
		end
	end
	return -1
end

function LiteralCommandNode.parse(
	self: Node,
	reader: Types.StringReader,
	contextBuilder: Types.CommandContextBuilder<S>
)
	local start = reader:getCursor()
	local finish = parseLiteral(self, reader)
	if finish > -1 then
		contextBuilder:withNode(self, StringRange.between(start, finish))
		return
	end

	error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:literalIncorrect():createWithContext(reader, self._literal))
end

function LiteralCommandNode.listSuggestions(
	self: Node,
	_context: Types.CommandContext<S>,
	builder: Types.SuggestionsBuilder
): Types.CompletableFuture<Types.Suggestions>
	if JavaString.startsWith(self._literalLowerCase, builder:getRemainingLowerCase()) then
		return builder:suggest(self._literal):buildFuture()
	else
		return Suggestions.empty()
	end
end

function LiteralCommandNode.isValidInput(self: Node, input: string): boolean
	return parseLiteral(self, StringReader.new(input)) > -1
end

function LiteralCommandNode.equals(self: Node, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not LiteralCommandNode.isInstance(other) then
		return false
	end

	local that = other :: Node

	if self._literal ~= that._literal then
		return false
	end
	return CommandNode.equals(self, other)
end

function LiteralCommandNode.getUsageText(self: Node): string
	return self._literal
end

function LiteralCommandNode.createBuilder(self: Node): Types.LiteralArgumentBuilder<S>
	local builder = LiteralArgumentBuilder.literal(self._literal)
	builder:requires(self:getRequirement())
	builder:forward(self:getRedirect(), self:getRedirectModifier(), self:isFork())
	local command = self:getCommand()
	if command ~= nil then
		builder:executes(command)
	end
	return builder
end

function LiteralCommandNode.getSortedKey(self: Node): string
	return self._literal
end

function LiteralCommandNode.getExamples(self: Node): { string }
	return { self._literal }
end

function LiteralCommandNode.__tostring(self: Node): string
	return "<literal " .. self._literal .. ">"
end

-- ArgumentCommandNode

Class.extend(ArgumentCommandNode, CommandNode)

local USAGE_ARGUMENT_OPEN = "<"
local USAGE_ARGUMENT_CLOSE = ">"

function ArgumentCommandNode.new(
	name: string,
	argumentType: ArgumentType<T>,
	command: Command?,
	requirement: Predicate,
	redirect: Types.CommandNode<S>?,
	modifier: RedirectModifier?,
	forks: boolean,
	customSuggestions: SuggestionProvider?
): Types.ArgumentCommandNode<S, T>
	local self = setmetatable({}, ArgumentCommandNode) :: any
	CommandNode.init(self, command, requirement, redirect, modifier, forks)
	local node = self
	node._name = name
	node._type = argumentType
	node._customSuggestions = customSuggestions
	return node
end

function ArgumentCommandNode.isInstance(value: unknown): boolean
	return Class.isInstance(value, ArgumentCommandNode)
end

function ArgumentCommandNode.getType(self: Node): ArgumentType<any>
	return self._type
end

function ArgumentCommandNode.getName(self: Node): string
	return self._name
end

function ArgumentCommandNode.getUsageText(self: Node): string
	return USAGE_ARGUMENT_OPEN .. self._name .. USAGE_ARGUMENT_CLOSE
end

function ArgumentCommandNode.getCustomSuggestions(self: Node): SuggestionProvider?
	return self._customSuggestions
end

function ArgumentCommandNode.parse(
	self: Node,
	reader: Types.StringReader,
	contextBuilder: Types.CommandContextBuilder<S>
)
	local start = reader:getCursor()
	local result = self._type:parse(reader, contextBuilder:getSource())
	local parsed = ParsedArgument.new(start, reader:getCursor(), result)

	contextBuilder:withArgument(self._name, parsed)
	contextBuilder:withNode(self, parsed:getRange())
end

function ArgumentCommandNode.listSuggestions(
	self: Node,
	context: Types.CommandContext<S>,
	builder: Types.SuggestionsBuilder
): Types.CompletableFuture<Types.Suggestions>
	local customSuggestions = self._customSuggestions
	if customSuggestions == nil then
		local listSuggestions = self._type.listSuggestions
		if listSuggestions == nil then
			return Suggestions.empty()
		end
		return listSuggestions(self._type, context, builder)
	else
		return customSuggestions(context, builder)
	end
end

function ArgumentCommandNode.createBuilder(self: Node): Types.RequiredArgumentBuilder<S, any>
	local builder = RequiredArgumentBuilder.argument(self._name, self._type)
	builder:requires(self:getRequirement())
	builder:forward(self:getRedirect(), self:getRedirectModifier(), self:isFork())
	builder:suggests(self._customSuggestions)
	local command = self:getCommand()
	if command ~= nil then
		builder:executes(command)
	end
	return builder
end

function ArgumentCommandNode.isValidInput(self: Node, input: string): boolean
	return catchSyntax(function()
		local reader = StringReader.new(input)
		self._type:parse(reader)
		return not reader:canRead() or reader:peek() == " "
	end, function()
		return false
	end)
end

function ArgumentCommandNode.equals(self: Node, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not ArgumentCommandNode.isInstance(other) then
		return false
	end

	local that = other :: Node

	if self._name ~= that._name then
		return false
	end
	if not Objects.equals(self._type, that._type) then
		return false
	end
	return CommandNode.equals(self, other)
end

function ArgumentCommandNode.getSortedKey(self: Node): string
	return self._name
end

function ArgumentCommandNode.getExamples(self: Node): { string }
	local getExamples = self._type.getExamples
	if getExamples == nil then
		return {}
	end
	return getExamples(self._type)
end

function ArgumentCommandNode.__tostring(self: Node): string
	return "<argument " .. self._name .. ":" .. tostring(self._type) .. ">"
end

-- ArgumentBuilder

-- Sets up a new builder of any subclass, as the field initialisers do in Java.
function ArgumentBuilder.init(self: any)
	self._arguments = RootCommandNode.new()
	self._command = nil
	self._requirement = always
	self._target = nil
	self._modifier = nil
	self._forks = false
end

function ArgumentBuilder.isInstance(value: unknown): boolean
	return Class.isInstance(value, ArgumentBuilder)
end

function ArgumentBuilder.with(self: Builder, argument: Types.ArgumentBuilder<S> | Types.CommandNode<S>): any
	if self._target ~= nil then
		error(RuntimeException.IllegalStateException.new("Cannot add children to a redirected node"))
	end
	if CommandNode.isInstance(argument) then
		self._arguments:addChild(argument :: Types.CommandNode<S>)
	else
		self._arguments:addChild((argument :: Types.ArgumentBuilder<S>):build())
	end
	return self:getThis()
end

function ArgumentBuilder.getArguments(self: Builder): { Types.CommandNode<S> }
	return self._arguments:getChildren()
end

function ArgumentBuilder.executes(self: Builder, command: Command?): any
	self._command = command
	return self:getThis()
end

function ArgumentBuilder.getCommand(self: Builder): Command?
	return self._command
end

function ArgumentBuilder.requires(self: Builder, requirement: Predicate): any
	self._requirement = requirement
	return self:getThis()
end

function ArgumentBuilder.getRequirement(self: Builder): Predicate
	return self._requirement
end

function ArgumentBuilder.redirect(
	self: Builder,
	target: Types.CommandNode<S>?,
	modifier: Types.SingleRedirectModifier<S>?
): any
	if modifier == nil then
		return ArgumentBuilder.forward(self, target, nil, false)
	end
	return ArgumentBuilder.forward(self, target, function(context)
		return { modifier(context) }
	end, false)
end

function ArgumentBuilder.fork(self: Builder, target: Types.CommandNode<S>?, modifier: RedirectModifier?): any
	return ArgumentBuilder.forward(self, target, modifier, true)
end

function ArgumentBuilder.forward(
	self: Builder,
	target: Types.CommandNode<S>?,
	modifier: RedirectModifier?,
	fork: boolean
): any
	if #self._arguments:getChildren() > 0 then
		error(RuntimeException.IllegalStateException.new("Cannot forward a node with children"))
	end
	self._target = target
	self._modifier = modifier
	self._forks = fork
	return self:getThis()
end

function ArgumentBuilder.getRedirect(self: Builder): Types.CommandNode<S>?
	return self._target
end

function ArgumentBuilder.getRedirectModifier(self: Builder): RedirectModifier?
	return self._modifier
end

function ArgumentBuilder.isFork(self: Builder): boolean
	return self._forks
end

function ArgumentBuilder.getThis(_self: any): any
	error("ArgumentBuilder.getThis is abstract")
end

function ArgumentBuilder.build(_self: any): any
	error("ArgumentBuilder.build is abstract")
end

-- LiteralArgumentBuilder

Class.extend(LiteralArgumentBuilder, ArgumentBuilder)

function LiteralArgumentBuilder.new(literal: string): Types.LiteralArgumentBuilder<S>
	local self = setmetatable({}, LiteralArgumentBuilder) :: any
	ArgumentBuilder.init(self)
	local builder = self
	builder._literal = literal
	return builder
end

function LiteralArgumentBuilder.literal(name: string): Types.LiteralArgumentBuilder<S>
	return LiteralArgumentBuilder.new(name)
end

function LiteralArgumentBuilder.isInstance(value: unknown): boolean
	return Class.isInstance(value, LiteralArgumentBuilder)
end

function LiteralArgumentBuilder.getThis(self: Builder): any
	return self
end

function LiteralArgumentBuilder.getLiteral(self: Builder): string
	return self._literal
end

function LiteralArgumentBuilder.build(self: Builder): Types.LiteralCommandNode<S>
	local result = LiteralCommandNode.new(
		self._literal,
		ArgumentBuilder.getCommand(self),
		ArgumentBuilder.getRequirement(self),
		ArgumentBuilder.getRedirect(self),
		ArgumentBuilder.getRedirectModifier(self),
		ArgumentBuilder.isFork(self)
	)

	for _, argument in ArgumentBuilder.getArguments(self) do
		result:addChild(argument)
	end

	return result
end

-- RequiredArgumentBuilder

Class.extend(RequiredArgumentBuilder, ArgumentBuilder)

function RequiredArgumentBuilder.argument(
	name: string,
	argumentType: ArgumentType<T>
): Types.RequiredArgumentBuilder<S, T>
	local self = setmetatable({}, RequiredArgumentBuilder) :: any
	ArgumentBuilder.init(self)
	local builder = self
	builder._name = name
	builder._type = argumentType
	builder._suggestionsProvider = nil
	return builder
end

function RequiredArgumentBuilder.isInstance(value: unknown): boolean
	return Class.isInstance(value, RequiredArgumentBuilder)
end

function RequiredArgumentBuilder.suggests(self: Builder, provider: SuggestionProvider?): any
	self._suggestionsProvider = provider
	return self:getThis()
end

function RequiredArgumentBuilder.getSuggestionsProvider(self: Builder): SuggestionProvider?
	return self._suggestionsProvider
end

function RequiredArgumentBuilder.getThis(self: Builder): any
	return self
end

function RequiredArgumentBuilder.getType(self: Builder): ArgumentType<any>
	return self._type
end

function RequiredArgumentBuilder.getName(self: Builder): string
	return self._name
end

function RequiredArgumentBuilder.build(self: Builder): Types.ArgumentCommandNode<S, any>
	local result = ArgumentCommandNode.new(
		self._name,
		self._type,
		ArgumentBuilder.getCommand(self),
		ArgumentBuilder.getRequirement(self),
		ArgumentBuilder.getRedirect(self),
		ArgumentBuilder.getRedirectModifier(self),
		ArgumentBuilder.isFork(self),
		RequiredArgumentBuilder.getSuggestionsProvider(self)
	)

	for _, argument in ArgumentBuilder.getArguments(self) do
		result:addChild(argument)
	end

	return result
end

return {
	CommandNode = CommandNode,
	RootCommandNode = RootCommandNode,
	LiteralCommandNode = LiteralCommandNode,
	ArgumentCommandNode = ArgumentCommandNode,
	ArgumentBuilder = ArgumentBuilder,
	LiteralArgumentBuilder = LiteralArgumentBuilder,
	RequiredArgumentBuilder = RequiredArgumentBuilder,
}
