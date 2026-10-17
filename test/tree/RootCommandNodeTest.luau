--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local Types = require("@brigadier/Types")
local EqualsTester = require("@test/lib/EqualsTester")
local AbstractCommandNodeTest = require("./AbstractCommandNode")
local CommandDispatcher = require("@brigadier/CommandDispatcher")
local StringReader = require("@brigadier/StringReader")
local LiteralArgumentBuilder = require("@brigadier/builder/LiteralArgumentBuilder")
local CommandContextBuilder = require("@brigadier/context/CommandContextBuilder")
local SuggestionsBuilder = require("@brigadier/suggestion/SuggestionsBuilder")
local RootCommandNode = require("@brigadier/tree/RootCommandNode")
local RuntimeException = require("@brigadier/util/RuntimeException")
local literal = LiteralArgumentBuilder.literal
local assertThat, is = Hamcrest.assertThat, Hamcrest.is
local IllegalStateException = RuntimeException.IllegalStateException
local UnsupportedOperationException = RuntimeException.UnsupportedOperationException

local RootCommandNodeTest = JUnit.suite("RootCommandNodeTest")
local node: Types.RootCommandNode<any>

AbstractCommandNodeTest(RootCommandNodeTest, function()
	return node
end)

RootCommandNodeTest:before(function()
	node = RootCommandNode.new()
end)

RootCommandNodeTest:test("testParse", function()
	local reader = StringReader.new("hello world")
	node:parse(reader, CommandContextBuilder.new(CommandDispatcher.new(), {}, RootCommandNode.new(), 0))
	assertThat(reader:getCursor(), is(0))
end)

RootCommandNodeTest:test("testAddChildNoRoot", function()
	JUnit.assertThrows(UnsupportedOperationException, function()
		node:addChild(RootCommandNode.new())
	end)
end)

RootCommandNodeTest:test("testUsage", function()
	assertThat(node:getUsageText(), is(""))
end)

RootCommandNodeTest:test("testSuggestions", function()
	local context = Mockito.mockObject()
	local result = node:listSuggestions(context, SuggestionsBuilder.new("", 0)):join()
	assertThat(result:isEmpty(), is(true))
end)

RootCommandNodeTest:test("testCreateBuilder", function()
	JUnit.assertThrows(IllegalStateException, function()
		node:createBuilder()
	end)
end)

RootCommandNodeTest:test("testEquals", function()
	-- Java's `new RootCommandNode<Object>() {{ addChild(literal("foo").build()); }}` is an anonymous
	-- subclass that adds a child as it is built.
	local function rootWithFoo()
		local root = RootCommandNode.new()
		root:addChild(literal("foo"):build())
		return root
	end

	EqualsTester.new()
		:addEqualityGroup(RootCommandNode.new(), RootCommandNode.new())
		:addEqualityGroup(rootWithFoo(), rootWithFoo())
		:testEquals()
end)

return RootCommandNodeTest
