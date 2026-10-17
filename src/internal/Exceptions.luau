--!strict

-- CommandSyntaxException, the exception types and BuiltInExceptions refer to each other, so they
-- live in one module; the files under exceptions/ return them from here.

local Types = require("../Types")
local Class = require("../util/Class")
local JavaFormat = require("../util/JavaFormat")
local JavaString = require("../util/JavaString")
local LiteralMessage = require("../LiteralMessage")

type Message = Types.Message
type ImmutableStringReader = Types.ImmutableStringReader
type CommandExceptionType = Types.CommandExceptionType

-- String concatenation of an Object in Java: null prints as "null".
local function str(value: unknown): string
	if value == nil then
		return "null"
	end
	return tostring(value)
end

-- CommandSyntaxException

type CommandSyntaxException = Types.CommandSyntaxException & {
	_type: CommandExceptionType,
	_message: Message,
	_input: string?,
	_cursor: number,
	_stackTrace: string?,
}

local CommandSyntaxException = {}
CommandSyntaxException.__index = CommandSyntaxException
CommandSyntaxException.CONTEXT_AMOUNT = 10
CommandSyntaxException.ENABLE_COMMAND_STACK_TRACES = true
CommandSyntaxException.BUILT_IN_EXCEPTIONS = (nil :: any) :: Types.BuiltInExceptionProvider

function CommandSyntaxException.new(
	exceptionType: CommandExceptionType,
	message: Message,
	input: string?,
	cursor: number?
): Types.CommandSyntaxException
	local self: CommandSyntaxException = setmetatable({
		_type = exceptionType,
		_message = message,
		_input = input,
		_cursor = if input == nil then -1 else cursor or -1,
		_stackTrace = if CommandSyntaxException.ENABLE_COMMAND_STACK_TRACES then debug.traceback(nil, 2) else nil,
	}, CommandSyntaxException) :: any
	return self
end

function CommandSyntaxException.isInstance(value: unknown): boolean
	return Class.isInstance(value, CommandSyntaxException)
end

function CommandSyntaxException.getMessage(self: CommandSyntaxException): string
	local message = self._message:getString()
	local context = self:getContext()
	if context ~= nil then
		message ..= ` at position {self._cursor}: {context}`
	end
	return message
end

function CommandSyntaxException.getRawMessage(self: CommandSyntaxException): Message
	return self._message
end

function CommandSyntaxException.getContext(self: CommandSyntaxException): string?
	local input = self._input
	if input == nil or self._cursor < 0 then
		return nil
	end
	local cursor = math.min(#input, self._cursor)
	local builder = ""
	if cursor > CommandSyntaxException.CONTEXT_AMOUNT then
		builder ..= "..."
	end
	builder ..= JavaString.substring(input, math.max(0, cursor - CommandSyntaxException.CONTEXT_AMOUNT), cursor)
	builder ..= "<--[HERE]"
	return builder
end

function CommandSyntaxException.getType(self: CommandSyntaxException): CommandExceptionType
	return self._type
end

function CommandSyntaxException.getInput(self: CommandSyntaxException): string?
	return self._input
end

function CommandSyntaxException.getCursor(self: CommandSyntaxException): number
	return self._cursor
end

function CommandSyntaxException.getStackTrace(self: CommandSyntaxException): string?
	return self._stackTrace
end

function CommandSyntaxException.__tostring(self: CommandSyntaxException): string
	return `com.mojang.brigadier.exceptions.CommandSyntaxException: {self:getMessage()}`
end

-- SimpleCommandExceptionType

type SimpleCommandExceptionType = Types.SimpleCommandExceptionType & { _message: Message }

local SimpleCommandExceptionType = {}
SimpleCommandExceptionType.__index = SimpleCommandExceptionType

function SimpleCommandExceptionType.new(message: Message): Types.SimpleCommandExceptionType
	local self: SimpleCommandExceptionType = setmetatable({ _message = message }, SimpleCommandExceptionType) :: any
	return self
end

function SimpleCommandExceptionType.isInstance(value: unknown): boolean
	return Class.isInstance(value, SimpleCommandExceptionType)
end

function SimpleCommandExceptionType.create(self: SimpleCommandExceptionType): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._message)
end

