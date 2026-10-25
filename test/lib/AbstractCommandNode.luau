--!strict
-- AbstractCommandNodeTest is abstract in Java and its tests run in every subclass, so each subclass
-- suite calls this with its getCommandNode.
local B = require("./load")
local JUnit = require("./JUnit")
local Hamcrest = require("./Hamcrest")
local Mockito = require("./Mockito")
local literal = B.literal
local assertThat, is, hasSize = Hamcrest.assertThat, Hamcrest.is, Hamcrest.hasSize

return function(suite: JUnit.Suite, getCommandNode: () -> any)
	local command: any

	suite:before(function()
		command = Mockito.mock()
	end)

	suite:test("testAddChild", function()
		local node = getCommandNode()

		node:addChild(literal("child1"):build())
		node:addChild(literal("child2"):build())
		node:addChild(literal("child1"):build())

		assertThat(node:getChildren(), hasSize(2))
	end)

	suite:test("testAddChildMergesGrandchildren", function()
		local node = getCommandNode()

		node:addChild(literal("child"):with(literal("grandchild1")):build())

		node:addChild(literal("child"):with(literal("grandchild2")):build())

		assertThat(node:getChildren(), hasSize(1))
		assertThat(node:getChildren()[1]:getChildren(), hasSize(2))
	end)

	suite:test("testAddChildPreservesCommand", function()
		local node = getCommandNode()

		node:addChild(literal("child"):executes(command):build())
		node:addChild(literal("child"):build())

		assertThat(node:getChildren()[1]:getCommand(), is(command))
	end)

	suite:test("testAddChildOverwritesCommand", function()
		local node = getCommandNode()

		node:addChild(literal("child"):build())
		node:addChild(literal("child"):executes(command):build())

		assertThat(node:getChildren()[1]:getCommand(), is(command))
	end)
end
