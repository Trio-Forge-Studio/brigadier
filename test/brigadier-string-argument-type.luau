--!nolint LocalUnused
local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local Mockito = require("./lib/Mockito")
local StringReader = B.StringReader
local escapeIfRequired = B.escapeIfRequired
local greedyString = B.greedyString
local stringArg = B.stringArg
local word = B.word
local assertThat, is, equalTo, hasToString = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo, Hamcrest.hasToString
local verify, when = Mockito.verify, Mockito.when

local StringArgumentTypeTest = JUnit.suite("StringArgumentTypeTest")
-- selene: allow(unused_variable) -- as in the Java test
local context: any

StringArgumentTypeTest:before(function()
	context = Mockito.mockObject()
end)

StringArgumentTypeTest:test("testParseWord", function()
	local reader = Mockito.mockObject()
	when(reader.readUnquotedString):thenReturn("hello")
	assertThat(word():parse(reader), equalTo("hello"))
	verify(reader.readUnquotedString)
end)

StringArgumentTypeTest:test("testParseString", function()
	local reader = Mockito.mockObject()
	when(reader.readString):thenReturn("hello world")
	assertThat(stringArg():parse(reader), equalTo("hello world"))
	verify(reader.readString)
end)

StringArgumentTypeTest:test("testParseGreedyString", function()
	local reader = StringReader.new("Hello world! This is a test.")
	assertThat(greedyString():parse(reader), equalTo("Hello world! This is a test."))
	assertThat(reader:canRead(), is(false))
end)

StringArgumentTypeTest:test("testToString", function()
	assertThat(stringArg(), hasToString("string()"))
end)

StringArgumentTypeTest:test("testEscapeIfRequired_notRequired", function()
	assertThat(escapeIfRequired("hello"), is(equalTo("hello")))
	assertThat(escapeIfRequired(""), is(equalTo("")))
end)

StringArgumentTypeTest:test("testEscapeIfRequired_multipleWords", function()
	assertThat(escapeIfRequired("hello world"), is(equalTo('"hello world"')))
end)

StringArgumentTypeTest:test("testEscapeIfRequired_quote", function()
	assertThat(escapeIfRequired('hello "world"!'), is(equalTo('"hello \\"world\\"!"')))
end)

StringArgumentTypeTest:test("testEscapeIfRequired_escapes", function()
	assertThat(escapeIfRequired("\\"), is(equalTo('"\\\\"')))
end)

StringArgumentTypeTest:test("testEscapeIfRequired_singleQuote", function()
	assertThat(escapeIfRequired('"'), is(equalTo('"\\""')))
end)

return StringArgumentTypeTest:tests()
