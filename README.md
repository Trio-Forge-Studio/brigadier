# @trioforge/brigadier

A roblox-ts port of [Mojang's Brigadier](https://github.com/Mojang/brigadier), the command parser and dispatcher behind Minecraft's commands. It is a class-for-class port of Brigadier 1.3, and it passes all of Brigadier's unit tests.

Read the documentation at <https://website.trio-forge.workers.dev/docs/brigadier/>.

## Install

```sh
pnpm add @trioforge/brigadier
```

roblox-ts only looks for packages in the scopes your project lists, so add the `@trioforge` scope in two places.

1. In `tsconfig.json`, add it to `typeRoots`:

	```json
	"typeRoots": ["node_modules/@rbxts", "node_modules/@trioforge"]
	```

2. In your Rojo project, map it beside `@rbxts` under `rbxts_include/node_modules`:

	```json
	"node_modules": {
		"$className": "Folder",
		"@rbxts": { "$path": "node_modules/@rbxts" },
		"@trioforge": { "$path": "node_modules/@trioforge" }
	}
	```

## Example

```ts
import { CommandDispatcher, argument, getInteger, getString, integer, literal, word } from "@trioforge/brigadier";

const dispatcher = new CommandDispatcher<Player>();

dispatcher.register(
	literal<Player>("give").then(
		argument<Player, string>("target", word()).then(
			argument<Player, number>("amount", integer(1, 100)).executes((context) => {
				const target = getString(context, "target");
				const amount = getInteger(context, "amount");
				print(`${context.getSource().Name} gives ${amount} to ${target}`);
				return 1;
			}),
		),
	),
);

dispatcher.execute("give Bob 50", player);
// → Ann gives 50 to Bob
```

A command that fails to parse throws a `CommandSyntaxException`. Its `getMessage()` names the problem and points at the character, such as `Integer must not be more than 100, found 500 at position 9: give Bob <--[HERE]`.

## Differences from the Java

The names are Brigadier's. [docs/porting.md](docs/porting.md) lists every place the port differs, such as Promises instead of `CompletableFuture` and `stringArg()` instead of `string()`.

## Development

Install the Node tools with `pnpm install`, and Lune and StyLua with `rokit install`.

```sh
pnpm run check   # oxfmt, rbxtsc, StyLua, the tests and the README example
pnpm run test    # build, then run the tests
```

The tests in `test/` are Brigadier's JUnit tests, ported to Luau one to one. The shared `tooling/lune/runtime.luau` loads the compiled package from `out/` through roblox-ts's runtime, as a place does, and Lune runs them. [AGENTS.md](AGENTS.md) has the rules for changing the port.

## License

MIT, like Brigadier. See [LICENSE](LICENSE).
