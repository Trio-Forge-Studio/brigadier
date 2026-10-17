--!strict
--!nolint LocalUnused
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local EqualsTester = require("@test/lib/EqualsTester")
local Java = require("@test/lib/Java")
local Types = require("@brigadier/Types")
local StringReader = require("@brigadier/StringReader")
local CommandSyntaxException = require("@brigadier/exceptions/CommandSyntaxException")
local LongArgumentType = require("@brigadier/arguments/LongArgumentType")
local longArg = LongArgumentType.longArg
local assertThat, is, hasToString = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasToString
local Long = Java.Long

local LongArgumentTypeTest = JUnit.suite("LongArgumentTypeTest")
-- selene: allow(unused_variable) -- as in the Java test
local type_: Types.LongArgumentType
-- selene: allow(unused_variable) -- as in the Java test
local context: any

LongArgumentTypeTest:before(function()
	context = Mockito.mockObject()
	type_ = longArg(-100, 1_000_000_000_000)
end)

LongArgumentTypeTest:test("parse", function()
	local reader = StringReader.new("15")
	assertThat(longArg():parse(reader), is(15))
	assertThat(reader:canRead(), is(false))
end)

LongArgumentTypeTest:test("parse_tooSmall", function()
	local reader = StringReader.new("-5")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		longArg(0, 100):parse(reader)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:longTooLow()))
	assertThat(ex:getCursor(), is(0))
end)

LongArgumentTypeTest:test("parse_tooBig", function()
	local reader = StringReader.new("5")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		longArg(-100, 0):parse(reader)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:longTooHigh()))
	assertThat(ex:getCursor(), is(0))
end)

LongArgumentTypeTest:test("testEquals", function()
	EqualsTester.new()
		:addEqualityGroup(longArg(), longArg())
		:addEqualityGroup(longArg(-100, 100), longArg(-100, 100))
		:addEqualityGroup(longArg(-100, 50), longArg(-100, 50))
		:addEqualityGroup(longArg(-50, 100), longArg(-50, 100))
		:testEquals()
end)

LongArgumentTypeTest:test("testToString", function()
	assertThat(longArg(), hasToString("longArg()"))
	assertThat(longArg(-100), hasToString("longArg(-100)"))
	assertThat(longArg(-100, 100), hasToString("longArg(-100, 100)"))
	assertThat(longArg(Long.MIN_VALUE, 100), hasToString("longArg(-9223372036854775808, 100)"))
end)

return LongArgumentTypeTest
