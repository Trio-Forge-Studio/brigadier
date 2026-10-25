local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local LiteralArgumentBuilder = B.LiteralArgumentBuilder
local integer = B.integer
local argument = B.argument
local assertThat, is, hasSize = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasSize

local LiteralArgumentBuilderTest = JUnit.suite("LiteralArgumentBuilderTest")
local builder: any
local command: any

LiteralArgumentBuilderTest:before(function()
	-- The Java class has an @Mock field but no MockitoJUnitRunner, so the field stays null.
	command = nil
	builder = LiteralArgumentBuilder.new("foo")
end)

LiteralArgumentBuilderTest:test("testBuild", function()
	local node = builder:build()

	assertThat(node:getLiteral(), is("foo"))
end)

LiteralArgumentBuilderTest:test("testBuildWithExecutor", function()
	local node = builder:executes(command):build()

	assertThat(node:getLiteral(), is("foo"))
	assertThat(node:getCommand(), is(command))
end)

LiteralArgumentBuilderTest:test("testBuildWithChildren", function()
	builder:with(argument("bar", integer()))
	builder:with(argument("baz", integer()))
	local node = builder:build()

	assertThat(node:getChildren(), hasSize(2))
end)

return LiteralArgumentBuilderTest:tests()
