--!nolint LocalUnused
local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local Mockito = require("./lib/Mockito")
local EqualsTester = require("./lib/EqualsTester")
local AbstractCommandNodeTest = require("./lib/AbstractCommandNode")
local CommandDispatcher = B.CommandDispatcher
local StringReader = B.StringReader
local CommandContextBuilder = B.CommandContextBuilder
local StringRange = B.StringRange
local CommandSyntaxException = B.CommandSyntaxException
local Suggestion = B.Suggestion
local SuggestionsBuilder = B.SuggestionsBuilder
local RootCommandNode = B.RootCommandNode
local literal = B.literal
local assertThat, is, equalTo = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo

local LiteralCommandNodeTest = JUnit.suite("LiteralCommandNodeTest")
local node: any
local contextBuilder: any

AbstractCommandNodeTest(LiteralCommandNodeTest, function()
	return node
end)

LiteralCommandNodeTest:before(function()
	node = literal("foo"):build()
	contextBuilder = CommandContextBuilder.new(CommandDispatcher.new(), {}, RootCommandNode.new(), 0)
end)

LiteralCommandNodeTest:test("testParse", function()
	local reader = StringReader.new("foo bar")
	node:parse(reader, contextBuilder)
	assertThat(reader:getRemaining(), equalTo(" bar"))
end)

LiteralCommandNodeTest:test("testParseExact", function()
	local reader = StringReader.new("foo")
	node:parse(reader, contextBuilder)
	assertThat(reader:getRemaining(), equalTo(""))
end)

LiteralCommandNodeTest:test("testParseSimilar", function()
	local reader = StringReader.new("foobar")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		node:parse(reader, contextBuilder)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:literalIncorrect()))
	assertThat(ex:getCursor(), is(0))
end)

LiteralCommandNodeTest:test("testParseInvalid", function()
	local reader = StringReader.new("bar")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		node:parse(reader, contextBuilder)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:literalIncorrect()))
	assertThat(ex:getCursor(), is(0))
end)

LiteralCommandNodeTest:test("testUsage", function()
	assertThat(node:getUsageText(), is("foo"))
end)

LiteralCommandNodeTest:test("testSuggestions", function()
	local empty = node:listSuggestions(contextBuilder:build(""), SuggestionsBuilder.new("", 0)):expect()
	assertThat(empty:getList(), equalTo({ Suggestion.new(StringRange:at(0), "foo") }))

	local foo = node:listSuggestions(contextBuilder:build("foo"), SuggestionsBuilder.new("foo", 0)):expect()
	assertThat(foo:isEmpty(), is(true))

	local food = node:listSuggestions(contextBuilder:build("food"), SuggestionsBuilder.new("food", 0)):expect()
	assertThat(food:isEmpty(), is(true))

	-- selene: allow(unused_variable) -- as in the Java test
	local b = node:listSuggestions(contextBuilder:build("b"), SuggestionsBuilder.new("b", 0)):expect()
	assertThat(food:isEmpty(), is(true))
end)

LiteralCommandNodeTest:test("testEquals", function()
	local command = Mockito.mock()

	EqualsTester.new()
		:addEqualityGroup(literal("foo"):build(), literal("foo"):build())
		:addEqualityGroup(literal("bar"):executes(command):build(), literal("bar"):executes(command):build())
		:addEqualityGroup(literal("bar"):build(), literal("bar"):build())
		:addEqualityGroup(literal("foo"):with(literal("bar")):build(), literal("foo"):with(literal("bar")):build())
		:testEquals()
end)

LiteralCommandNodeTest:test("testCreateBuilder", function()
	local builder = node:createBuilder()
	assertThat(builder:getLiteral(), is(node:getLiteral()))
	assertThat(builder:getRequirement(), is(node:getRequirement()))
	assertThat(builder:getCommand(), is(node:getCommand()))
end)

return LiteralCommandNodeTest:tests()
