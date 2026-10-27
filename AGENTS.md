# Agent instructions

A line-by-line port of Mojang's Brigadier 1.3, at commit `9ba4f13`, to roblox-ts, published as `@trioforge/brigadier`. Read [docs/porting.md](docs/porting.md) before changing anything under `src/` or `test/`. It fixes the names and the value rules, and lists every place the port differs from the Java.

## Tools

Run `pnpm install` and `rokit install`. `rokit.toml` pins Lune and StyLua. Vite+ (`vp`) formats and lints the repository from `vite.config.ts`, and `pnpm run fmt` fixes formatting. A pre-commit hook runs `vp check --fix` on staged files.

`tsconfig.json` extends `tsconfig.rbxts.json`, the roblox-ts options every Trio Forge library shares. The example checker, staged release command, and Lune runtime and test runner come from `@trioforge/tooling`. Lune code requires the runtime and runner as `@tooling/runtime` and `@tooling/test` through `.luaurc`. CI and release use the shared workflows in [Trio-Forge-Studio/tooling](https://github.com/Trio-Forge-Studio/tooling). Fix shared tooling in that repository.

## Checks

Run every check before you call a change done:

```sh
pnpm run check
```

It runs `vp check`, rbxtsc, StyLua over the Luau tests, the tests against the compiled package, and the README example. Fix the cause of a failure rather than silencing it.

## Examples

Every TypeScript example in the README and the docs compiles against `src/`. `pnpm run examples <files>` compiles the examples in Markdown and MDX files and runs them in Lune. They run as the player that `.lune/example.luau` provides and `.lune/example.d.ts` declares.

- A `// → text` comment is the next line the example prints.
- Blocks that share `group=<name>` in their info string build on each other. `nocheck` skips a block.

The docs live in the website repository, under `src/content/docs/docs/brigadier/`, and publish at <https://website.trio-forge.workers.dev/docs/brigadier/>. The website checks their examples against the commit of this repository that its `docs-sources.json` pins. After changing an example or an API, check the docs from a website checkout beside this one, and update them in the website PR that moves the pin:

```sh
pnpm run examples README.md ../website/src/content/docs/docs/brigadier/*.mdx ../website/src/content/docs/docs/brigadier/*/*.mdx
```

## Releases

Changesets versions and publishes the package. A PR that changes what the package ships adds a changeset with `pnpm changeset`, which says whether it takes a patch, minor or major bump. On `main`, `.github/workflows/release.yml` keeps a "chore(release): version packages" PR open that applies the changesets and writes `CHANGELOG.md`. Merging that PR stages the new version through npm trusted publishing. The trusted publisher may only stage, so the version goes live once a maintainer approves it with 2FA on npmjs.com or with `npm stage approve`. Don't publish from a machine.

CI fails a PR that changes `src/` without a changeset. A change that ships nothing, such as tests, docs or tooling, needs none.

## Lockfile

The lockfile records the pinned pnpm under `packageManagerDependencies`, and CI's frozen install fails without it. A Vite+ shell sets `PNPM_CONFIG_PM_ON_FAIL=ignore`, which stops pnpm writing that block. If it goes missing, regenerate the lockfile:

```sh
env -u PNPM_CONFIG_PM_ON_FAIL -u PNPM_CONFIG_RUNTIME_ON_FAIL pnpm install
```

## Porting

- Port behaviour from the Java, not from memory. When the Java and the port disagree, the Java wins unless docs/porting.md records the difference.
- Tests come first and mirror the JUnit tests one to one: same names, same order, same assertions.

## Conventions

- Comment only what the code can't say: a non-obvious reason, a workaround, a trap. Comments the Java had in tests stay.
- Commit messages are Conventional Commits with a scope: `feat(dispatcher): …`, `fix(reader): …`, `test(suggestion): …`, `docs: …`.
