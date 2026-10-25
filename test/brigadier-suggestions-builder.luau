local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local StringRange = B.StringRange
local Suggestion = B.Suggestion
local SuggestionsBuilder = B.SuggestionsBuilder
local assertThat, is, equalTo, not_ = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo, Hamcrest.not_

local SuggestionsBuilderTest = JUnit.suite("SuggestionsBuilderTest")

local builder: any

-- result.getList().stream().map(Suggestion::getText).collect(Collectors.toList())
local function getTexts(result: any): { string }
	local texts = {}
	for _, suggestion in result:getList() do
		table.insert(texts, (suggestion:getText()))
	end
	return texts
end

SuggestionsBuilderTest:before(function()
	builder = SuggestionsBuilder.new("Hello w", 6)
end)

SuggestionsBuilderTest:test("suggest_appends", function()
	local result = builder:suggest("world!"):build()
	assertThat(result:getList(), equalTo({ Suggestion.new(StringRange:between(6, 7), "world!") }))
	assertThat(result:getRange(), equalTo(StringRange:between(6, 7)))
	assertThat(result:isEmpty(), is(false))
end)

SuggestionsBuilderTest:test("suggest_replaces", function()
	local result = builder:suggest("everybody"):build()
	assertThat(result:getList(), equalTo({ Suggestion.new(StringRange:between(6, 7), "everybody") }))
	assertThat(result:getRange(), equalTo(StringRange:between(6, 7)))
	assertThat(result:isEmpty(), is(false))
end)

SuggestionsBuilderTest:test("suggest_noop", function()
	local result = builder:suggest("w"):build()
	assertThat(result:getList(), equalTo({}))
	assertThat(result:isEmpty(), is(true))
end)

SuggestionsBuilderTest:test("suggest_multiple", function()
	local result = builder:suggest("world!"):suggest("everybody"):suggest("weekend"):build()
	assertThat(
		result:getList(),
		equalTo({
			Suggestion.new(StringRange:between(6, 7), "everybody"),
			Suggestion.new(StringRange:between(6, 7), "weekend"),
			Suggestion.new(StringRange:between(6, 7), "world!"),
		})
	)
	assertThat(result:getRange(), equalTo(StringRange:between(6, 7)))
	assertThat(result:isEmpty(), is(false))
end)

SuggestionsBuilderTest:test("restart", function()
	builder:suggest("won't be included in restart")
	local other = builder:restart()
	assertThat(other, is(not_(builder)))
	assertThat(other:getInput(), equalTo(builder:getInput()))
	assertThat(other:getStart(), is(builder:getStart()))
	assertThat(other:getRemaining(), equalTo(builder:getRemaining()))
end)

SuggestionsBuilderTest:test("sort_alphabetical", function()
	local result = builder:suggest("2"):suggest("4"):suggest("6"):suggest("8"):suggest("30"):suggest("32"):build()
	local actual = getTexts(result)
	assertThat(actual, equalTo({ "2", "30", "32", "4", "6", "8" }))
end)

SuggestionsBuilderTest:test("sort_numerical", function()
	local result = builder:suggest(2):suggest(4):suggest(6):suggest(8):suggest(30):suggest(32):build()
	local actual = getTexts(result)
	assertThat(actual, equalTo({ "2", "4", "6", "8", "30", "32" }))
end)

SuggestionsBuilderTest:test("sort_mixed", function()
	local result = builder
		:suggest("11")
		:suggest("22")
		:suggest("33")
		:suggest("a")
		:suggest("b")
		:suggest("c")
		:suggest(2)
		:suggest(4)
		:suggest(6)
		:suggest(8)
		:suggest(30)
		:suggest(32)
		:suggest("3a")
		:suggest("a3")
		:build()
	local actual = getTexts(result)
	-- The Java test expects { "11", "2", "22", "33", "3a", "4", "6", "8", "30", "32", "a", "a3", "b", "c" }.
	-- Numbers compare by value with each other but by text with words, which isn't a consistent order,
	-- so the result depends on how the sort walks the list. Java's comes from HashSet's hash order and
	-- TimSort; the port keeps insertion order and merge sorts. See docs/porting.md.
	assertThat(actual, equalTo({ "11", "2", "22", "33", "4", "6", "8", "30", "32", "3a", "a", "a3", "b", "c" }))
end)

return SuggestionsBuilderTest:tests()