function SimpleCommandExceptionType.createWithContext(
	self: SimpleCommandExceptionType,
	reader: ImmutableStringReader
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._message, reader:getString(), reader:getCursor())
end

function SimpleCommandExceptionType.__tostring(self: SimpleCommandExceptionType): string
	return self._message:getString()
end

-- DynamicCommandExceptionType

type DynamicCommandExceptionType = Types.DynamicCommandExceptionType & { _function: (unknown) -> Message }

local DynamicCommandExceptionType = {}
DynamicCommandExceptionType.__index = DynamicCommandExceptionType

function DynamicCommandExceptionType.new(fn: (arg: any) -> Message): Types.DynamicCommandExceptionType
	local self: DynamicCommandExceptionType = setmetatable({ _function = fn }, DynamicCommandExceptionType) :: any
	return self
end

function DynamicCommandExceptionType.isInstance(value: unknown): boolean
	return Class.isInstance(value, DynamicCommandExceptionType)
end

function DynamicCommandExceptionType.create(
	self: DynamicCommandExceptionType,
	arg: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function(arg))
end

function DynamicCommandExceptionType.createWithContext(
	self: DynamicCommandExceptionType,
	reader: ImmutableStringReader,
	arg: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function(arg), reader:getString(), reader:getCursor())
end

-- Dynamic2CommandExceptionType

type Dynamic2CommandExceptionType = Types.Dynamic2CommandExceptionType & {
	_function: (unknown, unknown) -> Message,
}

local Dynamic2CommandExceptionType = {}
Dynamic2CommandExceptionType.__index = Dynamic2CommandExceptionType

function Dynamic2CommandExceptionType.new(fn: (a: any, b: any) -> Message): Types.Dynamic2CommandExceptionType
	local self: Dynamic2CommandExceptionType = setmetatable({ _function = fn }, Dynamic2CommandExceptionType) :: any
	return self
end

function Dynamic2CommandExceptionType.isInstance(value: unknown): boolean
	return Class.isInstance(value, Dynamic2CommandExceptionType)
end

function Dynamic2CommandExceptionType.create(
	self: Dynamic2CommandExceptionType,
	a: unknown,
	b: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function(a, b))
end

function Dynamic2CommandExceptionType.createWithContext(
	self: Dynamic2CommandExceptionType,
	reader: ImmutableStringReader,
	a: unknown,
	b: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function(a, b), reader:getString(), reader:getCursor())
end

-- Dynamic3CommandExceptionType

type Dynamic3CommandExceptionType = Types.Dynamic3CommandExceptionType & {
	_function: (unknown, unknown, unknown) -> Message,
}

local Dynamic3CommandExceptionType = {}
Dynamic3CommandExceptionType.__index = Dynamic3CommandExceptionType

function Dynamic3CommandExceptionType.new(fn: (a: any, b: any, c: any) -> Message): Types.Dynamic3CommandExceptionType
	local self: Dynamic3CommandExceptionType = setmetatable({ _function = fn }, Dynamic3CommandExceptionType) :: any
	return self
end

function Dynamic3CommandExceptionType.isInstance(value: unknown): boolean
	return Class.isInstance(value, Dynamic3CommandExceptionType)
end

function Dynamic3CommandExceptionType.create(
	self: Dynamic3CommandExceptionType,
	a: unknown,
	b: unknown,
	c: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function(a, b, c))
end

function Dynamic3CommandExceptionType.createWithContext(
	self: Dynamic3CommandExceptionType,
	reader: ImmutableStringReader,
	a: unknown,
	b: unknown,
	c: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function(a, b, c), reader:getString(), reader:getCursor())
end

-- Dynamic4CommandExceptionType

type Dynamic4CommandExceptionType = Types.Dynamic4CommandExceptionType & {
	_function: (unknown, unknown, unknown, unknown) -> Message,
}

