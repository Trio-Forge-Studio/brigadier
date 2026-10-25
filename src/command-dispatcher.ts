import type { AmbiguityConsumer, ResultConsumer } from "./command";
import { CommandContextBuilder, ContextChain } from "./context";
import { CommandSyntaxException } from "./exceptions";
import { rethrow, stableSort, substring, toLowerCase } from "./java";
import { type ImmutableStringReader, StringReader } from "./string-reader";
import { Suggestions, SuggestionsBuilder } from "./suggestion";
import { type CommandNode, type LiteralArgumentBuilder, type LiteralCommandNode, RootCommandNode } from "./tree";

export class ParseResults<S> {
	private readonly reader: ImmutableStringReader;
	private readonly exceptions: ReadonlyMap<CommandNode<S>, CommandSyntaxException>;

	constructor(
		private readonly context: CommandContextBuilder<S>,
		reader?: ImmutableStringReader,
		exceptions?: ReadonlyMap<CommandNode<S>, CommandSyntaxException>,
	) {
		this.reader = reader ?? new StringReader("");
		this.exceptions = exceptions ?? new Map();
	}

	getContext(): CommandContextBuilder<S> {
		return this.context;
	}

	getReader(): ImmutableStringReader {
		return this.reader;
	}

	getExceptions(): ReadonlyMap<CommandNode<S>, CommandSyntaxException> {
		return this.exceptions;
	}
}

const ARGUMENT_SEPARATOR = " ";

const USAGE_OPTIONAL_OPEN = "[";
const USAGE_OPTIONAL_CLOSE = "]";
const USAGE_REQUIRED_OPEN = "(";
const USAGE_REQUIRED_CLOSE = ")";
const USAGE_OR = "|";

function ignoreResult() {}

// The message of an error that isn't a CommandSyntaxException, as RuntimeException.getMessage gives it.
function messageOf(err: unknown): string | undefined {
	if (typeIs(err, "table") && typeIs((err as { getMessage?: unknown }).getMessage, "function")) {
		return (err as { getMessage(): string | undefined }).getMessage();
	}
	return tostring(err);
}

function hasCommandSyntaxExceptions<S>(parse: ParseResults<S>): boolean {
	return !parse.getExceptions().isEmpty();
}

function compareParses<S>(a: ParseResults<S>, b: ParseResults<S>): number {
	if (!a.getReader().canRead() && b.getReader().canRead()) {
		return -1;
	}
	if (a.getReader().canRead() && !b.getReader().canRead()) {
		return 1;
	}
	if (!hasCommandSyntaxExceptions(a) && hasCommandSyntaxExceptions(b)) {
		return -1;
	}
	if (hasCommandSyntaxExceptions(a) && !hasCommandSyntaxExceptions(b)) {
		return 1;
	}
	return 0;
}

export class CommandDispatcher<S> {
	static readonly ARGUMENT_SEPARATOR = ARGUMENT_SEPARATOR;
	static readonly ARGUMENT_SEPARATOR_CHAR = ARGUMENT_SEPARATOR;

	private readonly root: RootCommandNode<S>;
	private consumer: ResultConsumer<S> = ignoreResult;

	constructor(root?: RootCommandNode<S>) {
		this.root = root ?? new RootCommandNode();
	}

	register(command: LiteralArgumentBuilder<S>): LiteralCommandNode<S> {
		const build = command.build();
		this.root.addChild(build);
		return build;
	}

	setConsumer(consumer: ResultConsumer<S>) {
		this.consumer = consumer;
	}

	// execute(String, S), execute(StringReader, S) and execute(ParseResults).
	execute(input: string | StringReader, source: S): number;
	execute(parse: ParseResults<S>): number;
	execute(input: string | StringReader | ParseResults<S>, source?: S): number {
		if (input instanceof ParseResults) {
			return this.executeParse(input);
		}
		return this.executeParse(this.parse(input, source as S));
	}

	private executeParse(parse: ParseResults<S>): number {
		if (parse.getReader().canRead()) {
			const exceptions = parse.getExceptions();
			if (exceptions.size() === 1) {
				for (const [, exception] of exceptions) {
					throw exception;
				}
			} else if (parse.getContext().getRange().isEmpty()) {
				throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.dispatcherUnknownCommand().createWithContext(
					parse.getReader(),
				);
			}
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.dispatcherUnknownArgument().createWithContext(
				parse.getReader(),
			);
		}

		const command = parse.getReader().getString();
		const original = parse.getContext().build(command);

		const flatContext = ContextChain.tryFlatten(original);
		if (flatContext === undefined) {
			this.consumer(original, false, 0);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.dispatcherUnknownCommand().createWithContext(
				parse.getReader(),
			);
		}

		return flatContext.executeAll(original.getSource(), this.consumer);
	}

