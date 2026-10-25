import type { Command, RedirectModifier, ResultConsumer } from "./command";
import type { CommandDispatcher } from "./command-dispatcher";
import { catchSyntax } from "./exceptions";
import { IllegalArgumentException, IllegalStateException, objectsEquals, substring } from "./java";
import type { ImmutableStringReader } from "./string-reader";
import type { CommandNode } from "./tree";

export class StringRange {
	constructor(
		private readonly start: number,
		private readonly finish: number,
	) {}

	static at(pos: number): StringRange {
		return new StringRange(pos, pos);
	}

	static between(start: number, finish: number): StringRange {
		return new StringRange(start, finish);
	}

	static encompassing(a: StringRange, b: StringRange): StringRange {
		return new StringRange(math.min(a.getStart(), b.getStart()), math.max(a.getEnd(), b.getEnd()));
	}

	getStart(): number {
		return this.start;
	}

	getEnd(): number {
		return this.finish;
	}

	get(reader: ImmutableStringReader | string): string {
		return substring(typeIs(reader, "string") ? reader : reader.getString(), this.start, this.finish);
	}

	isEmpty(): boolean {
		return this.start === this.finish;
	}

	getLength(): number {
		return this.finish - this.start;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof StringRange)) {
			return false;
		}
		return this.start === other.start && this.finish === other.finish;
	}

	toString(): string {
		return `StringRange{start=${this.start}, end=${this.finish}}`;
	}
}

export class ParsedArgument<T> {
	private readonly range: StringRange;

	constructor(
		start: number,
		finish: number,
		private readonly result: T,
	) {
		this.range = StringRange.between(start, finish);
	}

	getRange(): StringRange {
		return this.range;
	}

	getResult(): T {
		return this.result;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof ParsedArgument)) {
			return false;
		}
		return objectsEquals(this.range, other.range) && objectsEquals(this.result, other.result);
	}
}

export class ParsedCommandNode<S> {
	constructor(
		private readonly node: CommandNode<S>,
		private readonly range: StringRange,
	) {}

	getNode(): CommandNode<S> {
		return this.node;
	}

	getRange(): StringRange {
		return this.range;
	}

	toString(): string {
		return `${this.node}@${this.range}`;
	}

	// Java compares getClass(), so an instance of a subclass is never equal to a ParsedCommandNode.
	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!typeIs(other, "table") || getmetatable(other) !== getmetatable(this)) {
			return false;
		}
		const that = other as ParsedCommandNode<S>;
		return objectsEquals(this.node, that.node) && objectsEquals(this.range, that.range);
	}
}

export class SuggestionContext<S> {
	constructor(
		readonly context: CommandContextBuilder<S>,
		readonly parent: CommandNode<S>,
		readonly startPos: number,
	) {}
}

interface Checkable {
	any: unknown;
}

// What Class.isAssignableFrom checks against: a Luau type name such as "number" or "Vector3", "any" for Object,
// or a class.
export type ArgumentClass = keyof CheckableTypes | keyof Checkable | (new (...args: never[]) => object);

function isAssignable(clazz: ArgumentClass, value: unknown): boolean {
	if (clazz === "any") {
		return true;
	}
	if (typeIs(clazz, "string")) {
		return typeOf(value) === clazz;
	}
	if (typeIs(clazz, "table")) {
		return value instanceof clazz;
	}
	throw new IllegalArgumentException(`Unknown argument class ${tostring(clazz)}`);
}

export class CommandContext<S> {
	constructor(
		private readonly source: S,
		private readonly input: string,
		private readonly args: ReadonlyMap<string, ParsedArgument<unknown>>,
		private readonly command: Command<S> | undefined,
		private readonly rootNode: CommandNode<S>,
		private readonly nodes: readonly ParsedCommandNode<S>[],
		private readonly range: StringRange,
		private readonly child: CommandContext<S> | undefined,
		private readonly modifier: RedirectModifier<S> | undefined,
		private readonly forks: boolean,
	) {}

	copyFor(source: S): CommandContext<S> {
		if (rawequal(this.source, source)) {
			return this;
		}
		return new CommandContext(
			source,
			this.input,
			this.args,
			this.command,
			this.rootNode,
			this.nodes,
			this.range,
			this.child,
			this.modifier,
			this.forks,
		);
	}

	getChild(): CommandContext<S> | undefined {
		return this.child;
	}

	getLastChild(): CommandContext<S> {
		let result = this.child;
		if (result === undefined) {
			return this;
		}
		let child = result.getChild();
		while (child !== undefined) {
			result = child;
			child = result.getChild();
		}
		return result;
	}

	getCommand(): Command<S> | undefined {
		return this.command;
	}

	getSource(): S {
		return this.source;
	}

