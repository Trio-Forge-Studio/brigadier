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
local integer = B.integer
local argument = B.argument
local assertThat, is = Hamcrest.assertThat, Hamcrest.is

local ArgumentCommandNodeTest = JUnit.suite("ArgumentCommandNodeTest")
local node: any
local contextBuilder: any

AbstractCommandNodeTest(ArgumentCommandNodeTest, function()
	return node
end)

ArgumentCommandNodeTest:before(function()
	node = argument("foo", integer()):build()
	contextBuilder = CommandContextBuilder.new(CommandDispatcher.new(), {}, RootCommandNode.new(), 0)
end)

ArgumentCommandNodeTest:test("testParse", function()
	local reader = StringReader.new("123 456")
	node:parse(reader, contextBuilder)

	assertThat(contextBuilder:getArguments()["foo"] ~= nil, is(true))
	assertThat(contextBuilder:getArguments()["foo"]:getResult(), is(123))
end)

ArgumentCommandNodeTest:test("testUsage", function()
	assertThat(node:getUsageText(), is("<foo>"))
end)

ArgumentCommandNodeTest:test("testSuggestions", function()
	local result = node:listSuggestions(contextBuilder:build(""), SuggestionsBuilder.new("", 0)):expect()
	assertThat(result:isEmpty(), is(true))
end)

ArgumentCommandNodeTest:test("testEquals", function()
	local command = Mockito.mock()

	EqualsTester.new()
		:addEqualityGroup(argument("foo", integer()):build(), argument("foo", integer()):build())
		:addEqualityGroup(
			argument("foo", integer()):executes(command):build(),
			argument("foo", integer()):executes(command):build()
		)
		:addEqualityGroup(argument("bar", integer(-100, 100)):build(), argument("bar", integer(-100, 100)):build())
		:addEqualityGroup(argument("foo", integer(-100, 100)):build(), argument("foo", integer(-100, 100)):build())
		:addEqualityGroup(
			argument("foo", integer()):with(argument("bar", integer())):build(),
			argument("foo", integer()):with(argument("bar", integer())):build()
		)
		:testEquals()
end)

ArgumentCommandNodeTest:test("testCreateBuilder", function()
	local builder = node:createBuilder()
	assertThat(builder:getName(), is(node:getName()))
	assertThat(builder:getType(), is(node:getType()))
	assertThat(builder:getRequirement(), is(node:getRequirement()))
	assertThat(builder:getCommand(), is(node:getCommand()))
end)

return ArgumentCommandNodeTest:tests()
