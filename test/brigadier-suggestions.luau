local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local StringRange = B.StringRange
local Suggestion = B.Suggestion
local Suggestions = B.Suggestions
local assertThat, is, equalTo = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo

local SuggestionsTest = JUnit.suite("SuggestionsTest")

SuggestionsTest:test("merge_empty", function()
	local merged = Suggestions:merge("foo b", {})
	assertThat(merged:isEmpty(), is(true))
end)

SuggestionsTest:test("merge_single", function()
	local suggestions = Suggestions.new(StringRange:at(5), { Suggestion.new(StringRange:at(5), "ar") })
	local merged = Suggestions:merge("foo b", { suggestions })
	assertThat(merged, equalTo(suggestions))
end)

SuggestionsTest:test("merge_multiple", function()
	local a = Suggestions.new(StringRange:at(5), {
		Suggestion.new(StringRange:at(5), "ar"),
		Suggestion.new(StringRange:at(5), "az"),
		Suggestion.new(StringRange:at(5), "Az"),
	})
	local b = Suggestions.new(StringRange:between(4, 5), {
		Suggestion.new(StringRange:between(4, 5), "foo"),
		Suggestion.new(StringRange:between(4, 5), "qux"),
		Suggestion.new(StringRange:between(4, 5), "apple"),
		Suggestion.new(StringRange:between(4, 5), "Bar"),
	})
	local merged = Suggestions:merge("foo b", { a, b })
	assertThat(
		merged:getList(),
		equalTo({
			Suggestion.new(StringRange:between(4, 5), "apple"),
			Suggestion.new(StringRange:between(4, 5), "bar"),
			Suggestion.new(StringRange:between(4, 5), "Bar"),
			Suggestion.new(StringRange:between(4, 5), "baz"),
			Suggestion.new(StringRange:between(4, 5), "bAz"),
			Suggestion.new(StringRange:between(4, 5), "foo"),
			Suggestion.new(StringRange:between(4, 5), "qux"),
		})
	)
end)

return SuggestionsTest:tests()
