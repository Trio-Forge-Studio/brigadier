--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Types = require("@brigadier/Types")
local IntegerArgumentType = require("@brigadier/arguments/IntegerArgumentType")
local LiteralArgumentBuilder = require("@brigadier/builder/LiteralArgumentBuilder")
local RequiredArgumentBuilder = require("@brigadier/builder/RequiredArgumentBuilder")
local integer = IntegerArgumentType.integer
local argument = RequiredArgumentBuilder.argument
local assertThat, is, hasSize = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasSize

local LiteralArgumentBuilderTest = JUnit.suite("LiteralArgumentBuilderTest")
local builder: Types.LiteralArgumentBuilder<any>
local command: any

LiteralArgumentBuilderTest:before(function()
	-- The Java class has an @Mock field but no MockitoJUnitRunner, so the field stays null.
	command = nil
	-- The constructor is protected in Java and not part of the port's surface; literal() calls it.
	builder = LiteralArgumentBuilder.literal("foo")
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

return LiteralArgumentBuilderTest