local Dynamic4CommandExceptionType = {}
Dynamic4CommandExceptionType.__index = Dynamic4CommandExceptionType

function Dynamic4CommandExceptionType.new(
	fn: (a: any, b: any, c: any, d: any) -> Message
): Types.Dynamic4CommandExceptionType
	local self: Dynamic4CommandExceptionType = setmetatable({ _function = fn }, Dynamic4CommandExceptionType) :: any
	return self
end

function Dynamic4CommandExceptionType.isInstance(value: unknown): boolean
	return Class.isInstance(value, Dynamic4CommandExceptionType)
end

function Dynamic4CommandExceptionType.create(
	self: Dynamic4CommandExceptionType,
	a: unknown,
	b: unknown,
	c: unknown,
	d: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function(a, b, c, d))
end

function Dynamic4CommandExceptionType.createWithContext(
	self: Dynamic4CommandExceptionType,
	reader: ImmutableStringReader,
	a: unknown,
	b: unknown,
	c: unknown,
	d: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function(a, b, c, d), reader:getString(), reader:getCursor())
end

-- DynamicNCommandExceptionType

type DynamicNCommandExceptionType = Types.DynamicNCommandExceptionType & {
	_function: ({ unknown }) -> Message,
}

local DynamicNCommandExceptionType = {}
DynamicNCommandExceptionType.__index = DynamicNCommandExceptionType

function DynamicNCommandExceptionType.new(fn: (args: { any }) -> Message): Types.DynamicNCommandExceptionType
	local self: DynamicNCommandExceptionType = setmetatable({ _function = fn }, DynamicNCommandExceptionType) :: any
	return self
end

function DynamicNCommandExceptionType.isInstance(value: unknown): boolean
	return Class.isInstance(value, DynamicNCommandExceptionType)
end

-- Java's create(Object a, Object... args) passes only the varargs to the function and drops `a`.
-- The port keeps that.
function DynamicNCommandExceptionType.create(
	self: DynamicNCommandExceptionType,
	_a: unknown,
	...: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function({ ... }))
end

function DynamicNCommandExceptionType.createWithContext(
	self: DynamicNCommandExceptionType,
	reader: ImmutableStringReader,
	...: unknown
): Types.CommandSyntaxException
	return CommandSyntaxException.new(self, self._function({ ... }), reader:getString(), reader:getCursor())
end

-- BuiltInExceptions

local function literal(text: string): Message
	return LiteralMessage.new(text)
end

local DOUBLE_TOO_SMALL = Dynamic2CommandExceptionType.new(function(found, min)
	return literal(`Double must not be less than {JavaFormat.double(min)}, found {JavaFormat.double(found)}`)
end)
local DOUBLE_TOO_BIG = Dynamic2CommandExceptionType.new(function(found, max)
	return literal(`Double must not be more than {JavaFormat.double(max)}, found {JavaFormat.double(found)}`)
end)

local FLOAT_TOO_SMALL = Dynamic2CommandExceptionType.new(function(found, min)
	return literal(`Float must not be less than {JavaFormat.float(min)}, found {JavaFormat.float(found)}`)
end)
local FLOAT_TOO_BIG = Dynamic2CommandExceptionType.new(function(found, max)
	return literal(`Float must not be more than {JavaFormat.float(max)}, found {JavaFormat.float(found)}`)
end)

local INTEGER_TOO_SMALL = Dynamic2CommandExceptionType.new(function(found, min)
	return literal(`Integer must not be less than {JavaFormat.integer(min)}, found {JavaFormat.integer(found)}`)
end)
local INTEGER_TOO_BIG = Dynamic2CommandExceptionType.new(function(found, max)
	return literal(`Integer must not be more than {JavaFormat.integer(max)}, found {JavaFormat.integer(found)}`)
end)

local LONG_TOO_SMALL = Dynamic2CommandExceptionType.new(function(found, min)
	return literal(`Long must not be less than {JavaFormat.integer(min)}, found {JavaFormat.integer(found)}`)
end)
local LONG_TOO_BIG = Dynamic2CommandExceptionType.new(function(found, max)
	return literal(`Long must not be more than {JavaFormat.integer(max)}, found {JavaFormat.integer(found)}`)
end)

