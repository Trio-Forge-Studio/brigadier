--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local Types = require("@brigadier/Types")
local CommandDispatcher = require("@brigadier/CommandDispatcher")
local StringReader = require("@brigadier/StringReader")
local IntegerArgumentType = require("@brigadier/arguments/IntegerArgumentType")
local LiteralArgumentBuilder = require("@brigadier/builder/LiteralArgumentBuilder")
local RequiredArgumentBuilder = require("@brigadier/builder/RequiredArgumentBuilder")
local CommandContext = require("@brigadier/context/CommandContext")
local CommandSyntaxException = require("@brigadier/exceptions/CommandSyntaxException")

local assertThat, is, equalTo = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo
local notNullValue, nullValue, hasProperty = Hamcrest.notNullValue, Hamcrest.nullValue, Hamcrest.hasProperty
local any, eq, argThat, times, never = Mockito.any, Mockito.eq, Mockito.argThat, Mockito.times, Mockito.never
local getInteger, integer = IntegerArgumentType.getInteger, IntegerArgumentType.integer
local literal = LiteralArgumentBuilder.literal
local argument = RequiredArgumentBuilder.argument

local CommandDispatcherTest = JUnit.suite("CommandDispatcherTest")
local subject: Types.CommandDispatcher<any>
local command: any
local source: any
local consumer: any

-- `new Object()`: a plain {} would equal every other empty table under Hamcrest's equalTo.
local function newObject(name: string): any
	return setmetatable({}, {
		__tostring = function()
			return name
		end,
	})
end

CommandDispatcherTest:before(function()
	command = Mockito.mock("command")
	source = Mockito.mockObject("source")
	consumer = Mockito.mock("consumer")

	subject = CommandDispatcher.new()
	Mockito.when(command, any()):thenReturn(42)
end)

local function inputWithOffset(input: string, offset: number): Types.StringReader
	local result = StringReader.new(input)
	result:setCursor(offset)
	return result
end

CommandDispatcherTest:test("testCreateAndExecuteCommand", function()
	subject:register(literal("foo"):executes(command))

	assertThat(subject:execute("foo", source), is(42))
	Mockito.verify(command, any())
end)

CommandDispatcherTest:test("testCreateAndExecuteOffsetCommand", function()
	subject:register(literal("foo"):executes(command))

	assertThat(subject:execute(inputWithOffset("/foo", 1), source), is(42))
	Mockito.verify(command, any())
end)

CommandDispatcherTest:test("testCreateAndMergeCommands", function()
	subject:register(literal("base"):with(literal("foo"):executes(command)))
	subject:register(literal("base"):with(literal("bar"):executes(command)))

	assertThat(subject:execute("base foo", source), is(42))
	assertThat(subject:execute("base bar", source), is(42))
	Mockito.verify(command, times(2), any())
end)

CommandDispatcherTest:test("testExecuteUnknownCommand", function()
	subject:register(literal("bar"))
	subject:register(literal("baz"))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("foo", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand()))
	assertThat(ex:getCursor(), is(0))
end)

CommandDispatcherTest:test("testExecuteImpermissibleCommand", function()
	subject:register(literal("foo"):requires(function(_s)
		return false
	end))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("foo", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand()))
	assertThat(ex:getCursor(), is(0))
end)

CommandDispatcherTest:test("testExecuteEmptyCommand", function()
	subject:register(literal(""))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand()))
	assertThat(ex:getCursor(), is(0))
end)

CommandDispatcherTest:test("testExecuteUnknownSubcommand", function()
	subject:register(literal("foo"):executes(command))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("foo bar", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownArgument()))
	assertThat(ex:getCursor(), is(4))
end)

CommandDispatcherTest:test("testExecuteIncorrectLiteral", function()
	subject:register(literal("foo"):executes(command):with(literal("bar")))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("foo baz", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownArgument()))
	assertThat(ex:getCursor(), is(4))
end)

CommandDispatcherTest:test("testExecuteAmbiguousIncorrectArgument", function()
	subject:register(literal("foo"):executes(command):with(literal("bar")):with(literal("baz")))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("foo unknown", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownArgument()))
	assertThat(ex:getCursor(), is(4))
end)

