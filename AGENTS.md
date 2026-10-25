# Agent instructions

A line-by-line port of Mojang's Brigadier 1.3, at commit `9ba4f13`, to roblox-ts, published as `@trioforge/brigadier`. Read [docs/porting.md](docs/porting.md) before changing anything under `src/` or `test/`. It fixes the names and the value rules, and lists every place the port differs from the Java.

## Checks

Run every check before you call a change done:

```sh
pnpm run check
```

It runs oxfmt over `src` and `scripts`, rbxtsc, StyLua over the Luau tests, the tests against the compiled package, and the README example. Install the Node tools with `pnpm install`, and Lune and StyLua with `rokit install`. Fix the cause of a failure rather than silencing it.

`node scripts/check-snippets.mjs <files>` compiles the TypeScript examples in Markdown and MDX files with rbxtsc and runs them in Lune. A `// → text` comment is the next line an example prints, and blocks that share `group=<name>` in their info string build on each other. Run it on the website's Brigadier docs after changing an example or an API:

```sh
node scripts/check-snippets.mjs README.md ../website/src/content/docs/brigadier/*.mdx ../website/src/content/docs/brigadier/*/*.mdx
```

## Porting

- Port behaviour from the Java, not from memory. When the Java and the port disagree, the Java wins unless docs/porting.md records the difference.
- Tests come first and mirror the JUnit tests one to one: same names, same order, same assertions.

## Conventions

- Comment only what the code can't say: a non-obvious reason, a workaround, a trap. Comments the Java had in tests stay.
- Commit messages are Conventional Commits with a scope: `feat(dispatcher): …`, `fix(reader): …`, `test(suggestion): …`, `docs: …`.

## Releasing

Releases publish from CI. Bump `version` in `package.json` in a PR and merge it. Then tag that commit on `main` and push the tag:

```sh
git tag v0.2.0 origin/main
git push origin refs/tags/v0.2.0
```

`.github/workflows/release.yml` refuses a tag that isn't on `main` or doesn't match the version, runs `pnpm run check`, and publishes with `npm publish` through npm trusted publishing, with provenance. Don't publish from a machine.
