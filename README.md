# Brigadier for Luau

A faithful port of [Mojang's Brigadier](https://github.com/Mojang/brigadier), the command parser and dispatcher behind Minecraft's commands, to strict Luau for Roblox.

Brigadier builds commands as a tree of literals and typed arguments. It parses input separately from running it, so the same tree gives you syntax errors that point at the right character, completion suggestions, usage strings, permission checks, redirects and forks.

This repository is the port of the core, class for class and test for test: all 234 of Brigadier's unit tests are ported and pass, along with a few of the port's own. A Roblox layer (networked command trees, client-side completion, Roblox argument types) and a typed declarative API come next; see [docs/design.md](docs/design.md).

## Example

```luau
local Brigadier = require(path.to.Brigadier)

local literal = Brigadier.LiteralArgumentBuilder.literal
local argument = Brigadier.RequiredArgumentBuilder.argument
local integer = Brigadier.IntegerArgumentType.integer
local word = Brigadier.StringArgumentType.word

type Source = { player: Player }

local dispatcher: Brigadier.CommandDispatcher<Source> = Brigadier.CommandDispatcher.new()

dispatcher:register(
	literal("give"):with(argument("player", word()):with(argument("amount", integer(1, 100)):executes(function(context)
		local player = Brigadier.StringArgumentType.getString(context, "player")
		local amount = Brigadier.IntegerArgumentType.getInteger(context, "amount")
		print(`{context:getSource().player.Name} gives {amount} to {player}`)
		return Brigadier.Command.SINGLE_SUCCESS
	end)))
)

local ok, err = pcall(function()
	dispatcher:execute("give Bob 500", { player = somePlayer })
end)
if not ok and Brigadier.CommandSyntaxException.isInstance(err) then
	local exception = err :: Brigadier.CommandSyntaxException
	print(exception:getMessage()) -- Integer must not be more than 100, found 500 at position 9: give Bob <--[HERE]
end
```

The API is Brigadier's, in camelCase, with these Luau adjustments:

- `then` is a Luau keyword, so adding a child is `with`: `literal("give"):with(argument(...))`.
- Constructors are `Class.new(...)`, and `instanceof` is `Class.isInstance(value)`.
- Exceptions are raised with `error` and caught with `pcall`.
- Suggestions use a small port of `CompletableFuture`; `join()` waits by yielding the coroutine.

[docs/porting.md](docs/porting.md) lists every rule, the full module surface, and the few places where the behaviour differs from Java.

## Installing

Not published yet. Until it is, copy `src` into your project, or sync it with Rojo using `default.project.json`.

## Development

The tools are pinned in `rokit.toml`. Install them with `rokit install`, then run `lune setup` once so the editor and luau-lsp know Lune's types.

```sh
bash scripts/check.sh   # StyLua, selene, luau-lsp (new solver), and the tests
lune run test           # just the tests; pass names to filter: lune run test StringReaderTest
lune run bench/ExecuteBenchmarks.luau
```

The tests in `test/` mirror Brigadier's JUnit tests one to one, on a small JUnit, Hamcrest and Mockito harness in `test/lib`.

## License

MIT, like Brigadier. See [LICENSE](LICENSE).
