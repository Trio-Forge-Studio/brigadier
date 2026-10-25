import type { ArgumentType } from "./arguments";
import type {
	AmbiguityConsumer,
	Command,
	Predicate,
	RedirectModifier,
	SingleRedirectModifier,
	SuggestionProvider,
} from "./command";
import { type CommandContext, type CommandContextBuilder, ParsedArgument, StringRange } from "./context";
import { CommandSyntaxException, catchSyntax } from "./exceptions";
import {
	IllegalStateException,
	UnsupportedOperationException,
	compareStrings,
	objectsEquals,
	startsWith,
	substring,
	toLowerCase,
} from "./java";
import { StringReader } from "./string-reader";
import { Suggestions, type SuggestionsBuilder } from "./suggestion";

// Nodes create builders and builders create nodes, so both live in this module.

function always(): boolean {
	return true;
}

export abstract class CommandNode<S> {
	private readonly children = new Map<string, CommandNode<S>>();
	private readonly childList: CommandNode<S>[] = [];
	private readonly literals = new Map<string, LiteralCommandNode<S>>();
	private readonly argumentList: ArgumentCommandNode<S, unknown>[] = [];

	protected constructor(
		private command: Command<S> | undefined,
		private readonly requirement: Predicate<S>,
		private readonly redirect: CommandNode<S> | undefined,
		private readonly modifier: RedirectModifier<S> | undefined,
		private readonly forks: boolean,
	) {}

	getCommand(): Command<S> | undefined {
		return this.command;
	}

	// The node's own list, in insertion order. Don't modify it.
	getChildren(): readonly CommandNode<S>[] {
		return this.childList;
	}

	getChild(name: string): CommandNode<S> | undefined {
		return this.children.get(name);
	}

	getRedirect(): CommandNode<S> | undefined {
		return this.redirect;
	}

	getRedirectModifier(): RedirectModifier<S> | undefined {
		return this.modifier;
	}

	canUse(source: S): boolean {
		return this.requirement(source);
	}

	addChild(node: CommandNode<S>) {
		if (node instanceof RootCommandNode) {
			throw new UnsupportedOperationException("Cannot add a RootCommandNode as a child to any other CommandNode");
		}

		const child = this.children.get(node.getName());
		if (child !== undefined) {
			// We've found something to merge onto
			const command = node.getCommand();
			if (command !== undefined) {
				child.command = command;
			}
			for (const grandchild of node.getChildren()) {
				child.addChild(grandchild);
			}
		} else {
			this.children.set(node.getName(), node);
			this.childList.push(node);
			if (node instanceof LiteralCommandNode) {
				this.literals.set(node.getName(), node as LiteralCommandNode<S>);
			} else if (node instanceof ArgumentCommandNode) {
				this.argumentList.push(node as ArgumentCommandNode<S, unknown>);
			}
		}
	}

	findAmbiguities(consumer: AmbiguityConsumer<S>) {
		let matches: string[] = [];

		for (const child of this.childList) {
			for (const sibling of this.childList) {
				if (rawequal(child, sibling)) {
					continue;
				}

				for (const input of child.getExamples()) {
					if (sibling.isValidInput(input) && !matches.includes(input)) {
						matches.push(input);
					}
				}

				if (matches.size() > 0) {
					consumer(this, child, sibling, matches);
					matches = [];
				}
			}

			child.findAmbiguities(consumer);
		}
	}

