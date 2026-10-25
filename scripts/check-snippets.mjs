// Checks the TypeScript examples in Markdown and MDX files against this package. Each one compiles with rbxtsc
// against src/ and runs in Lune. A `// → text` comment is the next line the example prints. A block whose info string
// contains "nocheck" is skipped. A block with group=<name> in its info string runs after the earlier blocks of that
// group in the same file, so a tutorial's steps can build on each other.
//
//   node scripts/check-snippets.mjs README.md ../../apps/docs/src/content/docs/brigadier/*.mdx ../../apps/docs/src/content/docs/brigadier/*/*.mdx

import { execFileSync, spawnSync } from "node:child_process";
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { stripVTControlCharacters } from "node:util";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const files = process.argv.slice(2);
if (files.length === 0) {
	console.error("Usage: node scripts/check-snippets.mjs <markdown files...>");
	process.exit(2);
}

const FENCE = /^([ \t]*)```(\w+)([^\n]*)\n([\s\S]*?)\n\1```/gm;
const TS = new Set(["ts", "typescript"]);
// Examples run as if a player typed them. The declaration stands in for that player, whom .lune/example.luau provides.
const PRELUDE = "declare const player: Player;\n";

function blocks(file) {
	const text = readFileSync(file, "utf8");
	const found = [];
	const groups = new Map();
	for (const match of text.matchAll(FENCE)) {
		const [, indent, lang, info, body] = match;
		if (info.includes("nocheck") || !TS.has(lang)) continue;
		const line = text.slice(0, match.index).split("\n").length + 1;
		const code = body
			.split("\n")
			.map((row) => (row.startsWith(indent) ? row.slice(indent.length) : row))
			.join("\n");
		const group = /\bgroup=(\S+)/.exec(info)?.[1];
		const prefix = group ? (groups.get(group) ?? "") : "";
		if (group) groups.set(group, prefix + code + "\n");
		found.push({ file, line, code, prefix });
	}
	return found;
}

const examples = files.flatMap(blocks);
let failed = 0;

// rbxtsc copies its whole root folder into the output, so the examples compile in a project of their own, beside a
// copy of the package's source.
const work = join(root, ".snippets");
const project = join(work, "project");
rmSync(work, { recursive: true, force: true });
mkdirSync(join(project, "examples"), { recursive: true });
cpSync(join(root, "src"), join(project, "src"), { recursive: true });
const byName = new Map();
examples.forEach((example, index) => {
	example.name = `${basename(example.file).replace(/\W/g, "-")}-${index}`;
	byName.set(`${example.name}.ts`, example);
	writeFileSync(join(project, "examples", `${example.name}.ts`), PRELUDE + example.prefix + example.code + "\n");
});
writeFileSync(
	join(project, "tsconfig.json"),
	JSON.stringify({
		extends: "../../tsconfig.json",
		compilerOptions: {
			rootDir: ".",
			outDir: "../out",
			declaration: false,
			tsBuildInfoFile: "../tsbuildinfo",
			baseUrl: ".",
			typeRoots: ["node_modules/@rbxts", "../../node_modules/@rbxts"],
			paths: { "@trioforge/brigadier": ["./src/index.ts"] },
		},
		include: ["examples", "src"],
	}),
);

const where = (example, row = 1) => `${relative(process.cwd(), example.file)}:${example.line + row - 1}`;
const rbxtsc = join(root, "node_modules", "roblox-ts", "out", "CLI", "cli.js");
const compiled = spawnSync(process.execPath, [rbxtsc, "--type", "package", "-p", project], {
	cwd: root,
	encoding: "utf8",
});
const text = stripVTControlCharacters(compiled.stdout + compiled.stderr);
for (const row of text.split(/\r?\n/).filter(Boolean)) {
	const match = /(?:^|[/])([^/:]+\.ts):(\d+):(\d+) - (.*)$/.exec(row);
	const example = match && byName.get(match[1]);
	if (example) {
		// The prelude and a group's earlier blocks come first. Errors there are reported for those blocks.
		const offset = Number(match[2]) - 1 - (example.prefix.split("\n").length - 1);
		if (offset >= 1) console.log(`${where(example, offset)}:${match[3]} ${match[4]}`);
	} else if (match || /error/i.test(row)) {
		console.log(row);
	}
}

if (compiled.status !== 0) {
	failed++;
} else {
	for (const example of examples) {
		let output;
		try {
			output = execFileSync("lune", ["run", "example", example.name], {
				cwd: root,
				encoding: "utf8",
				stdio: "pipe",
			});
		} catch (error) {
			failed++;
			console.log(`${where(example)} example failed`);
			console.log(String(error.stderr || error.stdout || error.message).trim());
			continue;
		}
		const expected = [...(example.prefix + example.code).matchAll(/^[ \t]*\/\/ → ?(.*)$/gm)].map(
			(match) => match[1],
		);
		const printed = output.split(/\r?\n/).filter((row) => row !== "");
		if (expected.length > 0 && expected.join("\n") !== printed.join("\n")) {
			failed++;
			console.log(`${where(example)} example printed something else`);
			console.log(`expected:\n  ${expected.join("\n  ")}\nprinted:\n  ${printed.join("\n  ")}`);
		}
	}
}

console.log(failed === 0 ? `${examples.length} examples passed` : `${examples.length} examples, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
