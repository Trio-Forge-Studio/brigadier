local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local Mockito = require("./lib/Mockito")
local EqualsTester = require("./lib/EqualsTester")
local CommandContextBuilder = B.CommandContextBuilder
local ParsedArgument = B.ParsedArgument
local StringRange = B.StringRange
local IllegalArgumentException = B.IllegalArgumentException
local assertThat, is = Hamcrest.assertThat, Hamcrest.is
local mock, mockObject = Mockito.mock, Mockito.mockObject

local CommandContextTest = JUnit.suite("CommandContextTest")

local builder: any
local source: any
local dispatcher: any
local rootNode: any

CommandContextTest:before(function()
	source = mockObject("source")
	dispatcher = mockObject("dispatcher")
	rootNode = mockObject("rootNode")
	builder = CommandContextBuilder.new(dispatcher, source, rootNode, 0)
end)

CommandContextTest:test("testGetArgument_nonexistent", function()
	JUnit.assertThrows(IllegalArgumentException, function()
		-- Object.class: Java's Object accepts any value; "any" stands in for it.
		builder:build(""):getArgument("foo", "any")
	end)
end)

CommandContextTest:test("testGetArgument_wrongType", function()
	JUnit.assertThrows(IllegalArgumentException, function()
		local context = builder:withArgument("foo", ParsedArgument.new(0, 1, 123)):build("123")
		context:getArgument("foo", "string")
	end)
end)

CommandContextTest:test("testGetArgument", function()
	local context = builder:withArgument("foo", ParsedArgument.new(0, 1, 123)):build("123")
	assertThat(context:getArgument("foo", "number"), is(123))
end)

CommandContextTest:test("testSource", function()
	assertThat(builder:build(""):getSource(), is(source))
end)

CommandContextTest:test("testRootNode", function()
	assertThat(builder:build(""):getRootNode(), is(rootNode))
end)

CommandContextTest:test("testEquals", function()
	local otherSource = {}
	local command = mock("command")
	local otherCommand = mock("otherCommand")
	-- selene: allow(shadowing) -- as in the Java test
	local rootNode = mockObject("rootNode")
	local otherRootNode = mockObject("otherRootNode")
	local node = mockObject("node")
	local otherNode = mockObject("otherNode")
	EqualsTester.new()
		:addEqualityGroup(
			CommandContextBuilder.new(dispatcher, source, rootNode, 0):build(""),
			CommandContextBuilder.new(dispatcher, source, rootNode, 0):build("")
		)
		:addEqualityGroup(
			CommandContextBuilder.new(dispatcher, source, otherRootNode, 0):build(""),
			CommandContextBuilder.new(dispatcher, source, otherRootNode, 0):build("")
		)
		:addEqualityGroup(
			CommandContextBuilder.new(dispatcher, otherSource, rootNode, 0):build(""),
			CommandContextBuilder.new(dispatcher, otherSource, rootNode, 0):build("")
		)
		:addEqualityGroup(
			CommandContextBuilder.new(dispatcher, source, rootNode, 0):withCommand(command):build(""),
			CommandContextBuilder.new(dispatcher, source, rootNode, 0):withCommand(command):build("")
		)
		:addEqualityGroup(
			CommandContextBuilder.new(dispatcher, source, rootNode, 0):withCommand(otherCommand):build(""),
			CommandContextBuilder.new(dispatcher, source, rootNode, 0):withCommand(otherCommand):build("")
		)
		:addEqualityGroup(
			CommandContextBuilder.new(dispatcher, source, rootNode, 0)
				:withArgument("foo", ParsedArgument.new(0, 1, 123))
				:build("123"),
			CommandContextBuilder.new(dispatcher, source, rootNode, 0)
				:withArgument("foo", ParsedArgument.new(0, 1, 123))
				:build("123")
		)
		:addEqualityGroup(
			CommandContextBuilder.new(dispatcher, source, rootNode, 0)
				:withNode(node, StringRange:between(0, 3))
				:withNode(otherNode, StringRange:between(4, 6))
				:build("123 456"),
			CommandContextBuilder.new(dispatcher, source, rootNode, 0)
				:withNode(node, StringRange:between(0, 3))
				:withNode(otherNode, StringRange:between(4, 6))
				:build("123 456")
		)
		:addEqualityGroup(
			CommandContextBuilder.new(dispatcher, source, rootNode, 0)
				:withNode(otherNode, StringRange:between(0, 3))
				:withNode(node, StringRange:between(4, 6))
				:build("123 456"),
			CommandContextBuilder.new(dispatcher, source, rootNode, 0)
				:withNode(otherNode, StringRange:between(0, 3))
				:withNode(node, StringRange:between(4, 6))
				:build("123 456")
		)
		:testEquals()
end)

return CommandContextTest:tests()
