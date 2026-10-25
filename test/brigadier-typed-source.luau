-- Not a port of a Java test.

local B = require("./lib/load")
local JUnit = require("./lib/JUnit")
local Hamcrest = require("./lib/Hamcrest")
local assertThat, is, equalTo = Hamcrest.assertThat, Hamcrest.is, Hamcrest.equalTo

type Source = {
	name: string,
	admin: boolean,
}

local literal = B.literal
local argument = B.argument
local integer = B.integer
local word = B.word

local TypedSourceTest = JUnit.suite("TypedSourceTest")
local dispatcher: any
local log: { string }

TypedSourceTest:before(function()
	dispatcher = B.CommandDispatcher.new()
	log = {}
	dispatcher:register(literal("give")
		:requires(function(source: Source): boolean
			return source.admin
		end)
		:with(argument("player", word()):with(argument("amount", integer(1, 100)):executes(function(context)
			local source: Source = context:getSource()
			local player = B.getString(context, "player")
			local amount = B.getInteger(context, "amount")
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
	local ex = JUnit.assertThrows(B.CommandSyntaxException, function()
		dispatcher:execute("give Bob 5", { name = "Cid", admin = false })
	end)
	assertThat(ex:getType(), is(B.CommandSyntaxException.BUILT_IN_EXCEPTIONS:dispatcherUnknownCommand()))
	assertThat(log, equalTo({}))
end)

TypedSourceTest:test("suggestsForTheSource", function()
	local parse = dispatcher:parse("gi", { name = "Ann", admin = true })
	local suggestions = dispatcher:getCompletionSuggestions(parse):expect()
	assertThat(suggestions:getList()[1]:getText(), is("give"))
end)

return TypedSourceTest:tests()