CommandDispatcherTest:test("testExecuteSubcommand", function()
	local subCommand = Mockito.mock("subCommand")
	Mockito.when(subCommand, any()):thenReturn(100)

	subject:register(
		literal("foo"):with(literal("a")):with(literal("="):executes(subCommand)):with(literal("c")):executes(command)
	)

	assertThat(subject:execute("foo =", source), is(100))
	Mockito.verify(subCommand, any())
end)

CommandDispatcherTest:test("testParseIncompleteLiteral", function()
	subject:register(literal("foo"):with(literal("bar"):executes(command)))

	local parse = subject:parse("foo ", source)
	assertThat(parse:getReader():getRemaining(), equalTo(" "))
	assertThat(#parse:getContext():getNodes(), is(1))
end)

CommandDispatcherTest:test("testParseIncompleteArgument", function()
	subject:register(literal("foo"):with(argument("bar", integer()):executes(command)))

	local parse = subject:parse("foo ", source)
	assertThat(parse:getReader():getRemaining(), equalTo(" "))
	assertThat(#parse:getContext():getNodes(), is(1))
end)

CommandDispatcherTest:test("testExecuteAmbiguiousParentSubcommand", function()
	local subCommand = Mockito.mock("subCommand")
	Mockito.when(subCommand, any()):thenReturn(100)

	subject:register(
		literal("test")
			:with(argument("incorrect", integer()):executes(command))
			:with(argument("right", integer()):with(argument("sub", integer()):executes(subCommand)))
	)

	assertThat(subject:execute("test 1 2", source), is(100))
	Mockito.verify(subCommand, any())
	Mockito.verify(command, never(), any())
end)

CommandDispatcherTest:test("testExecuteAmbiguiousParentSubcommandViaRedirect", function()
	local subCommand = Mockito.mock("subCommand")
	Mockito.when(subCommand, any()):thenReturn(100)

	local real = subject:register(
		literal("test")
			:with(argument("incorrect", integer()):executes(command))
			:with(argument("right", integer()):with(argument("sub", integer()):executes(subCommand)))
	)

	subject:register(literal("redirect"):redirect(real))

	assertThat(subject:execute("redirect 1 2", source), is(100))
	Mockito.verify(subCommand, any())
	Mockito.verify(command, never(), any())
end)

CommandDispatcherTest:test("testExecuteRedirectedMultipleTimes", function()
	local concreteNode = subject:register(literal("actual"):executes(command))
	local redirectNode = subject:register(literal("redirected"):redirect(subject:getRoot()))

	local input = "redirected redirected actual"

	local parse = subject:parse(input, source)
	assertThat(parse:getContext():getRange():get(input), equalTo("redirected"))
	assertThat(#parse:getContext():getNodes(), is(1))
	assertThat(parse:getContext():getRootNode(), is(subject:getRoot()))
	assertThat(parse:getContext():getNodes()[1]:getRange(), equalTo(parse:getContext():getRange()))
	assertThat(parse:getContext():getNodes()[1]:getNode(), is(redirectNode))

	local child1: Types.CommandContextBuilder<any> = parse:getContext():getChild() :: any
	assertThat(child1, is(notNullValue()))
	assertThat(child1:getRange():get(input), equalTo("redirected"))
	assertThat(#child1:getNodes(), is(1))
	assertThat(child1:getRootNode(), is(subject:getRoot()))
	assertThat(child1:getNodes()[1]:getRange(), equalTo(child1:getRange()))
	assertThat(child1:getNodes()[1]:getNode(), is(redirectNode))

	local child2: Types.CommandContextBuilder<any> = child1:getChild() :: any
	assertThat(child2, is(notNullValue()))
	assertThat(child2:getRange():get(input), equalTo("actual"))
	assertThat(#child2:getNodes(), is(1))
	assertThat(child2:getRootNode(), is(subject:getRoot()))
	assertThat(child2:getNodes()[1]:getRange(), equalTo(child2:getRange()))
	assertThat(child2:getNodes()[1]:getNode(), is(concreteNode))

	assertThat(subject:execute(parse), is(42))
	Mockito.verify(command, any())
end)

CommandDispatcherTest:test("testCorrectExecuteContextAfterRedirect", function()
	-- selene: allow(shadowing) -- as in the Java test
	local subject: Types.CommandDispatcher<any> = CommandDispatcher.new()

	local root = subject:getRoot()
	local add = literal("add")
	local blank = literal("blank")
	local addArg = argument("value", integer())
	local run = literal("run")

	subject:register(add:with(addArg:redirect(root, function(c: Types.CommandContext<any>): number
		return c:getSource() + getInteger(c, "value")
	end)))
	subject:register(blank:redirect(root))
	subject:register(run:executes(function(c)
		return c:getSource()
	end))

	assertThat(subject:execute("run", 0), is(0))
	assertThat(subject:execute("run", 1), is(1))

	assertThat(subject:execute("add 5 run", 1), is(1 + 5))
	assertThat(subject:execute("add 5 add 6 run", 2), is(2 + 5 + 6))
	assertThat(subject:execute("add 5 blank run", 1), is(1 + 5))
	assertThat(subject:execute("blank add 5 run", 1), is(1 + 5))
	assertThat(subject:execute("add 5 blank add 6 run", 2), is(2 + 5 + 6))
	assertThat(subject:execute("add 5 blank blank add 6 run", 2), is(2 + 5 + 6))
end)

CommandDispatcherTest:test("testSharedRedirectAndExecuteNodes", function()
	-- selene: allow(shadowing) -- as in the Java test
	local subject: Types.CommandDispatcher<any> = CommandDispatcher.new()

	local root = subject:getRoot()
	local add = literal("add")
	local addArg = argument("value", integer())

	subject:register(add:with(addArg
		:redirect(root, function(c: Types.CommandContext<any>): number
			return c:getSource() + getInteger(c, "value")
		end)
		:executes(function(c)
			return c:getSource()
		end)))

	assertThat(subject:execute("add 5", 1), is(1))
	assertThat(subject:execute("add 5 add 6", 1), is(1 + 5))
end)

CommandDispatcherTest:test("testExecuteRedirected", function()
	local modifier = Mockito.mock("modifier")
	local source1 = newObject("source1")
	local source2 = newObject("source2")

	Mockito.when(modifier, argThat(hasProperty("source", is(source)))):thenReturn({ source1, source2 })

	local concreteNode = subject:register(literal("actual"):executes(command))
	local redirectNode = subject:register(literal("redirected"):fork(subject:getRoot(), modifier))

	local input = "redirected actual"
	local parse = subject:parse(input, source)
	assertThat(parse:getContext():getRange():get(input), equalTo("redirected"))
	assertThat(#parse:getContext():getNodes(), is(1))
	assertThat(parse:getContext():getRootNode(), equalTo(subject:getRoot()))
	assertThat(parse:getContext():getNodes()[1]:getRange(), equalTo(parse:getContext():getRange()))
	assertThat(parse:getContext():getNodes()[1]:getNode(), is(redirectNode))
	assertThat(parse:getContext():getSource(), is(source))

	local parent: Types.CommandContextBuilder<any> = parse:getContext():getChild() :: any
	assertThat(parent, is(notNullValue()))
	assertThat(parent:getRange():get(input), equalTo("actual"))
	assertThat(#parent:getNodes(), is(1))
	assertThat(parse:getContext():getRootNode(), equalTo(subject:getRoot()))
	assertThat(parent:getNodes()[1]:getRange(), equalTo(parent:getRange()))
	assertThat(parent:getNodes()[1]:getNode(), is(concreteNode))
	assertThat(parent:getSource(), is(source))

	assertThat(subject:execute(parse), is(2))
	Mockito.verify(command, argThat(hasProperty("source", is(source1))))
	Mockito.verify(command, argThat(hasProperty("source", is(source2))))
end)

CommandDispatcherTest:test("testIncompleteRedirectShouldThrow", function()
	local foo = subject:register(literal("foo")
		:with(literal("bar"):with(argument("value", integer()):executes(function(context)
			return IntegerArgumentType.getInteger(context, "value")
		end)))
		:with(literal("awa"):executes(function(_context)
			return 2
		end)))
	subject:register(literal("baz"):redirect(foo))
	local e = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("baz bar", source)
	end)
	assertThat(e:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand()))
end)

CommandDispatcherTest:test("testRedirectModifierEmptyResult", function()
	local foo = subject:register(literal("foo")
		:with(literal("bar"):with(argument("value", integer()):executes(function(context)
			return IntegerArgumentType.getInteger(context, "value")
		end)))
		:with(literal("awa"):executes(function(_context)
			return 2
		end)))
	local emptyModifier: Types.RedirectModifier<any> = function(_context)
		return {}
	end
	subject:register(literal("baz"):fork(foo, emptyModifier))
	local result = subject:execute("baz bar 100", source)
	assertThat(result, is(0)) -- No commands executed, so result is 0
end)

CommandDispatcherTest:test("testExecuteOrphanedSubcommand", function()
	subject:register(literal("foo"):with(argument("bar", integer())):executes(command))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("foo 5", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand()))
	assertThat(ex:getCursor(), is(5))
end)

CommandDispatcherTest:test("testExecute_invalidOther", function()
	local wrongCommand = Mockito.mock("wrongCommand")
	subject:register(literal("w"):executes(wrongCommand))
	subject:register(literal("world"):executes(command))

	assertThat(subject:execute("world", source), is(42))
	Mockito.verify(wrongCommand, never(), any())
	Mockito.verify(command, any())
end)

CommandDispatcherTest:test("parse_noSpaceSeparator", function()
	subject:register(literal("foo"):with(argument("bar", integer()):executes(command)))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("foo$", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand()))
	assertThat(ex:getCursor(), is(0))
end)

CommandDispatcherTest:test("testExecuteInvalidSubcommand", function()
	subject:register(literal("foo"):with(argument("bar", integer())):executes(command))

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("foo bar", source)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedInt()))
	assertThat(ex:getCursor(), is(4))
end)

CommandDispatcherTest:test("testGetPath", function()
	local bar = literal("bar"):build()
	subject:register(literal("foo"):with(bar))

	assertThat(subject:getPath(bar), equalTo({ "foo", "bar" }))
end)

CommandDispatcherTest:test("testFindNodeExists", function()
	local bar = literal("bar"):build()
	subject:register(literal("foo"):with(bar))

	assertThat(subject:findNode({ "foo", "bar" }), is(bar))
end)

CommandDispatcherTest:test("testFindNodeDoesntExist", function()
	assertThat(subject:findNode({ "foo", "bar" }), is(nullValue()))
end)

CommandDispatcherTest:test("testResultConsumerInNonErrorRun", function()
	subject:setConsumer(consumer)

	subject:register(literal("foo"):executes(command))
	Mockito.when(command, any()):thenReturn(5)

	assertThat(subject:execute("foo", source), is(5))
	Mockito.verify(consumer, any(), eq(true), eq(5))
	Mockito.verifyNoMoreInteractions(consumer)
end)

CommandDispatcherTest:test("testResultConsumerInForkedNonErrorRun", function()
	subject:setConsumer(consumer)

	subject:register(literal("foo"):executes(function(c)
		return c:getSource()
	end))
	local contexts = { 9, 10, 11 }

	subject:register(literal("repeat"):fork(subject:getRoot(), function(_context)
		return contexts
	end))

	assertThat(subject:execute("repeat foo", source), is(#contexts))
	Mockito.verify(consumer, argThat(CommandDispatcherTest.contextSourceMatches(contexts[1])), eq(true), eq(9))
	Mockito.verify(consumer, argThat(CommandDispatcherTest.contextSourceMatches(contexts[2])), eq(true), eq(10))
	Mockito.verify(consumer, argThat(CommandDispatcherTest.contextSourceMatches(contexts[3])), eq(true), eq(11))
	Mockito.verifyNoMoreInteractions(consumer)
end)

CommandDispatcherTest:test("testExceptionInNonForkedCommand", function()
	subject:setConsumer(consumer)
	subject:register(literal("crash"):executes(command))
	local exception = CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedBool():create()
	Mockito.when(command, any()):thenThrow(exception)

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("crash", source)
	end)
	assertThat(ex, is(exception))

	Mockito.verify(consumer, any(), eq(false), eq(0))
	Mockito.verifyNoMoreInteractions(consumer)
end)

CommandDispatcherTest:test("testExceptionInNonForkedRedirectedCommand", function()
	subject:setConsumer(consumer)
	subject:register(literal("crash"):executes(command))
	subject:register(literal("redirect"):redirect(subject:getRoot()))

	local exception = CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedBool():create()
	Mockito.when(command, any()):thenThrow(exception)

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("redirect crash", source)
	end)
	assertThat(ex, is(exception))

	Mockito.verify(consumer, any(), eq(false), eq(0))
	Mockito.verifyNoMoreInteractions(consumer)
end)

CommandDispatcherTest:test("testExceptionInForkedRedirectedCommand", function()
	subject:setConsumer(consumer)
	subject:register(literal("crash"):executes(command))
	-- Collections::singleton: the modifier returns a collection holding the context itself.
	subject:register(literal("redirect"):fork(subject:getRoot(), function(context)
		return { context }
	end))

	local exception = CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedBool():create()
	Mockito.when(command, any()):thenThrow(exception)

	assertThat(subject:execute("redirect crash", source), is(0))
	Mockito.verify(consumer, any(), eq(false), eq(0))
	Mockito.verifyNoMoreInteractions(consumer)
end)

CommandDispatcherTest:test("testExceptionInNonForkedRedirect", function()
	local exception = CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedBool():create()

	subject:setConsumer(consumer)
	subject:register(literal("noop"):executes(command))
	subject:register(literal("redirect"):redirect(subject:getRoot(), function(_context): any
		error(exception)
	end))

	Mockito.when(command, any()):thenReturn(3)

	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		subject:execute("redirect noop", source)
	end)
	assertThat(ex, is(exception))

	Mockito.verifyZeroInteractions(command)
	Mockito.verify(consumer, any(), eq(false), eq(0))
	Mockito.verifyNoMoreInteractions(consumer)
end)

