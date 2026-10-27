# @trioforge/brigadier

A roblox-ts port of [Mojang's Brigadier](https://github.com/Mojang/brigadier), the command parser and dispatcher behind Minecraft's commands. It ports Brigadier 1.3 class for class and passes all of Brigadier's unit tests.

The documentation is at <https://website.trio-forge.workers.dev/docs/brigadier/>.

## Install

```sh
pnpm add @trioforge/brigadier
```

roblox-ts only finds packages in the scopes your project lists, so you need to add the `@trioforge` scope in two places.

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

When a command fails to parse, `execute` throws a `CommandSyntaxException`. Its `getMessage()` says what went wrong and where, such as `Integer must not be more than 100, found 500 at position 9: give Bob <--[HERE]`.

## Differences from the Java

The port keeps Brigadier's names. [docs/porting.md](docs/porting.md) lists every place where the port differs from the Java version, such as Promises instead of `CompletableFuture` and `stringArg()` instead of `string()`.

## Development

Install the Node tools with `pnpm install`, and Lune and StyLua with `rokit install`.

```sh
pnpm run check   # oxfmt, rbxtsc, StyLua, the tests and the README example
pnpm run test    # build, then run the tests
```

The tests in `test/` are Brigadier's JUnit tests, ported to Luau one to one. Lune runs them against the compiled package in `out/`, which `@trioforge/tooling`'s Lune runtime loads through the roblox-ts runtime the same way a Roblox place would. [AGENTS.md](AGENTS.md) has the rules for changing the port.

## License

MIT, like Brigadier. See [LICENSE](LICENSE).