	parse(command: string | StringReader, source: S): ParseResults<S> {
		const reader = typeIs(command, "string") ? new StringReader(command) : command;
		const context = new CommandContextBuilder(this, source, this.root, reader.getCursor());
		return this.parseNodes(this.root, reader, context);
	}

	private parseNodes(
		node: CommandNode<S>,
		originalReader: StringReader,
		contextSoFar: CommandContextBuilder<S>,
	): ParseResults<S> {
		const source = contextSoFar.getSource();
		let errors: Map<CommandNode<S>, CommandSyntaxException> | undefined;
		let potentials: ParseResults<S>[] | undefined;
		const cursor = originalReader.getCursor();

		for (const child of node.getRelevantNodes(originalReader)) {
			if (!child.canUse(source)) {
				continue;
			}
			const context = contextSoFar.copy();
			const reader = new StringReader(originalReader);
			let exception: CommandSyntaxException | undefined;
			try {
				child.parse(reader, context);
				if (reader.canRead() && reader.peek() !== ARGUMENT_SEPARATOR) {
					exception =
						CommandSyntaxException.BUILT_IN_EXCEPTIONS.dispatcherExpectedArgumentSeparator().createWithContext(
							reader,
						);
				}
			} catch (err) {
				exception =
					err instanceof CommandSyntaxException
						? err
						: CommandSyntaxException.BUILT_IN_EXCEPTIONS.dispatcherParseException().createWithContext(
								reader,
								messageOf(err),
							);
			}
			if (exception !== undefined) {
				errors ??= new Map();
				errors.set(child, exception);
				reader.setCursor(cursor);
				continue;
			}

			context.withCommand(child.getCommand());
			const redirect = child.getRedirect();
			if (reader.canRead(redirect === undefined ? 2 : 1)) {
				reader.skip();
				if (redirect !== undefined) {
					const childContext = new CommandContextBuilder(this, source, redirect, reader.getCursor());
					const parse = this.parseNodes(redirect, reader, childContext);
					context.withChild(parse.getContext());
					return new ParseResults(context, parse.getReader(), parse.getExceptions());
				}
				const parse = this.parseNodes(child, reader, context);
				potentials ??= [];
				potentials.push(parse);
			} else {
				potentials ??= [];
				potentials.push(new ParseResults(context, reader, new Map()));
			}
		}

		if (potentials !== undefined) {
			if (potentials.size() > 1) {
				stableSort(potentials, compareParses);
			}
			return potentials[0];
		}

		return new ParseResults(contextSoFar, originalReader, errors ?? new Map());
	}

	getAllUsage(node: CommandNode<S>, source: S, restricted: boolean): string[] {
		const result: string[] = [];
		this.getAllUsageRecursive(node, source, result, "", restricted);
		return result;
	}

	private getAllUsageRecursive(
		node: CommandNode<S>,
		source: S,
		result: string[],
		prefix: string,
		restricted: boolean,
	) {
		if (restricted && !node.canUse(source)) {
			return;
		}

		if (node.getCommand() !== undefined) {
			result.push(prefix);
		}

		const redirect = node.getRedirect();
		if (redirect !== undefined) {
			const redirectText = rawequal(redirect, this.root) ? "..." : "-> " + redirect.getUsageText();
			result.push(
				prefix === ""
					? node.getUsageText() + ARGUMENT_SEPARATOR + redirectText
					: prefix + ARGUMENT_SEPARATOR + redirectText,
			);
		} else {
			for (const child of node.getChildren()) {
				this.getAllUsageRecursive(
					child,
					source,
					result,
					prefix === "" ? child.getUsageText() : prefix + ARGUMENT_SEPARATOR + child.getUsageText(),
					restricted,
				);
			}
		}
	}

	// Java returns a LinkedHashMap. The map has no order, so iterate node.getChildren() to get it.
	getSmartUsage(node: CommandNode<S>, source: S): Map<CommandNode<S>, string> {
		const result = new Map<CommandNode<S>, string>();

		const optional = node.getCommand() !== undefined;
		for (const child of node.getChildren()) {
			const usage = this.getSmartUsageRecursive(child, source, optional, false);
			if (usage !== undefined) {
				result.set(child, usage);
			}
		}
		return result;
	}

