--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Types = require("@brigadier/Types")
local LiteralMessage = require("@brigadier/LiteralMessage")
local StringReader = require("@brigadier/StringReader")
local DynamicCommandExceptionType = require("@brigadier/exceptions/DynamicCommandExceptionType")
local assertThat, is = Hamcrest.assertThat, Hamcrest.is

local DynamicCommandSyntaxExceptionTypeTest = JUnit.suite("DynamicCommandSyntaxExceptionTypeTest")

local type_: Types.DynamicCommandExceptionType

DynamicCommandSyntaxExceptionTypeTest:before(function()
	type_ = DynamicCommandExceptionType.new(function(name)
		return LiteralMessage.new("Hello, " .. tostring(name) .. "!")
	end)
end)

DynamicCommandSyntaxExceptionTypeTest:test("createWithContext", function()
	local reader = StringReader.new("Foo bar")
	reader:setCursor(5)
	local exception = type_:createWithContext(reader, "World")
	assertThat(exception:getType(), is(type_))
	assertThat(exception:getInput(), is("Foo bar"))
	assertThat(exception:getCursor(), is(5))
end)

return DynamicCommandSyntaxExceptionTypeTest