	abstract isValidInput(input: string): boolean;

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof CommandNode)) {
			return false;
		}
		const that = other as CommandNode<S>;

		for (const [name, node] of this.children) {
			const match = that.children.get(name);
			if (match === undefined || !node.equals(match)) {
				return false;
			}
		}
		for (const [name] of that.children) {
			if (!this.children.has(name)) {
				return false;
			}
		}
		if (this.command !== undefined ? !objectsEquals(this.command, that.command) : that.command !== undefined) {
			return false;
		}

		return true;
	}

	getRequirement(): Predicate<S> {
		return this.requirement;
	}

	abstract getName(): string;

	abstract getUsageText(): string;

	abstract parse(reader: StringReader, contextBuilder: CommandContextBuilder<S>): void;

	abstract listSuggestions(context: CommandContext<S>, builder: SuggestionsBuilder): Promise<Suggestions>;

	abstract createBuilder(): ArgumentBuilder<S>;

	abstract getSortedKey(): string;

	getRelevantNodes(input: StringReader): readonly CommandNode<S>[] {
		if (!this.literals.isEmpty()) {
			const cursor = input.getCursor();
			while (input.canRead() && input.peek() !== " ") {
				input.skip();
			}
			const text = substring(input.getString(), cursor, input.getCursor());
			input.setCursor(cursor);
			const literal = this.literals.get(text);
			if (literal !== undefined) {
				return [literal];
			}
		}
		return this.argumentList;
	}

	compareTo(other: CommandNode<S>): number {
		if (this instanceof LiteralCommandNode === other instanceof LiteralCommandNode) {
			return compareStrings(this.getSortedKey(), other.getSortedKey());
		}

		return other instanceof LiteralCommandNode ? 1 : -1;
	}

	isFork(): boolean {
		return this.forks;
	}

	abstract getExamples(): readonly string[];
}

function sourceOfContext<S>(context: CommandContext<S>): readonly S[] {
	return [context.getSource()];
}

export class RootCommandNode<S> extends CommandNode<S> {
	constructor() {
		super(undefined, always, undefined, sourceOfContext, false);
	}

	getName(): string {
		return "";
	}

	getUsageText(): string {
		return "";
	}

	parse() {}

	listSuggestions(): Promise<Suggestions> {
		return Suggestions.empty();
	}

	isValidInput(): boolean {
		return false;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof RootCommandNode)) {
			return false;
		}
		return super.equals(other);
	}

	createBuilder(): ArgumentBuilder<S> {
		throw new IllegalStateException("Cannot convert root into a builder");
	}

	getSortedKey(): string {
		return "";
	}

	getExamples(): readonly string[] {
		return [];
	}

	toString(): string {
		return "<root>";
	}
}

export class LiteralCommandNode<S> extends CommandNode<S> {
	private readonly literalLowerCase: string;

	constructor(
		private readonly literal: string,
		command: Command<S> | undefined,
		requirement: Predicate<S>,
		redirect: CommandNode<S> | undefined,
		modifier: RedirectModifier<S> | undefined,
		forks: boolean,
	) {
		super(command, requirement, redirect, modifier, forks);
		this.literalLowerCase = toLowerCase(literal);
	}

	getLiteral(): string {
		return this.literal;
	}

	getName(): string {
		return this.literal;
	}

	// The end of the literal, or -1 when the input doesn't start with it.
	private parseLiteral(reader: StringReader): number {
		const start = reader.getCursor();
		if (reader.canRead(this.literal.size())) {
			const finish = start + this.literal.size();
			if (substring(reader.getString(), start, finish) === this.literal) {
				reader.setCursor(finish);
				if (!reader.canRead() || reader.peek() === " ") {
					return finish;
				}
				reader.setCursor(start);
			}
		}
		return -1;
	}

	parse(reader: StringReader, contextBuilder: CommandContextBuilder<S>) {
		const start = reader.getCursor();
		const finish = this.parseLiteral(reader);
		if (finish > -1) {
			contextBuilder.withNode(this, StringRange.between(start, finish));
			return;
		}

		throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.literalIncorrect().createWithContext(reader, this.literal);
	}

	listSuggestions(_context: CommandContext<S>, builder: SuggestionsBuilder): Promise<Suggestions> {
		if (startsWith(this.literalLowerCase, builder.getRemainingLowerCase())) {
			return builder.suggest(this.literal).buildFuture();
		}
		return Suggestions.empty();
	}

