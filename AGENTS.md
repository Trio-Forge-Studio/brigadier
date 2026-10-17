# Agent instructions

A line-by-line port of Mojang's Brigadier to strict Luau. Read [docs/porting.md](docs/porting.md) before changing anything under `src/` or `test/`: it fixes the names, the overload and value rules, and lists every place the port differs from Java. The Java source it follows is Brigadier 1.3 at commit `9ba4f13`.

## Checks

Run every check before you call a change done:

```sh
bash scripts/check.sh
```

It runs StyLua, selene, luau-lsp with the new type solver over `src`, `test`, `bench` and `.lune`, and the test suite (`lune run test`). Install the tools with `rokit install`, and run `lune setup` once. Fix the cause of a failure rather than silencing it.

## Porting

- Port behaviour from the Java, not from memory. When the Java and the port disagree, the Java wins unless docs/porting.md records the difference.
- Tests come first and mirror the JUnit tests one to one: same names, same order, same assertions. Tests of the port's own behaviour go in `test/port/`.
- Add a class's instance methods to `src/Types.luau` as `read` properties taking `self: any`, and its constructors and statics to the module surface in docs/porting.md.

## Conventions

- Comment only what the code can't say: a non-obvious reason, a workaround, a trap. Comments the Java had in tests stay.
- Commit messages are Conventional Commits with a scope: `feat(dispatcher): …`, `fix(reader): …`, `test(suggestion): …`, `docs: …`.
