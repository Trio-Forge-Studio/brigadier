# Agent instructions

A line-by-line port of Mojang's Brigadier 1.3, at commit `9ba4f13`, to roblox-ts, published as `@trioforge/brigadier`. Read [docs/porting.md](docs/porting.md) before changing anything under `src/` or `test/`. It fixes the names and the value rules, and lists every place the port differs from the Java.

## Checks

Run every check before you call a change done:

```sh
pnpm run check
```

It runs rbxtsc, StyLua over the Luau tests, the tests against the compiled package, and the README example. Fix the cause of a failure rather than silencing it.

`pnpm run examples <files>` compiles the TypeScript examples in Markdown and MDX files and runs them in Lune, as the root `AGENTS.md` describes. They run as the player that `.lune/example.luau` provides and `.lune/example.d.ts` declares. Run it on the Brigadier docs in `apps/docs` after changing an example or an API:

```sh
pnpm run examples README.md ../../apps/docs/src/content/docs/brigadier/*.mdx ../../apps/docs/src/content/docs/brigadier/*/*.mdx
```

## Porting

- Port behaviour from the Java, not from memory. When the Java and the port disagree, the Java wins unless docs/porting.md records the difference.
- Tests come first and mirror the JUnit tests one to one: same names, same order, same assertions.

## Conventions

- Comment only what the code can't say: a non-obvious reason, a workaround, a trap. Comments the Java had in tests stay.
- Commit messages are Conventional Commits with a scope: `feat(dispatcher): …`, `fix(reader): …`, `test(suggestion): …`, `docs: …`.
