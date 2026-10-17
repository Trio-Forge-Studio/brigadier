--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local Types = require("@brigadier/Types")
local RuntimeException = require("@brigadier/util/RuntimeException")
local ArgumentBuilder = require("@brigadier/builder/ArgumentBuilder")
local IntegerArgumentType = require("@brigadier/arguments/IntegerArgumentType")
local LiteralArgumentBuilder = require("@brigadier/builder/LiteralArgumentBuilder")
local RequiredArgumentBuilder = require("@brigadier/builder/RequiredArgumentBuilder")
local integer = IntegerArgumentType.integer
local literal = LiteralArgumentBuilder.literal
local argument = RequiredArgumentBuilder.argument
local assertThat, is, hasSize, hasItem = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasSize, Hamcrest.hasItem
local IllegalStateException = RuntimeException.IllegalStateException

-- class TestableArgumentBuilder<S> extends ArgumentBuilder<S, TestableArgumentBuilder<S>>
local TestableArgumentBuilder = setmetatable({}, { __index = ArgumentBuilder }) :: any
TestableArgumentBuilder.__index = TestableArgumentBuilder

function TestableArgumentBuilder.new(): Types.ArgumentBuilder<any>
	local self = {}
	ArgumentBuilder.init(self)
	return setmetatable(self, TestableArgumentBuilder) :: any
end

function TestableArgumentBuilder.getThis(self: any): any
	return self
end

function TestableArgumentBuilder.build(_self: any): any
	return nil
end

local ArgumentBuilderTest = JUnit.suite("ArgumentBuilderTest")
local builder: Types.ArgumentBuilder<any>

ArgumentBuilderTest:before(function()
	builder = TestableArgumentBuilder.new()
end)

ArgumentBuilderTest:test("testArguments", function()
	local argument_ = argument("bar", integer())

	builder:with(argument_)

	assertThat(builder:getArguments(), hasSize(1))
	assertThat(builder:getArguments(), hasItem(argument_:build()))
end)

ArgumentBuilderTest:test("testRedirect", function()
	local target = Mockito.mockObject()
	builder:redirect(target)
	assertThat(builder:getRedirect(), is(target))
end)

ArgumentBuilderTest:test("testRedirect_withChild", function()
	JUnit.assertThrows(IllegalStateException, function()
		local target = Mockito.mockObject()
		builder:with(literal("foo"))
		builder:redirect(target)
	end)
end)

ArgumentBuilderTest:test("testThen_withRedirect", function()
	JUnit.assertThrows(IllegalStateException, function()
		local target = Mockito.mockObject()
		builder:redirect(target)
		builder:with(literal("foo"))
	end)
end)

return ArgumentBuilderTest