CommandDispatcherTest:test("testExceptionInForkedRedirect", function()
	local exception = CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedBool():create()

	subject:setConsumer(consumer)
	subject:register(literal("noop"):executes(command))
	subject:register(literal("redirect"):fork(subject:getRoot(), function(_context): { any }
		error(exception)
	end))

	Mockito.when(command, any()):thenReturn(3)

	assertThat(subject:execute("redirect noop", source), is(0))

	Mockito.verifyZeroInteractions(command)
	Mockito.verify(consumer, any(), eq(false), eq(0))
	Mockito.verifyNoMoreInteractions(consumer)
end)

CommandDispatcherTest:test("testPartialExceptionInForkedRedirect", function()
	local exception = CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedBool():create()
	local otherSource = newObject("otherSource")
	local rejectedSource = newObject("rejectedSource")

	subject:setConsumer(consumer)
	subject:register(literal("run"):executes(command))
	subject:register(literal("split"):fork(subject:getRoot(), function(_context)
		return { source, rejectedSource, otherSource }
	end))
	subject:register(literal("filter"):fork(subject:getRoot(), function(context)
		local currentSource = context:getSource()
		if rawequal(currentSource, rejectedSource) then
			error(exception)
		end
		return { currentSource }
	end))

	Mockito.when(command, any()):thenReturn(3)

	assertThat(subject:execute("split filter run", source), is(2))

	Mockito.verify(command, argThat(CommandDispatcherTest.contextSourceMatches(source)))
	Mockito.verify(command, argThat(CommandDispatcherTest.contextSourceMatches(otherSource)))
	Mockito.verifyNoMoreInteractions(command)

	Mockito.verify(consumer, argThat(CommandDispatcherTest.contextSourceMatches(rejectedSource)), eq(false), eq(0))
	Mockito.verify(consumer, argThat(CommandDispatcherTest.contextSourceMatches(source)), eq(true), eq(3))
	Mockito.verify(consumer, argThat(CommandDispatcherTest.contextSourceMatches(otherSource)), eq(true), eq(3))
	Mockito.verifyNoMoreInteractions(consumer)
end)

-- selene: allow(shadowing) -- as in the Java test
CommandDispatcherTest.contextSourceMatches = function(source: unknown): Hamcrest.Matcher
	return Hamcrest.CustomMatcher("source " .. tostring(source), function(object)
		return CommandContext.isInstance(object) and rawequal((object :: any):getSource(), source)
	end)
end

return CommandDispatcherTest