	isValidInput(input: string): boolean {
		return this.parseLiteral(new StringReader(input)) > -1;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof LiteralCommandNode)) {
			return false;
		}
		if (this.literal !== other.literal) {
			return false;
		}
		return super.equals(other);
	}

	getUsageText(): string {
		return this.literal;
	}

	createBuilder(): LiteralArgumentBuilder<S> {
		const builder = literal<S>(this.literal);
		builder.requires(this.getRequirement());
		builder.forward(this.getRedirect(), this.getRedirectModifier(), this.isFork());
		const command = this.getCommand();
		if (command !== undefined) {
			builder.executes(command);
		}
		return builder;
	}

	getSortedKey(): string {
		return this.literal;
	}

	getExamples(): readonly string[] {
		return [this.literal];
	}

	toString(): string {
		return `<literal ${this.literal}>`;
	}
}

const USAGE_ARGUMENT_OPEN = "<";
const USAGE_ARGUMENT_CLOSE = ">";

export class ArgumentCommandNode<S, T> extends CommandNode<S> {
	constructor(
		private readonly name: string,
		private readonly argumentType: ArgumentType<T>,
		command: Command<S> | undefined,
		requirement: Predicate<S>,
		redirect: CommandNode<S> | undefined,
		modifier: RedirectModifier<S> | undefined,
		forks: boolean,
		private readonly customSuggestions: SuggestionProvider<S> | undefined,
	) {
		super(command, requirement, redirect, modifier, forks);
	}

	getType(): ArgumentType<T> {
		return this.argumentType;
	}

	getName(): string {
		return this.name;
	}

	getUsageText(): string {
		return USAGE_ARGUMENT_OPEN + this.name + USAGE_ARGUMENT_CLOSE;
	}

	getCustomSuggestions(): SuggestionProvider<S> | undefined {
		return this.customSuggestions;
	}

	parse(reader: StringReader, contextBuilder: CommandContextBuilder<S>) {
		const start = reader.getCursor();
		const result = this.argumentType.parse(reader, contextBuilder.getSource());
		const parsed = new ParsedArgument<T>(start, reader.getCursor(), result);

		contextBuilder.withArgument(this.name, parsed);
		contextBuilder.withNode(this, parsed.getRange());
	}

	listSuggestions(context: CommandContext<S>, builder: SuggestionsBuilder): Promise<Suggestions> {
		if (this.customSuggestions === undefined) {
			return this.argumentType.listSuggestions?.(context, builder) ?? Suggestions.empty();
		}
		return this.customSuggestions(context, builder);
	}

	createBuilder(): RequiredArgumentBuilder<S, T> {
		const builder = argument<S, T>(this.name, this.argumentType);
		builder.requires(this.getRequirement());
		builder.forward(this.getRedirect(), this.getRedirectModifier(), this.isFork());
		builder.suggests(this.customSuggestions);
		const command = this.getCommand();
		if (command !== undefined) {
			builder.executes(command);
		}
		return builder;
	}

	isValidInput(input: string): boolean {
		return catchSyntax(
			() => {
				const reader = new StringReader(input);
				this.argumentType.parse(reader);
				return !reader.canRead() || reader.peek() === " ";
			},
			() => false,
		);
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof ArgumentCommandNode)) {
			return false;
		}
		if (this.name !== other.name) {
			return false;
		}
		if (!objectsEquals(this.argumentType, other.argumentType)) {
			return false;
		}
		return super.equals(other);
	}

	getSortedKey(): string {
		return this.name;
	}

	getExamples(): readonly string[] {
		return this.argumentType.getExamples?.() ?? [];
	}

	toString(): string {
		return `<argument ${this.name}:${this.argumentType}>`;
	}
}

