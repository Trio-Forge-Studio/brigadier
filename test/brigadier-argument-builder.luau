local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local Mockito = require("./lib/Mockito")
local ArgumentBuilder = B.ArgumentBuilder
local integer = B.integer
local literal = B.literal
local argument = B.argument
local assertThat, is, hasSize, hasItem = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasSize, Hamcrest.hasItem
local IllegalStateException = B.IllegalStateException

-- class TestableArgumentBuilder<S> extends ArgumentBuilder<S, TestableArgumentBuilder<S>>
local TestableArgumentBuilder = setmetatable({}, { __index = ArgumentBuilder }) :: any
TestableArgumentBuilder.__index = TestableArgumentBuilder

function TestableArgumentBuilder.new(): any
	local self = setmetatable({}, TestableArgumentBuilder)
	ArgumentBuilder.constructor(self)
	return self
end

function TestableArgumentBuilder.build(_self: any): any
	return nil
end

local ArgumentBuilderTest = JUnit.suite("ArgumentBuilderTest")
local builder: any

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

return ArgumentBuilderTest:tests()