	getArgument<V>(name: string, clazz: ArgumentClass): V {
		const argument = this.args.get(name);

		if (argument === undefined) {
			throw new IllegalArgumentException(`No such argument '${name}' exists on this command`);
		}

		const result = argument.getResult();
		if (isAssignable(clazz, result)) {
			return result as V;
		}
		throw new IllegalArgumentException(
			`Argument '${name}' is defined as ${typeOf(result)}, not ${tostring(clazz)}`,
		);
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof CommandContext)) {
			return false;
		}
		const that = other as CommandContext<S>;

		if (!objectsEquals(this.args, that.args)) {
			return false;
		}
		if (!this.rootNode.equals(that.rootNode)) {
			return false;
		}
		if (this.nodes.size() !== that.nodes.size() || !objectsEquals(this.nodes, that.nodes)) {
			return false;
		}
		if (this.command !== undefined ? !objectsEquals(this.command, that.command) : that.command !== undefined) {
			return false;
		}
		if (!objectsEquals(this.source, that.source)) {
			return false;
		}
		if (this.child !== undefined ? !this.child.equals(that.child) : that.child !== undefined) {
			return false;
		}

		return true;
	}

	getRedirectModifier(): RedirectModifier<S> | undefined {
		return this.modifier;
	}

	getRange(): StringRange {
		return this.range;
	}

	getInput(): string {
		return this.input;
	}

	getRootNode(): CommandNode<S> {
		return this.rootNode;
	}

	getNodes(): readonly ParsedCommandNode<S>[] {
		return this.nodes;
	}

	hasNodes(): boolean {
		return this.nodes.size() > 0;
	}

	isForked(): boolean {
		return this.forks;
	}
}

export class CommandContextBuilder<S> {
	private readonly args = new Map<string, ParsedArgument<unknown>>();
	private readonly nodes: ParsedCommandNode<S>[] = [];
	private command?: Command<S>;
	private child?: CommandContextBuilder<S>;
	private range: StringRange;
	private modifier?: RedirectModifier<S>;
	private forks = false;

	constructor(
		private readonly dispatcher: CommandDispatcher<S>,
		private source: S,
		private readonly rootNode: CommandNode<S>,
		start: number,
	) {
		this.range = StringRange.at(start);
	}

	withSource(source: S): this {
		this.source = source;
		return this;
	}

	getSource(): S {
		return this.source;
	}

	getRootNode(): CommandNode<S> {
		return this.rootNode;
	}

	withArgument(name: string, argument: ParsedArgument<unknown>): this {
		this.args.set(name, argument);
		return this;
	}

	getArguments(): ReadonlyMap<string, ParsedArgument<unknown>> {
		return this.args;
	}

	withCommand(command: Command<S> | undefined): this {
		this.command = command;
		return this;
	}

	withNode(node: CommandNode<S>, range: StringRange): this {
		this.nodes.push(new ParsedCommandNode(node, range));
		this.range = StringRange.encompassing(this.range, range);
		this.modifier = node.getRedirectModifier();
		this.forks = node.isFork();
		return this;
	}

	// Java's copy() leaves the modifier at its initial null.
	copy(): CommandContextBuilder<S> {
		const copy = new CommandContextBuilder(this.dispatcher, this.source, this.rootNode, this.range.getStart());
		copy.command = this.command;
		for (const [name, argument] of this.args) {
			copy.args.set(name, argument);
		}
		for (const node of this.nodes) {
			copy.nodes.push(node);
		}
		copy.child = this.child;
		copy.range = this.range;
		copy.forks = this.forks;
		return copy;
	}

	withChild(child: CommandContextBuilder<S>): this {
		this.child = child;
		return this;
	}

	getChild(): CommandContextBuilder<S> | undefined {
		return this.child;
	}

	getLastChild(): CommandContextBuilder<S> {
		let result = this.child;
		if (result === undefined) {
			return this;
		}
		let child = result.getChild();
		while (child !== undefined) {
			result = child;
			child = result.getChild();
		}
		return result;
	}

	getCommand(): Command<S> | undefined {
		return this.command;
	}

	getNodes(): readonly ParsedCommandNode<S>[] {
		return this.nodes;
	}

	build(input: string): CommandContext<S> {
		return new CommandContext(
			this.source,
			input,
			this.args,
			this.command,
			this.rootNode,
			this.nodes,
			this.range,
			this.child?.build(input),
			this.modifier,
			this.forks,
		);
	}

	getDispatcher(): CommandDispatcher<S> {
		return this.dispatcher;
	}

	getRange(): StringRange {
		return this.range;
	}

