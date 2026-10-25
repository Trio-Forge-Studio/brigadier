local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local Mockito = require("./lib/Mockito")
local EqualsTester = require("./lib/EqualsTester")
local AbstractCommandNodeTest = require("./lib/AbstractCommandNode")
local CommandDispatcher = B.CommandDispatcher
local StringReader = B.StringReader
local CommandContextBuilder = B.CommandContextBuilder
local SuggestionsBuilder = B.SuggestionsBuilder
local RootCommandNode = B.RootCommandNode
local literal = B.literal
local assertThat, is = Hamcrest.assertThat, Hamcrest.is
local IllegalStateException = B.IllegalStateException
local UnsupportedOperationException = B.UnsupportedOperationException

local RootCommandNodeTest = JUnit.suite("RootCommandNodeTest")
local node: any

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
	local result = node:listSuggestions(context, SuggestionsBuilder.new("", 0)):expect()
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

return RootCommandNodeTest:tests()
