--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local Objects = require("../util/Objects")
local RuntimeException = require("../util/RuntimeException")

-- The source type. The public types in Types.luau keep it generic; the implementation uses `any`,
-- which keeps the new solver from giving up on these mutually recursive types.
type S = any

type CommandContext = Types.CommandContext<S> & {
	_source: S,
	_input: string,
	_command: Types.Command<S>?,
	_arguments: { [string]: Types.ParsedArgument<S, any> },
	_rootNode: Types.CommandNode<S>,
	_nodes: { Types.ParsedCommandNode<S> },
	_range: Types.StringRange,
	_child: Types.CommandContext<S>?,
	_modifier: Types.RedirectModifier<S>?,
	_forks: boolean,
}

local CommandContext = {}
CommandContext.__index = CommandContext

function CommandContext.new(
	source: S,
	input: string,
	arguments: { [string]: Types.ParsedArgument<S, any> },
	command: Types.Command<S>?,
	rootNode: Types.CommandNode<S>,
	nodes: { Types.ParsedCommandNode<S> },
	range: Types.StringRange,
	child: Types.CommandContext<S>?,
	modifier: Types.RedirectModifier<S>?,
	forks: boolean
): Types.CommandContext<S>
	local self: CommandContext = setmetatable({
		_source = source,
		_input = input,
		_arguments = arguments,
		_command = command,
		_rootNode = rootNode,
		_nodes = nodes,
		_range = range,
		_child = child,
		_modifier = modifier,
		_forks = forks,
	}, CommandContext) :: any
	return self
end

function CommandContext.isInstance(value: unknown): boolean
	return Class.isInstance(value, CommandContext)
end

function CommandContext.copyFor(self: CommandContext, source: S): Types.CommandContext<S>
	if rawequal(self._source, source) then
		return self
	end
	return CommandContext.new(
		source,
		self._input,
		self._arguments,
		self._command,
		self._rootNode,
		self._nodes,
		self._range,
		self._child,
		self._modifier,
		self._forks
	)
end

function CommandContext.getChild(self: CommandContext): Types.CommandContext<S>?
	return self._child
end

function CommandContext.getLastChild(self: CommandContext): Types.CommandContext<S>
	local result: Types.CommandContext<S> = self
	while true do
		local child = result:getChild()
		if child == nil then
			return result
		end
		result = child
	end
end

function CommandContext.getCommand(self: CommandContext): Types.Command<S>?
	return self._command
end

function CommandContext.getSource(self: CommandContext): S
	return self._source
end

-- The class of a value as Java's getSimpleName would name it, for the error message.
local function className(value: unknown): string
	if type(value) == "table" then
		local metatable = getmetatable(value :: any)
		if type(metatable) == "table" and type(rawget(metatable, "__tostring")) ~= "function" then
			return "table"
		end
	end
	return typeof(value)
end

-- Class.isAssignableFrom: a Luau type name such as "number" or "Vector3", "any" for Object, or a
-- class with isInstance.
local function isAssignable(class: any, value: unknown): boolean
	if class == "any" then
		return true
	end
	if type(class) == "string" then
		return typeof(value) == class
	end
	local isInstance = if type(class) == "table" then class.isInstance else nil
	if type(isInstance) == "function" then
		return isInstance(value)
	end
	error(RuntimeException.IllegalArgumentException.new(`Unknown argument class {tostring(class)}`))
end

function CommandContext.getArgument(self: CommandContext, name: string, class: any): any
	local argument = self._arguments[name]

	if argument == nil then
		error(RuntimeException.IllegalArgumentException.new("No such argument '" .. name .. "' exists on this command"))
	end

	local result = argument:getResult()
	if isAssignable(class, result) then
		return result
	else
		error(
			RuntimeException.IllegalArgumentException.new(
				"Argument '" .. name .. "' is defined as " .. className(result) .. ", not " .. tostring(class)
			)
		)
	end
end

function CommandContext.equals(self: CommandContext, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if not CommandContext.isInstance(other) then
		return false
	end

	local that = other :: CommandContext

	if not Objects.equals(self._arguments, that._arguments) then
		return false
	end
	if not self._rootNode:equals(that._rootNode) then
		return false
	end
	if #self._nodes ~= #that._nodes or not Objects.equals(self._nodes, that._nodes) then
		return false
	end
	if if self._command ~= nil then not Objects.equals(self._command, that._command) else that._command ~= nil then
		return false
	end
	if not Objects.equals(self._source, that._source) then
		return false
	end
	if if self._child ~= nil then not self._child:equals(that._child) else that._child ~= nil then
		return false
	end

	return true
end

function CommandContext.getRedirectModifier(self: CommandContext): Types.RedirectModifier<S>?
	return self._modifier
end

function CommandContext.getRange(self: CommandContext): Types.StringRange
	return self._range
end

function CommandContext.getInput(self: CommandContext): string
	return self._input
end

function CommandContext.getRootNode(self: CommandContext): Types.CommandNode<S>
	return self._rootNode
end

function CommandContext.getNodes(self: CommandContext): { Types.ParsedCommandNode<S> }
	return self._nodes
end

function CommandContext.hasNodes(self: CommandContext): boolean
	return #self._nodes > 0
end

function CommandContext.isForked(self: CommandContext): boolean
	return self._forks
end

return CommandContext