local LITERAL_INCORRECT = DynamicCommandExceptionType.new(function(expected)
	return literal("Expected literal " .. str(expected))
end)

local READER_EXPECTED_START_OF_QUOTE = SimpleCommandExceptionType.new(literal("Expected quote to start a string"))
local READER_EXPECTED_END_OF_QUOTE = SimpleCommandExceptionType.new(literal("Unclosed quoted string"))
local READER_INVALID_ESCAPE = DynamicCommandExceptionType.new(function(character)
	return literal("Invalid escape sequence '" .. str(character) .. "' in quoted string")
end)
local READER_INVALID_BOOL = DynamicCommandExceptionType.new(function(value)
	return literal("Invalid bool, expected true or false but found '" .. str(value) .. "'")
end)
local READER_INVALID_INT = DynamicCommandExceptionType.new(function(value)
	return literal("Invalid integer '" .. str(value) .. "'")
end)
local READER_EXPECTED_INT = SimpleCommandExceptionType.new(literal("Expected integer"))
local READER_INVALID_LONG = DynamicCommandExceptionType.new(function(value)
	return literal("Invalid long '" .. str(value) .. "'")
end)
local READER_EXPECTED_LONG = SimpleCommandExceptionType.new(literal("Expected long"))
local READER_INVALID_DOUBLE = DynamicCommandExceptionType.new(function(value)
	return literal("Invalid double '" .. str(value) .. "'")
end)
local READER_EXPECTED_DOUBLE = SimpleCommandExceptionType.new(literal("Expected double"))
local READER_INVALID_FLOAT = DynamicCommandExceptionType.new(function(value)
	return literal("Invalid float '" .. str(value) .. "'")
end)
local READER_EXPECTED_FLOAT = SimpleCommandExceptionType.new(literal("Expected float"))
local READER_EXPECTED_BOOL = SimpleCommandExceptionType.new(literal("Expected bool"))
local READER_EXPECTED_SYMBOL = DynamicCommandExceptionType.new(function(symbol)
	return literal("Expected '" .. str(symbol) .. "'")
end)

local DISPATCHER_UNKNOWN_COMMAND = SimpleCommandExceptionType.new(literal("Unknown command"))
local DISPATCHER_UNKNOWN_ARGUMENT = SimpleCommandExceptionType.new(literal("Incorrect argument for command"))
local DISPATCHER_EXPECTED_ARGUMENT_SEPARATOR =
	SimpleCommandExceptionType.new(literal("Expected whitespace to end one argument, but found trailing data"))
local DISPATCHER_PARSE_EXCEPTION = DynamicCommandExceptionType.new(function(message)
	return literal("Could not parse command: " .. str(message))
end)

local BuiltInExceptions = {}
BuiltInExceptions.__index = BuiltInExceptions

function BuiltInExceptions.new(): Types.BuiltInExceptionProvider
	return setmetatable({}, BuiltInExceptions) :: any
end

function BuiltInExceptions.isInstance(value: unknown): boolean
	return Class.isInstance(value, BuiltInExceptions)
end

function BuiltInExceptions.doubleTooLow(_self: any): Types.Dynamic2CommandExceptionType
	return DOUBLE_TOO_SMALL
end

function BuiltInExceptions.doubleTooHigh(_self: any): Types.Dynamic2CommandExceptionType
	return DOUBLE_TOO_BIG
end

function BuiltInExceptions.floatTooLow(_self: any): Types.Dynamic2CommandExceptionType
	return FLOAT_TOO_SMALL
end

function BuiltInExceptions.floatTooHigh(_self: any): Types.Dynamic2CommandExceptionType
	return FLOAT_TOO_BIG
end

function BuiltInExceptions.integerTooLow(_self: any): Types.Dynamic2CommandExceptionType
	return INTEGER_TOO_SMALL
end

function BuiltInExceptions.integerTooHigh(_self: any): Types.Dynamic2CommandExceptionType
	return INTEGER_TOO_BIG
