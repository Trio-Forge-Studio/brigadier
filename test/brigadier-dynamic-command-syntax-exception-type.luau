local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local LiteralMessage = B.LiteralMessage
local StringReader = B.StringReader
local DynamicCommandExceptionType = B.DynamicCommandExceptionType
local assertThat, is = Hamcrest.assertThat, Hamcrest.is

local DynamicCommandSyntaxExceptionTypeTest = JUnit.suite("DynamicCommandSyntaxExceptionTypeTest")

local type_: any

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

return DynamicCommandSyntaxExceptionTypeTest:tests()