	findSuggestionContext(cursor: number): SuggestionContext<S> {
		if (this.range.getStart() <= cursor) {
			if (this.range.getEnd() < cursor) {
				if (this.child !== undefined) {
					return this.child.findSuggestionContext(cursor);
				} else if (this.nodes.size() > 0) {
					const last = this.nodes[this.nodes.size() - 1];
					return new SuggestionContext(this, last.getNode(), last.getRange().getEnd() + 1);
				}
				return new SuggestionContext(this, this.rootNode, this.range.getStart());
			}
			let prev = this.rootNode;
			for (const node of this.nodes) {
				const nodeRange = node.getRange();
				if (nodeRange.getStart() <= cursor && cursor <= nodeRange.getEnd()) {
					return new SuggestionContext(this, prev, nodeRange.getStart());
				}
				prev = node.getNode();
			}
			return new SuggestionContext(this, prev, this.range.getStart());
		}
		throw new IllegalStateException("Can't find node before cursor");
	}
}

export class ContextChain<S> {
	static readonly Stage = {
		MODIFY: "MODIFY",
		EXECUTE: "EXECUTE",
	} as const;

	private nextStageCache?: ContextChain<S>;

	// TODO ideally those two would have separate types, but modifiers and executables expect full context
	constructor(
		private readonly modifiers: readonly CommandContext<S>[],
		private readonly executable: CommandContext<S>,
	) {
		if (executable.getCommand() === undefined) {
			throw new IllegalArgumentException("Last command in chain must be executable");
		}
	}

	static tryFlatten<S>(rootContext: CommandContext<S>): ContextChain<S> | undefined {
		const modifiers: CommandContext<S>[] = [];

		let current = rootContext;

		while (true) {
			const child = current.getChild();
			if (child === undefined) {
				// Last entry must be executable command
				if (current.getCommand() === undefined) {
					return undefined;
				}

				return new ContextChain(modifiers, current);
			}

			modifiers.push(current);
			current = child;
		}
	}

	static runModifier<S>(
		modifier: CommandContext<S>,
		source: S,
		resultConsumer: ResultConsumer<S>,
		forkedMode: boolean,
	): readonly S[] {
		const sourceModifier = modifier.getRedirectModifier();

		// Note: source currently in context is irrelevant at this point, since we might have updated it in one of earlier stages
		if (sourceModifier === undefined) {
			// Simple redirect, just propagate source to next node
			return [source];
		}

		const contextToUse = modifier.copyFor(source);
		return catchSyntax(
			() => sourceModifier(contextToUse),
			(ex) => {
				resultConsumer(contextToUse, false, 0);
				if (forkedMode) {
					return [];
				}
				throw ex;
			},
		);
	}

	static runExecutable<S>(
		executable: CommandContext<S>,
		source: S,
		resultConsumer: ResultConsumer<S>,
		forkedMode: boolean,
	): number {
		const contextToUse = executable.copyFor(source);
		return catchSyntax(
			() => {
				const result = executable.getCommand()!(contextToUse);
				resultConsumer(contextToUse, true, result);
				return forkedMode ? 1 : result;
			},
			(ex) => {
				resultConsumer(contextToUse, false, 0);
				if (forkedMode) {
					return 0;
				}
				throw ex;
			},
		);
	}

	executeAll(source: S, resultConsumer: ResultConsumer<S>): number {
		if (this.modifiers.size() === 0) {
			// Fast path - just a single stage
			return ContextChain.runExecutable(this.executable, source, resultConsumer, false);
		}

		let forkedMode = false;
		let currentSources: readonly S[] = [source];

		for (const modifier of this.modifiers) {
			forkedMode ||= modifier.isForked();

			const nextSources: S[] = [];
			for (const sourceToRun of currentSources) {
				for (const nextSource of ContextChain.runModifier(modifier, sourceToRun, resultConsumer, forkedMode)) {
					nextSources[nextSources.size()] = nextSource;
				}
			}
			if (nextSources.size() === 0) {
				return 0;
			}
			currentSources = nextSources;
		}

		let result = 0;
		for (const executionSource of currentSources) {
			result += ContextChain.runExecutable(this.executable, executionSource, resultConsumer, forkedMode);
		}

		return result;
	}

	getStage(): (typeof ContextChain.Stage)[keyof typeof ContextChain.Stage] {
		return this.modifiers.size() === 0 ? ContextChain.Stage.EXECUTE : ContextChain.Stage.MODIFY;
	}

	getTopContext(): CommandContext<S> {
		if (this.modifiers.size() === 0) {
			return this.executable;
		}
		return this.modifiers[0];
	}

	nextStage(): ContextChain<S> | undefined {
		const modifierCount = this.modifiers.size();
		if (modifierCount === 0) {
			return undefined;
		}

		if (this.nextStageCache === undefined) {
			const rest: CommandContext<S>[] = [];
			for (let index = 1; index < modifierCount; index++) {
				rest.push(this.modifiers[index]);
			}
			this.nextStageCache = new ContextChain(rest, this.executable);
		}
		return this.nextStageCache;
	}
}
