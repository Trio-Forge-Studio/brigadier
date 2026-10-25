#!/usr/bin/env node
// Checks the TypeScript examples in Markdown and MDX files against the package in the current directory. Each one
// compiles with rbxtsc against src/. With --run, each also runs in Lune through the package's .lune/example.luau, and a
// `// → text` comment is the next line it prints. A block whose info string contains "nocheck" is skipped. A block
// with group=<name> in its info string follows the earlier blocks of that group in the same file, so a tutorial's
// steps can build on each other. --types <file> adds a declaration file, such as the globals the examples assume.
//
//   check-examples [--run] [--types <file>] <markdown files...>

import { execFileSync, spawnSync } from "node:child_process";
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, join, relative, resolve } from "node:path";
import { parseArgs, stripVTControlCharacters } from "node:util";

const { values: options, positionals: files } = parseArgs({
	options: { run: { type: "boolean", default: false }, types: { type: "string" } },
	allowPositionals: true,
});
if (files.length === 0) {
	console.error("Usage: check-examples [--run] [--types <file>] <markdown files...>");
	process.exit(2);
}

const root = process.cwd();
const { name: packageName } = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const FENCE = /^([ \t]*)```(\w+)([^\n]*)\n([\s\S]*?)\n\1```/gm;
const LANGUAGES = { ts: "ts", typescript: "ts", tsx: "tsx" };

function blocks(file) {
	const text = readFileSync(file, "utf8");
	const found = [];
	const groups = new Map();
	for (const match of text.matchAll(FENCE)) {
		const [, indent, lang, info, body] = match;
		const extension = LANGUAGES[lang];
		if (info.includes("nocheck") || !extension) continue;
		const line = text.slice(0, match.index).split("\n").length + 1;
		const code = body
			.split("\n")
			.map((row) => (row.startsWith(indent) ? row.slice(indent.length) : row))
			.join("\n");
		const name = /\bgroup=(\S+)/.exec(info)?.[1];
		const group = name ? (groups.get(name) ?? { code: "", tsx: false }) : undefined;
		const prefix = group?.code ?? "";
		if (group) {
			group.code += code + "\n";
			group.tsx ||= extension === "tsx";
			groups.set(name, group);
		}
		found.push({ file, line, code, prefix, group, extension });
	}
	// A group's earlier blocks repeat in every later one, so the whole group compiles as TSX once any block needs it.
	for (const example of found) if (example.group?.tsx) example.extension = "tsx";
	return found;
}

const examples = files.flatMap(blocks);

// rbxtsc copies its whole root folder into the output, so the examples compile in a project of their own, beside a
// copy of the package's source.
const work = join(root, ".snippets");
const project = join(work, "project");
rmSync(work, { recursive: true, force: true });
mkdirSync(join(project, "examples"), { recursive: true });
cpSync(join(root, "src"), join(project, "src"), { recursive: true });
if (options.types) cpSync(resolve(options.types), join(project, "examples", "types.d.ts"));
const byFile = new Map();
examples.forEach((example, index) => {
	example.name = `${basename(example.file).replace(/\W/g, "-")}-${index}`;
	const file = `${example.name}.${example.extension}`;
	byFile.set(file, example);
	writeFileSync(join(project, "examples", file), example.prefix + example.code + "\n");
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
			paths: { [packageName]: ["./src/index.ts"] },
		},
		include: ["examples", "src"],
	}),
);

const where = (example, row = 1) => `${relative(process.cwd(), example.file)}:${example.line + row - 1}`;
const rbxtsc = join(root, "node_modules", "roblox-ts", "out", "CLI", "cli.js");
const compiled = spawnSync(process.execPath, [rbxtsc, "--type", "package", "-p", project], { encoding: "utf8" });
const output = stripVTControlCharacters(compiled.stdout + compiled.stderr);
for (const row of output.split(/\r?\n/).filter(Boolean)) {
	const match = /(?:^|[/])([^/:]+\.tsx?):(\d+):(\d+) - (.*)$/.exec(row);
	const example = match && byFile.get(match[1]);
	if (example) {
		// A group's earlier blocks come first. Errors there are reported for those blocks.
		const offset = Number(match[2]) - (example.prefix.split("\n").length - 1);
		if (offset >= 1) console.log(`${where(example, offset)}:${match[3]} ${match[4]}`);
	} else if (match || /error/i.test(row)) {
		console.log(row);
	}
}

if (compiled.status !== 0) {
	console.log(`${examples.length} examples, compile failed`);
	process.exit(1);
}
if (!options.run) {
	console.log(`${examples.length} examples compiled`);
	process.exit(0);
}

let failed = 0;
for (const example of examples) {
	let printed;
	try {
		printed = execFileSync("lune", ["run", "example", example.name], { encoding: "utf8", stdio: "pipe" });
	} catch (error) {
		failed++;
		console.log(`${where(example)} example failed`);
		console.log(String(error.stderr || error.stdout || error.message).trim());
		continue;
	}
	const expected = [...(example.prefix + example.code).matchAll(/^[ \t]*\/\/ → ?(.*)$/gm)].map((match) => match[1]);
	const rows = printed.split(/\r?\n/).filter((row) => row !== "");
	if (expected.length > 0 && expected.join("\n") !== rows.join("\n")) {
		failed++;
		console.log(`${where(example)} example printed something else`);
		console.log(`expected:\n  ${expected.join("\n  ")}\nprinted:\n  ${rows.join("\n  ")}`);
	}
}
console.log(failed === 0 ? `${examples.length} examples passed` : `${examples.length} examples, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
