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
local DoubleArgumentType = require("@brigadier/arguments/DoubleArgumentType")
local doubleArg = DoubleArgumentType.doubleArg
local assertThat, is, hasToString = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasToString
local Integer = Java.Integer

local DoubleArgumentTypeTest = JUnit.suite("DoubleArgumentTypeTest")
-- selene: allow(unused_variable) -- as in the Java test
local type_: Types.DoubleArgumentType
-- selene: allow(unused_variable) -- as in the Java test
local context: any

DoubleArgumentTypeTest:before(function()
	context = Mockito.mockObject()
	type_ = doubleArg(-100, 100)
end)

DoubleArgumentTypeTest:test("parse", function()
	local reader = StringReader.new("15")
	assertThat(doubleArg():parse(reader), is(15.0))
	assertThat(reader:canRead(), is(false))
end)

DoubleArgumentTypeTest:test("parse_tooSmall", function()
	local reader = StringReader.new("-5")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		doubleArg(0, 100):parse(reader)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:doubleTooLow()))
	assertThat(ex:getCursor(), is(0))
end)

DoubleArgumentTypeTest:test("parse_tooBig", function()
	local reader = StringReader.new("5")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		doubleArg(-100, 0):parse(reader)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:doubleTooHigh()))
	assertThat(ex:getCursor(), is(0))
end)

DoubleArgumentTypeTest:test("testEquals", function()
	EqualsTester.new()
		:addEqualityGroup(doubleArg(), doubleArg())
		:addEqualityGroup(doubleArg(-100, 100), doubleArg(-100, 100))
		:addEqualityGroup(doubleArg(-100, 50), doubleArg(-100, 50))
		:addEqualityGroup(doubleArg(-50, 100), doubleArg(-50, 100))
		:testEquals()
end)

DoubleArgumentTypeTest:test("testToString", function()
	assertThat(doubleArg(), hasToString("double()"))
	assertThat(doubleArg(-100), hasToString("double(-100.0)"))
	assertThat(doubleArg(-100, 100), hasToString("double(-100.0, 100.0)"))
	assertThat(doubleArg(Integer.MIN_VALUE, 100), hasToString("double(-2.147483648E9, 100.0)"))
end)

return DoubleArgumentTypeTest
