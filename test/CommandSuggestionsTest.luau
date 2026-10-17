--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local Types = require("@brigadier/Types")
local CommandDispatcher = require("@brigadier/CommandDispatcher")
local StringReader = require("@brigadier/StringReader")
local IntegerArgumentType = require("@brigadier/arguments/IntegerArgumentType")
local StringArgumentType = require("@brigadier/arguments/StringArgumentType")
local LiteralArgumentBuilder = require("@brigadier/builder/LiteralArgumentBuilder")
local RequiredArgumentBuilder = require("@brigadier/builder/RequiredArgumentBuilder")
local StringRange = require("@brigadier/context/StringRange")
local Suggestion = require("@brigadier/suggestion/Suggestion")

local assertThat, is, equalTo = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo
local integer = IntegerArgumentType.integer
local word = StringArgumentType.word
local literal = LiteralArgumentBuilder.literal
local argument = RequiredArgumentBuilder.argument

local CommandSuggestionsTest = JUnit.suite("CommandSuggestionsTest")
local subject: Types.CommandDispatcher<any>
local source: any

CommandSuggestionsTest:before(function()
	source = Mockito.mockObject("source")

	subject = CommandDispatcher.new()
end)

local function testSuggestions(contents: string, cursor: number, range: Types.StringRange, ...: string)
	local result = subject:getCompletionSuggestions(subject:parse(contents, source), cursor):join()
	assertThat(result:getRange(), equalTo(range))

	local expected: { Types.Suggestion } = {}
	for _, suggestion in { ... } do
		table.insert(expected, Suggestion.new(range, suggestion))
	end

	assertThat(result:getList(), equalTo(expected))
end

local function inputWithOffset(input: string, offset: number): Types.StringReader
	local result = StringReader.new(input)
	result:setCursor(offset)
	return result
end

CommandSuggestionsTest:test("getCompletionSuggestions_rootCommands", function()
	subject:register(literal("foo"))
	subject:register(literal("bar"))
	subject:register(literal("baz"))

	local result = subject:getCompletionSuggestions(subject:parse("", source)):join()

	assertThat(result:getRange(), equalTo(StringRange.at(0)))
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange.at(0), "bar"),
			Suggestion.new(StringRange.at(0), "baz"),
			Suggestion.new(StringRange.at(0), "foo"),
		})
	)
end)

CommandSuggestionsTest:test("getCompletionSuggestions_rootCommands_withInputOffset", function()
	subject:register(literal("foo"))
	subject:register(literal("bar"))
	subject:register(literal("baz"))

	local result = subject:getCompletionSuggestions(subject:parse(inputWithOffset("OOO", 3), source)):join()

	assertThat(result:getRange(), equalTo(StringRange.at(3)))
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange.at(3), "bar"),
			Suggestion.new(StringRange.at(3), "baz"),
			Suggestion.new(StringRange.at(3), "foo"),
		})
	)
end)

CommandSuggestionsTest:test("getCompletionSuggestions_rootCommands_partial", function()
	subject:register(literal("foo"))
	subject:register(literal("bar"))
	subject:register(literal("baz"))

	local result = subject:getCompletionSuggestions(subject:parse("b", source)):join()

	assertThat(result:getRange(), equalTo(StringRange.between(0, 1)))
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange.between(0, 1), "bar"),
			Suggestion.new(StringRange.between(0, 1), "baz"),
		})
	)
end)

CommandSuggestionsTest:test("getCompletionSuggestions_rootCommands_partial_withInputOffset", function()
	subject:register(literal("foo"))
	subject:register(literal("bar"))
	subject:register(literal("baz"))

	local result = subject:getCompletionSuggestions(subject:parse(inputWithOffset("Zb", 1), source)):join()

	assertThat(result:getRange(), equalTo(StringRange.between(1, 2)))
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange.between(1, 2), "bar"),
			Suggestion.new(StringRange.between(1, 2), "baz"),
		})
	)
end)