	private getSmartUsageRecursive(
		node: CommandNode<S>,
		source: S,
		optional: boolean,
		deep: boolean,
	): string | undefined {
		if (!node.canUse(source)) {
			return undefined;
		}

		const selfUsage = optional
			? USAGE_OPTIONAL_OPEN + node.getUsageText() + USAGE_OPTIONAL_CLOSE
			: node.getUsageText();
		const childOptional = node.getCommand() !== undefined;
		const open = childOptional ? USAGE_OPTIONAL_OPEN : USAGE_REQUIRED_OPEN;
		const close = childOptional ? USAGE_OPTIONAL_CLOSE : USAGE_REQUIRED_CLOSE;

		if (!deep) {
			const redirect = node.getRedirect();
			if (redirect !== undefined) {
				const redirectText = rawequal(redirect, this.root) ? "..." : "-> " + redirect.getUsageText();
				return selfUsage + ARGUMENT_SEPARATOR + redirectText;
			}
			const children = node.getChildren().filter((child) => child.canUse(source));
			if (children.size() === 1) {
				const usage = this.getSmartUsageRecursive(children[0], source, childOptional, childOptional);
				if (usage !== undefined) {
					return selfUsage + ARGUMENT_SEPARATOR + usage;
				}
			} else if (children.size() > 1) {
				// A LinkedHashSet<String>.
				const childUsage: string[] = [];
				for (const child of children) {
					const usage = this.getSmartUsageRecursive(child, source, childOptional, true);
					if (usage !== undefined && !childUsage.includes(usage)) {
						childUsage.push(usage);
					}
				}
				if (childUsage.size() === 1) {
					const usage = childUsage[0];
					return (
						selfUsage +
						ARGUMENT_SEPARATOR +
						(childOptional ? USAGE_OPTIONAL_OPEN + usage + USAGE_OPTIONAL_CLOSE : usage)
					);
				} else if (childUsage.size() > 1) {
					let builder = open;
					let count = 0;
					for (const child of children) {
						if (count > 0) {
							builder += USAGE_OR;
						}
						builder += child.getUsageText();
						count++;
					}
					if (count > 0) {
						builder += close;
						return selfUsage + ARGUMENT_SEPARATOR + builder;
					}
				}
			}
		}

		return selfUsage;
	}

	getCompletionSuggestions(parse: ParseResults<S>, cursor?: number): Promise<Suggestions> {
		const cursorPosition = cursor ?? parse.getReader().getTotalLength();
		const context = parse.getContext();

		const nodeBeforeCursor = context.findSuggestionContext(cursorPosition);
		const parent = nodeBeforeCursor.parent;
		const start = math.min(nodeBeforeCursor.startPos, cursorPosition);

		const fullInput = parse.getReader().getString();
		const truncatedInput = substring(fullInput, 0, cursorPosition);
		const truncatedInputLowerCase = toLowerCase(truncatedInput);
		const futures: Promise<Suggestions>[] = [];
		for (const node of parent.getChildren()) {
			let future = Suggestions.empty();
			try {
				future = node.listSuggestions(
					nodeBeforeCursor.context.build(truncatedInput),
					new SuggestionsBuilder(truncatedInput, truncatedInputLowerCase, start),
				);
			} catch (err) {
				if (!(err instanceof CommandSyntaxException)) {
					rethrow(err);
				}
			}
			futures.push(future);
		}

		// Promise.all's typings lose the element type of an array that isn't a tuple.
		return Promise.all(futures).andThen((suggestions) =>
			Suggestions.merge(fullInput, suggestions as Suggestions[]),
		);
	}

	getRoot(): RootCommandNode<S> {
		return this.root;
	}

	getPath(target: CommandNode<S>): string[] {
		const nodes: CommandNode<S>[][] = [];
		const addPaths = (node: CommandNode<S>, parents: readonly CommandNode<S>[]) => {
			const current = [...parents, node];
			nodes.push(current);
			for (const child of node.getChildren()) {
				addPaths(child, current);
			}
		};
		addPaths(this.root, []);

		for (const list of nodes) {
			if (rawequal(list[list.size() - 1], target)) {
				const result: string[] = [];
				for (const node of list) {
					if (!rawequal(node, this.root)) {
						result.push(node.getName());
					}
				}
				return result;
			}
		}

		return [];
	}

	findNode(path: readonly string[]): CommandNode<S> | undefined {
		let node: CommandNode<S> | undefined = this.root;
		for (const name of path) {
			node = node.getChild(name);
			if (node === undefined) {
				return undefined;
			}
		}
		return node;
	}

	findAmbiguities(consumer: AmbiguityConsumer<S>) {
		this.root.findAmbiguities(consumer);
	}
}
