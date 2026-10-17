--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local StringRange = require("@brigadier/context/StringRange")
local Suggestion = require("@brigadier/suggestion/Suggestion")
local assertThat, equalTo = Hamcrest.assertThat, Hamcrest.equalTo

local SuggestionTest = JUnit.suite("SuggestionTest")

SuggestionTest:test("apply_insertation_start", function()
	local suggestion = Suggestion.new(StringRange.at(0), "And so I said: ")
	assertThat(suggestion:apply("Hello world!"), equalTo("And so I said: Hello world!"))
end)

SuggestionTest:test("apply_insertation_middle", function()
	local suggestion = Suggestion.new(StringRange.at(6), "small ")
	assertThat(suggestion:apply("Hello world!"), equalTo("Hello small world!"))
end)

SuggestionTest:test("apply_insertation_end", function()
	local suggestion = Suggestion.new(StringRange.at(5), " world!")
	assertThat(suggestion:apply("Hello"), equalTo("Hello world!"))
end)

SuggestionTest:test("apply_replacement_start", function()
	local suggestion = Suggestion.new(StringRange.between(0, 5), "Goodbye")
	assertThat(suggestion:apply("Hello world!"), equalTo("Goodbye world!"))
end)

SuggestionTest:test("apply_replacement_middle", function()
	local suggestion = Suggestion.new(StringRange.between(6, 11), "Alex")
	assertThat(suggestion:apply("Hello world!"), equalTo("Hello Alex!"))
end)

SuggestionTest:test("apply_replacement_end", function()
	local suggestion = Suggestion.new(StringRange.between(6, 12), "Creeper!")
	assertThat(suggestion:apply("Hello world!"), equalTo("Hello Creeper!"))
end)

SuggestionTest:test("apply_replacement_everything", function()
	local suggestion = Suggestion.new(StringRange.between(0, 12), "Oh dear.")
	assertThat(suggestion:apply("Hello world!"), equalTo("Oh dear."))
end)

SuggestionTest:test("expand_unchanged", function()
	local suggestion = Suggestion.new(StringRange.at(1), "oo")
	assertThat(suggestion:expand("f", StringRange.at(1)), equalTo(suggestion))
end)

SuggestionTest:test("expand_left", function()
	local suggestion = Suggestion.new(StringRange.at(1), "oo")
	assertThat(
		suggestion:expand("f", StringRange.between(0, 1)),
		equalTo(Suggestion.new(StringRange.between(0, 1), "foo"))
	)
end)

SuggestionTest:test("expand_right", function()
	local suggestion = Suggestion.new(StringRange.at(0), "minecraft:")
	assertThat(
		suggestion:expand("fish", StringRange.between(0, 4)),
		equalTo(Suggestion.new(StringRange.between(0, 4), "minecraft:fish"))
	)
end)

SuggestionTest:test("expand_both", function()
	local suggestion = Suggestion.new(StringRange.at(11), "minecraft:")
	assertThat(
		suggestion:expand("give Steve fish_block", StringRange.between(5, 21)),
		equalTo(Suggestion.new(StringRange.between(5, 21), "Steve minecraft:fish_block"))
	)
end)

SuggestionTest:test("expand_replacement", function()
	local suggestion = Suggestion.new(StringRange.between(6, 11), "strangers")
	assertThat(
		suggestion:expand("Hello world!", StringRange.between(0, 12)),
		equalTo(Suggestion.new(StringRange.between(0, 12), "Hello strangers!"))
	)
end)

return SuggestionTest
