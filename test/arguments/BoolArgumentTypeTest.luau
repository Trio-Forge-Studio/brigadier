--!strict
--!nolint LocalUnused
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local Types = require("@brigadier/Types")
local BoolArgumentType = require("@brigadier/arguments/BoolArgumentType")
local bool = BoolArgumentType.bool
local assertThat, is = Hamcrest.assertThat, Hamcrest.is
local verify, when = Mockito.verify, Mockito.when

local BoolArgumentTypeTest = JUnit.suite("BoolArgumentTypeTest")
local type_: Types.BoolArgumentType
-- selene: allow(unused_variable) -- as in the Java test
local context: any

BoolArgumentTypeTest:before(function()
	context = Mockito.mockObject()
	type_ = bool()
end)

BoolArgumentTypeTest:test("parse", function()
	local reader = Mockito.mockObject()
	when(reader.readBoolean):thenReturn(true)
	assertThat(type_:parse(reader), is(true))
	verify(reader.readBoolean)
end)

return BoolArgumentTypeTest
