--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local Types = require("@brigadier/Types")
local IntegerArgumentType = require("@brigadier/arguments/IntegerArgumentType")
local RequiredArgumentBuilder = require("@brigadier/builder/RequiredArgumentBuilder")
local integer = IntegerArgumentType.integer
local argument = RequiredArgumentBuilder.argument
local assertThat, is, hasSize = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasSize

local RequiredArgumentBuilderTest = JUnit.suite("RequiredArgumentBuilderTest")
local type_: any
local builder: Types.RequiredArgumentBuilder<any, number>
local command: any

RequiredArgumentBuilderTest:before(function()
	type_ = Mockito.mockObject()
	command = Mockito.mock()
	builder = argument("foo", type_)
end)

RequiredArgumentBuilderTest:test("testBuild", function()
	local node = builder:build()

	assertThat(node:getName(), is("foo"))
	assertThat(node:getType(), is(type_))
end)

RequiredArgumentBuilderTest:test("testBuildWithExecutor", function()
	local node = builder:executes(command):build()

	assertThat(node:getName(), is("foo"))
	assertThat(node:getType(), is(type_))
	assertThat(node:getCommand(), is(command))
end)

RequiredArgumentBuilderTest:test("testBuildWithChildren", function()
	builder:with(argument("bar", integer()))
	builder:with(argument("baz", integer()))
	local node = builder:build()

	assertThat(node:getChildren(), hasSize(2))
end)

return RequiredArgumentBuilderTest