CommandSuggestionsTest:test("getCompletionSuggestions_subCommands", function()
	subject:register(literal("parent"):with(literal("foo")):with(literal("bar")):with(literal("baz")))

	local result = subject:getCompletionSuggestions(subject:parse("parent ", source)):join()

	assertThat(result:getRange(), equalTo(StringRange.at(7)))
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange.at(7), "bar"),
			Suggestion.new(StringRange.at(7), "baz"),
			Suggestion.new(StringRange.at(7), "foo"),
		})
	)
end)

CommandSuggestionsTest:test("getCompletionSuggestions_movingCursor_subCommands", function()
	subject:register(literal("parent_one"):with(literal("faz")):with(literal("fbz")):with(literal("gaz")))

	subject:register(literal("parent_two"))

	testSuggestions("parent_one faz ", 0, StringRange.at(0), "parent_one", "parent_two")
	testSuggestions("parent_one faz ", 1, StringRange.between(0, 1), "parent_one", "parent_two")
	testSuggestions("parent_one faz ", 7, StringRange.between(0, 7), "parent_one", "parent_two")
	testSuggestions("parent_one faz ", 8, StringRange.between(0, 8), "parent_one")
	testSuggestions("parent_one faz ", 10, StringRange.at(0))
	testSuggestions("parent_one faz ", 11, StringRange.at(11), "faz", "fbz", "gaz")
	testSuggestions("parent_one faz ", 12, StringRange.between(11, 12), "faz", "fbz")
	testSuggestions("parent_one faz ", 13, StringRange.between(11, 13), "faz")
	testSuggestions("parent_one faz ", 14, StringRange.at(0))
	testSuggestions("parent_one faz ", 15, StringRange.at(0))
end)

CommandSuggestionsTest:test("getCompletionSuggestions_subCommands_partial", function()
	subject:register(literal("parent"):with(literal("foo")):with(literal("bar")):with(literal("baz")))

	local parse = subject:parse("parent b", source)
	local result = subject:getCompletionSuggestions(parse):join()

	assertThat(result:getRange(), equalTo(StringRange.between(7, 8)))
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange.between(7, 8), "bar"),
			Suggestion.new(StringRange.between(7, 8), "baz"),
		})
	)
end)

CommandSuggestionsTest:test("getCompletionSuggestions_subCommands_partial_withInputOffset", function()
	subject:register(literal("parent"):with(literal("foo")):with(literal("bar")):with(literal("baz")))

	local parse = subject:parse(inputWithOffset("junk parent b", 5), source)
	local result = subject:getCompletionSuggestions(parse):join()

	assertThat(result:getRange(), equalTo(StringRange.between(12, 13)))
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange.between(12, 13), "bar"),
			Suggestion.new(StringRange.between(12, 13), "baz"),
		})
	)
end)

CommandSuggestionsTest:test("getCompletionSuggestions_redirect", function()
	local actual = subject:register(literal("actual"):with(literal("sub")))
	subject:register(literal("redirect"):redirect(actual))

	local parse = subject:parse("redirect ", source)
	local result = subject:getCompletionSuggestions(parse):join()

	assertThat(result:getRange(), equalTo(StringRange.at(9)))
	assertThat(result:getList(), equalTo({ Suggestion.new(StringRange.at(9), "sub") }))
end)

CommandSuggestionsTest:test("getCompletionSuggestions_redirectPartial", function()
	local actual = subject:register(literal("actual"):with(literal("sub")))
	subject:register(literal("redirect"):redirect(actual))

	local parse = subject:parse("redirect s", source)
	local result = subject:getCompletionSuggestions(parse):join()

	assertThat(result:getRange(), equalTo(StringRange.between(9, 10)))
	assertThat(result:getList(), equalTo({ Suggestion.new(StringRange.between(9, 10), "sub") }))
end)

