# Brigadier for Luau: design draft

Working name: `brigadier-luau`. A port of [Mojang/brigadier](https://github.com/Mojang/brigadier) (MIT) to strict Luau, plus the Roblox layer Minecraft builds on top of it: a server that sends each player the commands they may use, and a client that parses, highlights and completes locally.

Status: draft. Step 1 of the plan, the port of the core, is done (see the README and docs/porting.md). The API shape in section 3 was checked against luau-lsp 1.70.1 with the new solver in a throwaway spike.

## 1. Goals

- Same model as Brigadier: a tree of literal and argument nodes, parsing kept separate from execution, `requires`, `redirect` and `fork`, suggestions, usage strings, syntax errors that carry a cursor position.
- Arguments typed end to end in strict Luau, without the string lookups Brigadier needs (`getInteger(ctx, "amount")`).
- The server has the final say. The client gets a filtered copy of the tree for completion and highlighting; the server parses every line again with the real source.
- The core runs anywhere Luau runs (Lune for tests). Only the Roblox layer touches services.
- No UI. The package gives a console what it needs (spans, suggestions, usage, errors) and leaves drawing to the game.

Not goals for v1: a ready-made console, chat-bar integration beyond an optional adapter, roblox-ts typings (planned after the Luau API settles).

## 2. Layers

```
src/
  init.luau              public API
  Core/
    StringReader.luau
    Nodes.luau           Root, Literal, Argument; canUse, relevant children
    Builder.luau         declarative tree builder and typed handles
    Dispatcher.luau      register, parse, execute, completion, usage
    Context.luau         Context and ContextBuilder (with child contexts for redirects)
    ParseResults.luau
    Suggestions.luau     Suggestions and SuggestionsBuilder
    Errors.luau          syntax errors and fail()
    Types/               bool, integer, number, word, string, greedy
  Schema/
    Registry.luau        argument types by id, with encode/decode of their properties
    Wire.luau            tree <-> plain tables for remotes
  Roblox/
    Types/               player(s) with selectors, user, vector3, color3, enum, duration, choice
    Server.luau
    Client.luau
    Transport.luau       default RemoteEvent transport; replaceable
    Chat.luau            optional TextChatService adapter
```

`Core` is a faithful port. Keep Brigadier's algorithms as they are, because they are subtle and its test suite pins them down:

- Parsing tries every relevant child with a copy of the reader, but a literal that matches hides the argument siblings (`getRelevantNodes`).
- When several branches parse, the best one wins: the one that consumed the most input, then the one with fewer errors.
- Completion finds the node under the cursor (`findSuggestionContext`) and asks that node's children for suggestions.
- `redirect` continues parsing at another node with a child context. `fork` and the modifier turn one source into several.

Port Brigadier's JUnit tests to Lune as a conformance suite before building anything on top.

## 3. Luau API

### Binding the source type

`S` is the game's source type: who runs the command and what they can do. Luau can't infer `S` from the curried builder calls (an unannotated `literal "x" {...}` comes out as `Node<unknown>`), so it is bound once with a cast:

```luau
local Brig = require(Packages.Brigadier)

type Source = {
	player: Player,
	role: number,
	reply: (text: string) -> (),
}

local B = Brig.builder() :: Brig.Builder<Source>
local literal, argument = B.literal, B.argument
```

After that, `ctx.source` is `Source` everywhere, and `requires` gets a `Source`.

### Declaring commands

Luau's call syntax without parentheses (`f "x" {...}`) gives a tree that reads like the command. It also avoids `then`, which is a keyword in Luau, so Brigadier's `.then(...)` can't be ported literally.

```luau
local T = Brig.types
local R = Brig.roblox

local target = Brig.arg("player", R.player())
local amount = Brig.arg("amount", T.integer(1, 1_000_000))

dispatcher:register(literal "give" {
	requires = function(source)
		return source.role >= Roles.Admin
	end,
	argument(target) {
		argument(amount) {
			executes = function(ctx)
				local player = target:get(ctx) -- Player
				local n = amount:get(ctx) -- number
				Money.give(player, n)
				ctx.source.reply(`Gave {n} to {player.Name}.`)
			end,
		},
	},
})
```

A node table is `{ [number]: Node<S>, requires: ..., executes: ..., suggests: ..., redirect: ..., fork: ... }`. Children go in the array part and settings in named keys. The type checker catches a misspelled key (`require =` gives an error), though the message is unclear.

Handles are values: `Brig.arg(name, type)` returns an `Arg<T>`, and `handle:get(ctx)` returns `T`. In that spike, assigning `amount:get(ctx)` to a `string` is rejected. One handle can appear in several branches. Two different arguments with the same name on one path are an error at `register`.

### Optional arguments and branches

Brigadier has no optional arguments: a node is optional when its parent is also executable. Keep that rule; it is what makes usage strings and completion correct.

```luau
local function heal(ctx: Brig.Context<Source>, who: Player)
	...
end

literal "heal" {
	executes = function(ctx) heal(ctx, ctx.source.player) end,
	argument(target) {
		executes = function(ctx) heal(ctx, target:get(ctx)) end,
	},
}
```

### Return values and failures

`executes` returns an optional `number` (Brigadier's result count, default 1). `Brig.fail(message)` throws a command failure that the dispatcher catches and reports. Any other error is logged on the server and the player gets a generic message, so stack traces never reach clients.

### Redirects and execute-style commands

```luau
dispatcher:register(literal "execute" {
	literal "as" {
		argument(targets) {
			fork = Brig.path "execute",
			modifier = function(ctx)
				local sources = {}
				for _, player in targets:get(ctx) do
					table.insert(sources, Sources.of(player))
				end
				return sources
			end,
		},
	},
	literal "run" {
		redirect = Brig.root,
	},
})
```

`Brig.path` and `Brig.root` are resolved at `register`, which lets a node point at its own ancestors, something a table literal can't express directly.

### Argument types

```luau
export type ArgType<T> = {
	id: string,
	parse: (reader: StringReader) -> T, -- sync; raises a syntax error at the reader's cursor
	suggest: ((ctx: Context<any>, builder: SuggestionsBuilder) -> ())?,
	examples: { string }?,
	encode: (() -> { [string]: unknown })?, -- properties sent to clients
}
```

`parse` must be synchronous and pure, because the client runs it on every keystroke. Types that need a lookup follow Minecraft's entity selector: `parse` returns an unresolved value, and the handle resolves it at execution time, where yielding is allowed.

- `R.player()` parses `@me`, `@random` or a name prefix into a selector; `get` returns one `Player` or fails.
- `R.players()` adds `@all` and `@others`; `get` returns `{ Player }`.
- `R.user()` accepts `@name`, a user id, or a player in the server. `get` yields on `GetUserIdFromNameAsync` and caches the result.

Custom types are registered in a shared module that both sides require:

```luau
Brig.registry.define("fd:upgrade", function(props)
	return T.choice(Upgrades.ids)
end)
```

### Custom suggestions

```luau
argument(item) {
	suggests = function(ctx, builder)
		for _, id in Inventory.of(ctx.source.player) do
			builder:suggest(id)
		end
	end,
}
```

The tree is defined on the server only, because `executes` uses server modules. So a node's `suggests` function only exists on the server, and the wire format marks it as remote. Suggestions that come from an argument type run on the client, if the client knows the type.

## 4. Networking

### One reliable RemoteEvent

The server creates one `RemoteEvent` and sends messages tagged with a `t` field over it.

| Option | Verdict |
| --- | --- |
| `RemoteEvent` | Used for everything. |
| `RemoteFunction` | No. `InvokeServer` has no timeout, a command can only answer once, an error in the handler surfaces on the client, and the server needs to push the tree anyway. |
| `UnreliableRemoteEvent` | No. Messages may be dropped or arrive out of order, and payloads are capped at about 1 KB. A tree or a `run` must arrive. Suggestions could tolerate a drop, but a full list doesn't fit, and after debouncing the traffic is too small to matter. |

Reliable events on one remote arrive in order, so feedback lines arrive before their `done`.

`Transport.luau` is the only file that touches the remote: `send(player?, message)` and `onMessage(handler)`. Games that use Zap, Blink or ByteNet can replace it.

### Messages

Client to server:

| `t` | Fields | |
| --- | --- | --- |
| `run` | `id`, `line` | Run a command line. |
| `suggest` | `id`, `line`, `cursor` | Ask for remote suggestions at the cursor. |

Server to client:

| `t` | Fields | |
| --- | --- | --- |
| `tree` | `nodes` | The player's filtered tree. Replaces the previous one. |
| `say` | `id`, `text` | Feedback from a running command. |
| `done` | `id`, `ok`, `result?`, `error?` | `error` is `{ message, cursor? }`. `cursor` is set for syntax errors so the console can underline the spot. |
| `suggestions` | `id`, `start`, `items` | `items` is `{ { text, tooltip? } }`. |

`id` is a counter chosen by the client. It ties feedback to a request and lets the client drop suggestion answers for text it no longer shows.

### Tree sync

- The server builds a player's tree by walking the dispatcher with `canUse(source)` and keeping only the nodes that pass, along with any redirects they reach. `requires` never leaves the server.
- It sends the tree when the player joins and again on `server:refresh(player)`, for example after a role change. If the encoded tree hasn't changed since the last send, nothing is sent.
- Optimization for later: if `requires` is declared as a permission level instead of a function, trees can be built once per level and cached.

Wire format, version 1:

```luau
{
	v = 1,
	nodes = {
		{ k = "root", c = { 2, 5 } },
		{ k = "lit", n = "give", c = { 3 } },
		{ k = "arg", n = "player", type = "roblox:player", c = { 4 } },
		{ k = "arg", n = "amount", type = "integer", p = { min = 1, max = 1000000 }, x = true },
		...
	},
}
```

`c` holds child indices, `x` marks an executable node, `r` is a redirect index, `s = true` asks the server for suggestions, and `p` holds the type's properties. Optional fields live in the dictionary part. Remotes truncate arrays that contain `nil`, so never let an array have holes.

When the client gets a type id it doesn't know, it falls back to a `word` type that suggests remotely and doesn't validate. The console still works and the server still validates.

### Running a command

1. The client parses locally for highlighting only, then sends `run`.
2. The server checks the message (a string no longer than 256 characters, a number id) and applies the rate limits.
3. The server builds the source with `config.source(player, reply)`, then parses. Parsing checks `requires` again, so the client's tree is never trusted.
4. On a syntax error it sends `done` with the error and the cursor.
5. Otherwise it executes in a new thread. `reply` sends `say`, and a return or `fail` sends `done`.

Limits per player, all configurable: a token bucket for `run` (5 per second, burst of 10), another for `suggest` (15 per second), and at most 3 commands running at once.

### Suggestions

- The client computes local suggestions immediately: literals and suggestions from argument types it knows.
- If the node under the cursor has `s = true`, it also sends `suggest`, debounced to about 100 ms, and merges the answer. Answers for an older `id` are dropped.
- The server parses the whole line with the real source, so a provider can depend on earlier arguments, as in Brigadier.

## 5. Roblox API

```luau
-- server
local server = Brig.Server.new(dispatcher, {
	source = function(player, reply): Source
		return { player = player, role = Roles.of(player), reply = reply }
	end,
})
server:refresh(player)

-- client
local client = Brig.Client.new()
client:onTree(function() ... end)
local view = client:inspect(line, cursor)
-- view.spans: { { start, stop, kind: "literal" | "argument" | "error" } }
-- view.usage: "give <player> <amount>"
-- view.error: { message, cursor }?
client:suggest(line, cursor, function(suggestions) ... end) -- local first, then merged with remote
local ok, result = client:run(line, function(text) ... end) -- yields until done
```

`inspect` is what a console redraws on every keystroke. It is local and synchronous.

`Chat.luau` (optional) registers a `TextChatCommand` for each top-level literal and passes the text to the same server path.

## 6. Plan

1. Port the core and Brigadier's tests to Lune.
2. Declarative builder, typed handles, `Brig.path` and `Brig.root`.
3. Registry and wire format, with round-trip tests.
4. Server, client and transport, plus the Roblox argument types.
5. A sample place with a minimal console, tested in play mode with two clients.
6. Publish to Wally and pesde.
7. roblox-ts typings.
8. Try it in Fragile Delivery. The admin panel builds forms from the catalog, so it will need a form for each executable path in the tree.

## 7. Open questions

- The name. "Brigadier" is clear but belongs to Mojang's project.
- Whether to offer a chained API (`literal("give"):with(...)`) as well as the table form. One form is simpler to document.
- Client-only commands (local debug toggles) merged into the server tree.
- Whether `requires` should also accept a permission level, which would allow caching trees per level.
- How to get readable type errors for misspelled keys, or whether to accept the current ones.
