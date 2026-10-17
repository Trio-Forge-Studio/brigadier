--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local EqualsTester = require("@test/lib/EqualsTester")
local StringReader = require("@brigadier/StringReader")
local ParsedArgument = require("@brigadier/context/ParsedArgument")
local assertThat, equalTo = Hamcrest.assertThat, Hamcrest.equalTo

local ParsedArgumentTest = JUnit.suite("ParsedArgumentTest")

ParsedArgumentTest:test("testEquals", function()
	EqualsTester.new()
		:addEqualityGroup(ParsedArgument.new(0, 3, "bar"), ParsedArgument.new(0, 3, "bar"))
		:addEqualityGroup(ParsedArgument.new(3, 6, "baz"), ParsedArgument.new(3, 6, "baz"))
		:addEqualityGroup(ParsedArgument.new(6, 9, "baz"), ParsedArgument.new(6, 9, "baz"))
		:testEquals()
end)

ParsedArgumentTest:test("getRaw", function()
	local reader = StringReader.new("0123456789")
	local argument = ParsedArgument.new(2, 5, "")
	assertThat(argument:getRange():get(reader), equalTo("234"))
end)

return ParsedArgumentTest
