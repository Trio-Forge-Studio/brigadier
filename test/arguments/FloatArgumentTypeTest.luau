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
local FloatArgumentType = require("@brigadier/arguments/FloatArgumentType")
local floatArg = FloatArgumentType.floatArg
local assertThat, is, hasToString = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasToString
local Integer = Java.Integer

local FloatArgumentTypeTest = JUnit.suite("FloatArgumentTypeTest")
-- selene: allow(unused_variable) -- as in the Java test
local type_: Types.FloatArgumentType
-- selene: allow(unused_variable) -- as in the Java test
local context: any

FloatArgumentTypeTest:before(function()
	context = Mockito.mockObject()
	type_ = floatArg(-100, 100)
end)

FloatArgumentTypeTest:test("parse", function()
	local reader = StringReader.new("15")
	assertThat(floatArg():parse(reader), is(15))
	assertThat(reader:canRead(), is(false))
end)

FloatArgumentTypeTest:test("parse_tooSmall", function()
	local reader = StringReader.new("-5")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		floatArg(0, 100):parse(reader)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:floatTooLow()))
	assertThat(ex:getCursor(), is(0))
end)

FloatArgumentTypeTest:test("parse_tooBig", function()
	local reader = StringReader.new("5")
	local ex = JUnit.assertThrows(CommandSyntaxException, function()
		floatArg(-100, 0):parse(reader)
	end)
	assertThat(ex:getType(), is(CommandSyntaxException.BUILT_IN_EXCEPTIONS:floatTooHigh()))
	assertThat(ex:getCursor(), is(0))
end)

FloatArgumentTypeTest:test("testEquals", function()
	EqualsTester.new()
		:addEqualityGroup(floatArg(), floatArg())
		:addEqualityGroup(floatArg(-100, 100), floatArg(-100, 100))
		:addEqualityGroup(floatArg(-100, 50), floatArg(-100, 50))
		:addEqualityGroup(floatArg(-50, 100), floatArg(-50, 100))
		:testEquals()
end)

FloatArgumentTypeTest:test("testToString", function()
	assertThat(floatArg(), hasToString("float()"))
	assertThat(floatArg(-100), hasToString("float(-100.0)"))
	assertThat(floatArg(-100, 100), hasToString("float(-100.0, 100.0)"))
	-- The Java test expects JDK 8's "-2.14748365E9". Float.toString prints the shortest digits that
	-- identify the float, as the JDK specifies and does since JDK 19; see docs/porting.md.
	assertThat(floatArg(Integer.MIN_VALUE, 100), hasToString("float(-2.1474836E9, 100.0)"))
end)

return FloatArgumentTypeTest
