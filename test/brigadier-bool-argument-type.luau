--!nolint LocalUnused
local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local Mockito = require("./lib/Mockito")
local bool = B.bool
local assertThat, is = Hamcrest.assertThat, Hamcrest.is
local verify, when = Mockito.verify, Mockito.when

local BoolArgumentTypeTest = JUnit.suite("BoolArgumentTypeTest")
local type_: any
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

return BoolArgumentTypeTest:tests()