end

function BuiltInExceptions.longTooLow(_self: any): Types.Dynamic2CommandExceptionType
	return LONG_TOO_SMALL
end

function BuiltInExceptions.longTooHigh(_self: any): Types.Dynamic2CommandExceptionType
	return LONG_TOO_BIG
end

function BuiltInExceptions.literalIncorrect(_self: any): Types.DynamicCommandExceptionType
	return LITERAL_INCORRECT
end

function BuiltInExceptions.readerExpectedStartOfQuote(_self: any): Types.SimpleCommandExceptionType
	return READER_EXPECTED_START_OF_QUOTE
end

function BuiltInExceptions.readerExpectedEndOfQuote(_self: any): Types.SimpleCommandExceptionType
	return READER_EXPECTED_END_OF_QUOTE
end

function BuiltInExceptions.readerInvalidEscape(_self: any): Types.DynamicCommandExceptionType
	return READER_INVALID_ESCAPE
end

function BuiltInExceptions.readerInvalidBool(_self: any): Types.DynamicCommandExceptionType
	return READER_INVALID_BOOL
end

function BuiltInExceptions.readerInvalidInt(_self: any): Types.DynamicCommandExceptionType
	return READER_INVALID_INT
end

function BuiltInExceptions.readerExpectedInt(_self: any): Types.SimpleCommandExceptionType
	return READER_EXPECTED_INT
end

function BuiltInExceptions.readerInvalidLong(_self: any): Types.DynamicCommandExceptionType
	return READER_INVALID_LONG
end

function BuiltInExceptions.readerExpectedLong(_self: any): Types.SimpleCommandExceptionType
	return READER_EXPECTED_LONG
end

function BuiltInExceptions.readerInvalidDouble(_self: any): Types.DynamicCommandExceptionType
	return READER_INVALID_DOUBLE
end

function BuiltInExceptions.readerExpectedDouble(_self: any): Types.SimpleCommandExceptionType
	return READER_EXPECTED_DOUBLE
end

function BuiltInExceptions.readerInvalidFloat(_self: any): Types.DynamicCommandExceptionType
	return READER_INVALID_FLOAT
end

function BuiltInExceptions.readerExpectedFloat(_self: any): Types.SimpleCommandExceptionType
	return READER_EXPECTED_FLOAT
end

function BuiltInExceptions.readerExpectedBool(_self: any): Types.SimpleCommandExceptionType
	return READER_EXPECTED_BOOL
end

function BuiltInExceptions.readerExpectedSymbol(_self: any): Types.DynamicCommandExceptionType
	return READER_EXPECTED_SYMBOL
end

function BuiltInExceptions.dispatcherUnknownCommand(_self: any): Types.SimpleCommandExceptionType
	return DISPATCHER_UNKNOWN_COMMAND
end

function BuiltInExceptions.dispatcherUnknownArgument(_self: any): Types.SimpleCommandExceptionType
	return DISPATCHER_UNKNOWN_ARGUMENT
end

function BuiltInExceptions.dispatcherExpectedArgumentSeparator(_self: any): Types.SimpleCommandExceptionType
	return DISPATCHER_EXPECTED_ARGUMENT_SEPARATOR
end

function BuiltInExceptions.dispatcherParseException(_self: any): Types.DynamicCommandExceptionType
	return DISPATCHER_PARSE_EXCEPTION
end

CommandSyntaxException.BUILT_IN_EXCEPTIONS = BuiltInExceptions.new()

return {
	CommandSyntaxException = CommandSyntaxException,
	SimpleCommandExceptionType = SimpleCommandExceptionType,
	DynamicCommandExceptionType = DynamicCommandExceptionType,
	Dynamic2CommandExceptionType = Dynamic2CommandExceptionType,
	Dynamic3CommandExceptionType = Dynamic3CommandExceptionType,
	Dynamic4CommandExceptionType = Dynamic4CommandExceptionType,
	DynamicNCommandExceptionType = DynamicNCommandExceptionType,
	BuiltInExceptions = BuiltInExceptions,
}
