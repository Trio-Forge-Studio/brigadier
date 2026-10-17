--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local EqualsTester = require("@test/lib/EqualsTester")
local AbstractCommandNodeTest = require("./AbstractCommandNode")
local Types = require("@brigadier/Types")
local CommandDispatcher = require("@brigadier/CommandDispatcher")
local StringReader = require("@brigadier/StringReader")
local IntegerArgumentType = require("@brigadier/arguments/IntegerArgumentType")
local RequiredArgumentBuilder = require("@brigadier/builder/RequiredArgumentBuilder")
local CommandContextBuilder = require("@brigadier/context/CommandContextBuilder")
local SuggestionsBuilder = require("@brigadier/suggestion/SuggestionsBuilder")
local RootCommandNode = require("@brigadier/tree/RootCommandNode")
local integer = IntegerArgumentType.integer
local argument = RequiredArgumentBuilder.argument
local assertThat, is = Hamcrest.assertThat, Hamcrest.is

local ArgumentCommandNodeTest = JUnit.suite("ArgumentCommandNodeTest")
local node: Types.ArgumentCommandNode<any, number>
local contextBuilder: Types.CommandContextBuilder<any>

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
	local result = node:listSuggestions(contextBuilder:build(""), SuggestionsBuilder.new("", 0)):join()
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

return ArgumentCommandNodeTest