CommandSuggestionsTest:test("getCompletionSuggestions_movingCursor_redirect", function()
	local actualOne =
		subject:register(literal("actual_one"):with(literal("faz")):with(literal("fbz")):with(literal("gaz")))

	local _actualTwo = subject:register(literal("actual_two"))

	subject:register(literal("redirect_one"):redirect(actualOne))
	subject:register(literal("redirect_two"):redirect(actualOne))

	testSuggestions(
		"redirect_one faz ",
		0,
		StringRange.at(0),
		"actual_one",
		"actual_two",
		"redirect_one",
		"redirect_two"
	)
	testSuggestions("redirect_one faz ", 9, StringRange.between(0, 9), "redirect_one", "redirect_two")
	testSuggestions("redirect_one faz ", 10, StringRange.between(0, 10), "redirect_one")
	testSuggestions("redirect_one faz ", 12, StringRange.at(0))
	testSuggestions("redirect_one faz ", 13, StringRange.at(13), "faz", "fbz", "gaz")
	testSuggestions("redirect_one faz ", 14, StringRange.between(13, 14), "faz", "fbz")
	testSuggestions("redirect_one faz ", 15, StringRange.between(13, 15), "faz")
	testSuggestions("redirect_one faz ", 16, StringRange.at(0))
	testSuggestions("redirect_one faz ", 17, StringRange.at(0))
end)

CommandSuggestionsTest:test("getCompletionSuggestions_redirectPartial_withInputOffset", function()
	local actual = subject:register(literal("actual"):with(literal("sub")))
	subject:register(literal("redirect"):redirect(actual))

	local parse = subject:parse(inputWithOffset("/redirect s", 1), source)
	local result = subject:getCompletionSuggestions(parse):join()

	assertThat(result:getRange(), equalTo(StringRange.between(10, 11)))
	assertThat(result:getList(), equalTo({ Suggestion.new(StringRange.between(10, 11), "sub") }))
end)

CommandSuggestionsTest:test("getCompletionSuggestions_redirect_lots", function()
	local loop = subject:register(literal("redirect"))
	subject:register(literal("redirect"):with(literal("loop"):with(argument("loop", integer()):redirect(loop))))

	local result = subject:getCompletionSuggestions(subject:parse("redirect loop 1 loop 02 loop 003 ", source)):join()

	assertThat(result:getRange(), equalTo(StringRange.at(33)))
	assertThat(result:getList(), equalTo({ Suggestion.new(StringRange.at(33), "loop") }))
end)

CommandSuggestionsTest:test("getCompletionSuggestions_redirect_contextualArgument", function()
	local actual = subject:register(
		literal("actual"):with(
			argument("arg_one", word()):with(
				argument("arg_two", word()):suggests(
					function(context: Types.CommandContext<any>, builder: Types.SuggestionsBuilder)
						local argOne = StringArgumentType.getString(context, "arg_one")
						builder:suggest("contextual_" .. argOne)
						return builder:buildFuture()
					end
				)
			)
		)
	)
	subject:register(literal("redirect"):redirect(actual))

	local result = subject:getCompletionSuggestions(subject:parse("redirect first ", source)):join()

	assertThat(result:getRange(), equalTo(StringRange.at(15)))
	assertThat(result:getList(), equalTo({ Suggestion.new(StringRange.at(15), "contextual_first") }))
end)

CommandSuggestionsTest:test("getCompletionSuggestions_execute_simulation", function()
	local execute = subject:register(literal("execute"))
	subject:register(
		literal("execute")
			:with(literal("as"):with(argument("name", word()):redirect(execute)))
			:with(literal("store"):with(argument("name", word()):redirect(execute)))
			:with(literal("run"):executes(function(_c)
				return 0
			end))
	)

	local parse = subject:parse("execute as Dinnerbone as", source)
	local result = subject:getCompletionSuggestions(parse):join()

	assertThat(result:isEmpty(), is(true))
end)

CommandSuggestionsTest:test("getCompletionSuggestions_execute_simulation_partial", function()
	local execute = subject:register(literal("execute"))
	subject:register(
		literal("execute")
			:with(literal("as"):with(literal("bar"):redirect(execute)):with(literal("baz"):redirect(execute)))
			:with(literal("store"):with(argument("name", word()):redirect(execute)))
			:with(literal("run"):executes(function(_c)
				return 0
			end))
	)

	local parse = subject:parse("execute as bar as ", source)
	local result = subject:getCompletionSuggestions(parse):join()

	assertThat(result:getRange(), equalTo(StringRange.at(18)))
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange.at(18), "bar"),
			Suggestion.new(StringRange.at(18), "baz"),
		})
	)
end)

return CommandSuggestionsTest
