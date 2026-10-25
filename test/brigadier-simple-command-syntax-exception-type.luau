local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local Mockito = require("./lib/Mockito")
local LiteralMessage = B.LiteralMessage
local StringReader = B.StringReader
local CommandSyntaxException = B.CommandSyntaxException
local SimpleCommandExceptionType = B.SimpleCommandExceptionType
local assertThat, is, equalTo, nullValue = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo, Hamcrest.nullValue
local mockObject = Mockito.mockObject

local SimpleCommandSyntaxExceptionTypeTest = JUnit.suite("SimpleCommandSyntaxExceptionTypeTest")

SimpleCommandSyntaxExceptionTypeTest:test("createWithContext", function()
	local type_ = SimpleCommandExceptionType.new(LiteralMessage.new("error"))
	local reader = StringReader.new("Foo bar")
	reader:setCursor(5)
	local exception = type_:createWithContext(reader)
	assertThat(exception:getType(), is(type_))
	assertThat(exception:getInput(), is("Foo bar"))
	assertThat(exception:getCursor(), is(5))
end)

SimpleCommandSyntaxExceptionTypeTest:test("getContext_none", function()
	local exception = CommandSyntaxException.new(mockObject(), LiteralMessage.new("error"))
	assertThat(exception:getContext(), is(nullValue()))
end)

SimpleCommandSyntaxExceptionTypeTest:test("getContext_short", function()
	local exception = CommandSyntaxException.new(mockObject(), LiteralMessage.new("error"), "Hello world!", 5)
	assertThat(exception:getContext(), equalTo("Hello<--[HERE]"))
end)

SimpleCommandSyntaxExceptionTypeTest:test("getContext_long", function()
	local exception = CommandSyntaxException.new(
		mockObject(),
		LiteralMessage.new("error"),
		"Hello world! This has an error in it. Oh dear!",
		20
	)
	assertThat(exception:getContext(), equalTo("...d! This ha<--[HERE]"))
end)

return SimpleCommandSyntaxExceptionTypeTest:tests()
