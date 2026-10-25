local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local Mockito = require("./lib/Mockito")
local contextSourceMatches = require("./lib/contextSourceMatches")
local CommandDispatcher = B.CommandDispatcher
local ContextChain = B.ContextChain
local literal = B.literal
local assertThat, is, notNullValue, nullValue =
	Hamcrest.assertThat, Hamcrest.is, Hamcrest.notNullValue, Hamcrest.nullValue
local any, argThat, eq, mock, verify, verifyNoMoreInteractions, when =
	Mockito.any,
	Mockito.argThat,
	Mockito.eq,
	Mockito.mock,
	Mockito.verify,
	Mockito.verifyNoMoreInteractions,
	Mockito.when

local ContextChainTest = JUnit.suite("ContextChainTest")

ContextChainTest:test("testExecuteAllForSingleCommand", function()
	local consumer = mock("consumer")
	local command = mock("command")

	when(command, any()):thenReturn(4)

	local dispatcher = CommandDispatcher.new()
	dispatcher:register(literal("foo"):executes(command))
	local source = "compile_source"

	local result = dispatcher:parse("foo", source)
	local topContext = result:getContext():build("foo")
	local chain = ContextChain:tryFlatten(topContext) or JUnit.fail()

	local runtimeSource = "runtime_source"
	assertThat(chain:executeAll(runtimeSource, consumer), is(4))

	verify(command, argThat(contextSourceMatches(runtimeSource)))

	verify(consumer, argThat(contextSourceMatches(runtimeSource)), eq(true), eq(4))
	verifyNoMoreInteractions(consumer)
end)

ContextChainTest:test("testExecuteAllForRedirectedCommand", function()
	local consumer = mock("consumer")
	local command = mock("command")

	when(command, any()):thenReturn(4)

	local redirectedSource = "redirected_source"

	local dispatcher = CommandDispatcher.new()
	dispatcher:register(literal("foo"):executes(command))
	dispatcher:register(literal("bar"):redirect(dispatcher:getRoot(), function(_context)
		return redirectedSource
	end))
	local source = "compile_source"

	local result = dispatcher:parse("bar foo", source)
	local topContext = result:getContext():build("bar foo")
	local chain = ContextChain:tryFlatten(topContext) or JUnit.fail()

	local runtimeSource = "runtime_source"
	assertThat(chain:executeAll(runtimeSource, consumer), is(4))

	verify(command, argThat(contextSourceMatches(redirectedSource)))

	verify(consumer, argThat(contextSourceMatches(redirectedSource)), eq(true), eq(4))
	verifyNoMoreInteractions(consumer)
end)

ContextChainTest:test("testSingleStageExecution", function()
	local dispatcher = CommandDispatcher.new()
	dispatcher:register(literal("foo"):executes(function(_context)
		return 1
	end))
	local source = {}

	local result = dispatcher:parse("foo", source)
	local topContext = result:getContext():build("foo")
	local chain = ContextChain:tryFlatten(topContext) or JUnit.fail()

	assertThat(chain:getStage(), is(ContextChain.Stage.EXECUTE))
	assertThat(chain:getTopContext(), is(topContext))
	assertThat(chain:nextStage(), nullValue())
end)

ContextChainTest:test("testMultiStageExecution", function()
	local dispatcher = CommandDispatcher.new()
	dispatcher:register(literal("foo"):executes(function(_context)
		return 1
	end))
	dispatcher:register(literal("bar"):redirect(dispatcher:getRoot()))
	local source = {}

	local result = dispatcher:parse("bar bar foo", source)
	local topContext = result:getContext():build("bar bar foo")
	local stage0 = ContextChain:tryFlatten(topContext) or JUnit.fail()

	assertThat(stage0:getStage(), is(ContextChain.Stage.MODIFY))
	assertThat(stage0:getTopContext(), is(topContext))

	local stage1 = stage0:nextStage()
	assertThat(stage1, notNullValue())
	assertThat(stage1:getStage(), is(ContextChain.Stage.MODIFY))
	assertThat(stage1:getTopContext(), is(topContext:getChild()))

	local stage2 = stage1:nextStage()
	assertThat(stage2, notNullValue())
	assertThat(stage2:getStage(), is(ContextChain.Stage.EXECUTE))
	assertThat(stage2:getTopContext(), is(topContext:getChild():getChild()))

	assertThat(stage2:nextStage(), nullValue())
end)

ContextChainTest:test("testMissingExecute", function()
	local dispatcher = CommandDispatcher.new()
	dispatcher:register(literal("foo"):executes(function(_context)
		return 1
	end))
	dispatcher:register(literal("bar"):redirect(dispatcher:getRoot()))

	local source = {}
	local result = dispatcher:parse("bar bar", source)
	local topContext = result:getContext():build("bar bar")
	-- Optional.empty() is nil.
	assertThat(ContextChain:tryFlatten(topContext), is(nil))
end)

return ContextChainTest:tests()
