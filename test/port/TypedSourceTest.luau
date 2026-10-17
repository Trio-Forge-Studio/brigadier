--!strict

-- Not a port of a Java test. Brigadier's tests all use Object as the source, which the port types as
-- `any`; this suite uses a concrete source type, so the type check fails if the public types stop
-- accepting one.

local JUnit = require("@test/lib/JUnit")
local Hamcrest = require("@test/lib/Hamcrest")
local Brigadier = require("@brigadier")
local assertThat, is, equalTo = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo

type Source = {
	name: string,
	admin: boolean,
}

local literal = Brigadier.LiteralArgumentBuilder.literal
local argument = Brigadier.RequiredArgumentBuilder.argument
local integer = Brigadier.IntegerArgumentType.integer
local word = Brigadier.StringArgumentType.word

local TypedSourceTest = JUnit.suite("TypedSourceTest")
local dispatcher: Brigadier.CommandDispatcher<Source>
local log: { string }

TypedSourceTest:before(function()
	dispatcher = Brigadier.CommandDispatcher.new()
	log = {}
	dispatcher:register(literal("give")
		:requires(function(source: Source): boolean
			return source.admin
		end)
		:with(argument("player", word()):with(argument("amount", integer(1, 100)):executes(function(context)
			local source: Source = context:getSource()
			local player = Brigadier.StringArgumentType.getString(context, "player")
			local amount = Brigadier.IntegerArgumentType.getInteger(context, "amount")
			table.insert(log, `{source.name} gave {amount} to {player}`)
			return amount
		end))))
end)

TypedSourceTest:test("executesWithTheSource", function()
	local result = dispatcher:execute("give Bob 5", { name = "Ann", admin = true })
	assertThat(result, is(5))
	assertThat(log, equalTo({ "Ann gave 5 to Bob" }))
end)

TypedSourceTest:test("requirementSeesTheSource", function()
	local ex: Brigadier.CommandSyntaxException = JUnit.assertThrows(Brigadier.CommandSyntaxException, function()
		dispatcher:execute("give Bob 5", { name = "Cid", admin = false })
	end)
	assertThat(ex:getType(), is(Brigadier.CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand()))
	assertThat(log, equalTo({}))
end)

TypedSourceTest:test("suggestsForTheSource", function()
	local parse = dispatcher:parse("gi", { name = "Ann", admin = true })
	local suggestions = dispatcher:getCompletionSuggestions(parse):join()
	assertThat(suggestions:getList()[1]:getText(), is("give"))
end)

return TypedSourceTest
