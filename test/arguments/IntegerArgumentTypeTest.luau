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
local IntegerArgumentType = require("@brigadier/arguments/IntegerArgumentType")
local integer = IntegerArgumentType.integer
local assertThat, is, hasToString = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasToString
local Integer = Java.Integer

local IntegerArgumentTypeTest = JUnit.suite("IntegerArgumentTypeTest")
-- selene: allow(unused_variable) -- as in the Java test
local type_: Types.IntegerArgumentType
-- selene: allow(unused_variable) -- as in the Java test
local context: any

IntegerArgumentTypeTest:before(function()
	context = Mockito.mockObject()
	type_ = integer(-100, 100)
end)

IntegerArgumentTypeTest:test("parse", function()
	local reader = StringReader.new("15")
	assertThat(integer():parse(reader), is(15))
	assertThat(reader:canRead(), is(false))
end)

IntegerArgumentTypeTest:test("parse_tooSmall", function()
	local reader = StringReader.new("-5")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		integer(0, 100):parse(reader)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:integerTooLow()))
	assertThat(ex:getCursor(), is(0))
end)

IntegerArgumentTypeTest:test("parse_tooBig", function()
	local reader = StringReader.new("5")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		integer(-100, 0):parse(reader)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:integerTooHigh()))
	assertThat(ex:getCursor(), is(0))
end)

IntegerArgumentTypeTest:test("testEquals", function()
	EqualsTester.new()
		:addEqualityGroup(integer(), integer())
		:addEqualityGroup(integer(-100, 100), integer(-100, 100))
		:addEqualityGroup(integer(-100, 50), integer(-100, 50))
		:addEqualityGroup(integer(-50, 100), integer(-50, 100))
		:testEquals()
end)

IntegerArgumentTypeTest:test("testToString", function()
	assertThat(integer(), hasToString("integer()"))
	assertThat(integer(-100), hasToString("integer(-100)"))
	assertThat(integer(-100, 100), hasToString("integer(-100, 100)"))
	assertThat(integer(Integer.MIN_VALUE, 100), hasToString("integer(-2147483648, 100)"))
end)

return IntegerArgumentTypeTest