export abstract class ArgumentBuilder<S> {
	private readonly args = new RootCommandNode<S>();
	private command?: Command<S>;
	private requirement: Predicate<S> = always;
	private target?: CommandNode<S>;
	private modifier?: RedirectModifier<S>;
	private forks = false;

	// then(ArgumentBuilder) and then(CommandNode).
	then(argument: ArgumentBuilder<S> | CommandNode<S>): this {
		if (this.target !== undefined) {
			throw new IllegalStateException("Cannot add children to a redirected node");
		}
		this.args.addChild(argument instanceof CommandNode ? argument : argument.build());
		return this;
	}

	getArguments(): readonly CommandNode<S>[] {
		return this.args.getChildren();
	}

	executes(command: Command<S> | undefined): this {
		this.command = command;
		return this;
	}

	getCommand(): Command<S> | undefined {
		return this.command;
	}

	requires(requirement: Predicate<S>): this {
		this.requirement = requirement;
		return this;
	}

	getRequirement(): Predicate<S> {
		return this.requirement;
	}

	redirect(target: CommandNode<S> | undefined, modifier?: SingleRedirectModifier<S>): this {
		if (modifier === undefined) {
			return this.forward(target, undefined, false);
		}
		return this.forward(target, (context) => [modifier(context)], false);
	}

	fork(target: CommandNode<S> | undefined, modifier: RedirectModifier<S> | undefined): this {
		return this.forward(target, modifier, true);
	}

	forward(target: CommandNode<S> | undefined, modifier: RedirectModifier<S> | undefined, fork: boolean): this {
		if (this.args.getChildren().size() > 0) {
			throw new IllegalStateException("Cannot forward a node with children");
		}
		this.target = target;
		this.modifier = modifier;
		this.forks = fork;
		return this;
	}

	getRedirect(): CommandNode<S> | undefined {
		return this.target;
	}

	getRedirectModifier(): RedirectModifier<S> | undefined {
		return this.modifier;
	}

	isFork(): boolean {
		return this.forks;
	}

	abstract build(): CommandNode<S>;
}

export class LiteralArgumentBuilder<S> extends ArgumentBuilder<S> {
	constructor(private readonly literal: string) {
		super();
	}

	getLiteral(): string {
		return this.literal;
	}

	build(): LiteralCommandNode<S> {
		const result = new LiteralCommandNode(
			this.literal,
			this.getCommand(),
			this.getRequirement(),
			this.getRedirect(),
			this.getRedirectModifier(),
			this.isFork(),
		);

		for (const child of this.getArguments()) {
			result.addChild(child);
		}

		return result;
	}
}

export function literal<S>(name: string): LiteralArgumentBuilder<S> {
	return new LiteralArgumentBuilder(name);
}

export class RequiredArgumentBuilder<S, T> extends ArgumentBuilder<S> {
	private suggestionsProvider?: SuggestionProvider<S>;

	constructor(
		private readonly name: string,
		private readonly argumentType: ArgumentType<T>,
	) {
		super();
	}

	suggests(provider: SuggestionProvider<S> | undefined): this {
		this.suggestionsProvider = provider;
		return this;
	}

	getSuggestionsProvider(): SuggestionProvider<S> | undefined {
		return this.suggestionsProvider;
	}

	getType(): ArgumentType<T> {
		return this.argumentType;
	}

	getName(): string {
		return this.name;
	}

	build(): ArgumentCommandNode<S, T> {
		const result = new ArgumentCommandNode(
			this.name,
			this.argumentType,
			this.getCommand(),
			this.getRequirement(),
			this.getRedirect(),
			this.getRedirectModifier(),
			this.isFork(),
			this.getSuggestionsProvider(),
		);

		for (const child of this.getArguments()) {
			result.addChild(child);
		}

		return result;
	}
}

export function argument<S, T>(name: string, argumentType: ArgumentType<T>): RequiredArgumentBuilder<S, T> {
	return new RequiredArgumentBuilder(name, argumentType);
}
