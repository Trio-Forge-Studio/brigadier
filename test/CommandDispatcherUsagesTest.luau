--!strict
local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Mockito = require("@test/lib/Mockito")
local Types = require("@brigadier/Types")
local CommandDispatcher = require("@brigadier/CommandDispatcher")
local StringReader = require("@brigadier/StringReader")
local LiteralArgumentBuilder = require("@brigadier/builder/LiteralArgumentBuilder")

local assertThat, is, equalTo, empty = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo, Hamcrest.empty
local literal = LiteralArgumentBuilder.literal

local CommandDispatcherUsagesTest = JUnit.suite("CommandDispatcherUsagesTest")
local subject: Types.CommandDispatcher<any>
local source: any
local command: any

-- get(String) and get(StringReader).
-- selene: allow(shadowing) -- as in the Java test
local function get(command: string | Types.StringReader): Types.CommandNode<any>
	local nodes = subject:parse(command, source):getContext():getNodes()
	return nodes[#nodes]:getNode()
end

CommandDispatcherUsagesTest:before(function()
	source = Mockito.mockObject("source")
	command = Mockito.mock("command")

	subject = CommandDispatcher.new()
	subject:register(
		literal("a")
			:with(literal("1"):with(literal("i"):executes(command)):with(literal("ii"):executes(command)))
			:with(literal("2"):with(literal("i"):executes(command)):with(literal("ii"):executes(command)))
	)
	subject:register(literal("b"):with(literal("1"):executes(command)))
	subject:register(literal("c"):executes(command))
	subject:register(literal("d")
		:requires(function(_s)
			return false
		end)
		:executes(command))
	subject:register(
		literal("e")
			:executes(command)
			:with(
				literal("1")
					:executes(command)
					:with(literal("i"):executes(command))
					:with(literal("ii"):executes(command))
			)
	)
	subject:register(literal("f")
		:with(
			literal("1"):with(literal("i"):executes(command)):with(literal("ii"):executes(command):requires(function(_s)
				return false
			end))
		)
		:with(literal("2")
			:with(literal("i"):executes(command):requires(function(_s)
				return false
			end))
			:with(literal("ii"):executes(command))))
	subject:register(literal("g"):executes(command):with(literal("1"):with(literal("i"):executes(command))))
	subject:register(
		literal("h")
			:executes(command)
			:with(literal("1"):with(literal("i"):executes(command)))
			:with(literal("2"):with(literal("i"):with(literal("ii"):executes(command))))
			:with(literal("3"):executes(command))
	)
	subject:register(
		literal("i"):executes(command):with(literal("1"):executes(command)):with(literal("2"):executes(command))
	)
	subject:register(literal("j"):redirect(subject:getRoot()))
	subject:register(literal("k"):redirect(get("h")))
end)

CommandDispatcherUsagesTest:test("testAllUsage_noCommands", function()
	subject = CommandDispatcher.new()
	local results = subject:getAllUsage(subject:getRoot(), source, true)
	-- emptyArray(): an array is a table, so empty() covers it.
	assertThat(results, is(empty()))
end)

CommandDispatcherUsagesTest:test("testSmartUsage_noCommands", function()
	subject = CommandDispatcher.new()
	local results = subject:getSmartUsage(subject:getRoot(), source)
	assertThat(results, is(empty()))
end)

CommandDispatcherUsagesTest:test("testAllUsage_root", function()
	local results = subject:getAllUsage(subject:getRoot(), source, true)
	assertThat(
		results,
		equalTo({
			"a 1 i",
			"a 1 ii",
			"a 2 i",
			"a 2 ii",
			"b 1",
			"c",
			"e",
			"e 1",
			"e 1 i",
			"e 1 ii",
			"f 1 i",
			"f 2 ii",
			"g",
			"g 1 i",
			"h",
			"h 1 i",
			"h 2 i ii",
			"h 3",
			"i",
			"i 1",
			"i 2",
			"j ...",
			"k -> h",
		})
	)
end)

CommandDispatcherUsagesTest:test("testSmartUsage_root", function()
	local results = subject:getSmartUsage(subject:getRoot(), source)
	assertThat(
		results,
		equalTo({
			[get("a")] = "a (1|2)",
			[get("b")] = "b 1",
			[get("c")] = "c",
			[get("e")] = "e [1]",
			[get("f")] = "f (1|2)",
			[get("g")] = "g [1]",
			[get("h")] = "h [1|2|3]",
			[get("i")] = "i [1|2]",
			[get("j")] = "j ...",
			[get("k")] = "k -> h",
		})
	)
end)

CommandDispatcherUsagesTest:test("testSmartUsage_h", function()
	local results = subject:getSmartUsage(get("h"), source)
	assertThat(
		results,
		equalTo({
			[get("h 1")] = "[1] i",
			[get("h 2")] = "[2] i ii",
			[get("h 3")] = "[3]",
		})
	)
end)

CommandDispatcherUsagesTest:test("testSmartUsage_offsetH", function()
	local offsetH = StringReader.new("/|/|/h")
	offsetH:setCursor(5)

	local results = subject:getSmartUsage(get(offsetH), source)
	assertThat(
		results,
		equalTo({
			[get("h 1")] = "[1] i",
			[get("h 2")] = "[2] i ii",
			[get("h 3")] = "[3]",
		})
	)
end)

return CommandDispatcherUsagesTest
