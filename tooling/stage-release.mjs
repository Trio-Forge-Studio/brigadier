#!/usr/bin/env node
// Stages the package if its version isn't on npm yet, for a maintainer to approve with 2FA on npmjs.com.
// changesets/action runs this on each push to main without changesets, so it only stages on the commit that merged
// the version PR. Anywhere else, a version may already be waiting in the stage queue.

import { execFileSync, spawnSync } from "node:child_process";
import { appendFileSync, mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

const VERSION_PR = "chore(release): version packages";
const subject = execFileSync("git", ["log", "-1", "--format=%s"], { encoding: "utf8" }).trim();
if (!subject.startsWith(VERSION_PR)) {
	console.log(`Nothing to stage: ${JSON.stringify(subject)} isn't the version PR.`);
	process.exit(0);
}

const shell = process.platform === "win32";
const onNpm = (spec) => spawnSync("npm", ["view", spec, "version"], { encoding: "utf8", shell }).stdout.trim() !== "";

const packDir = mkdtempSync(join(tmpdir(), "stage-"));
let failed = false;
for (const manifest of ["package.json"]) {
	const { name, version, private: isPrivate } = JSON.parse(readFileSync(manifest, "utf8"));
	const spec = `${name}@${version}`;
	if (isPrivate || onNpm(spec)) continue;

	const packed = spawnSync("pnpm", ["pack", "--pack-destination", packDir, "--json"], {
		cwd: dirname(manifest),
		encoding: "utf8",
		shell,
	});
	if (packed.status !== 0) {
		console.error(`${spec}: pnpm pack failed\n${packed.stderr}`);
		failed = true;
		continue;
	}
	const tarball = JSON.parse(packed.stdout.slice(packed.stdout.search(/^\{/m))).filename;
	const args = ["stage", "publish", tarball, "--access", "public", "--provenance", ...process.argv.slice(2)];
	const staged = spawnSync("npm", args, {
		stdio: "inherit",
		shell,
	});
	if (staged.status !== 0) {
		console.error(`${spec}: npm stage publish failed`);
		failed = true;
		continue;
	}
	console.log(`${spec}: staged. Approve it on npmjs.com.`);
	// changesets/action reads these events to push the git tag and create the GitHub release.
	if (process.env.CHANGESETS_OUTPUT) {
		appendFileSync(
			process.env.CHANGESETS_OUTPUT,
			JSON.stringify({ type: "git-tag", tag: spec, packageName: name }) + "\n",
		);
	}
}
process.exit(failed ? 1 : 0);
