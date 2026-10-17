--!strict

-- The shape of every Brigadier class. The classes refer to each other in cycles that Luau can't
-- follow across modules, so they are declared together here and each module implements one.

local Types = {}

export type Message = {
	read getString: (self: any) -> string,
}

export type ImmutableStringReader = {
	read getString: (self: any) -> string,
	read getRemainingLength: (self: any) -> number,
	read getTotalLength: (self: any) -> number,
	read getCursor: (self: any) -> number,
	read getRead: (self: any) -> string,
	read getRemaining: (self: any) -> string,
	read canRead: (self: any, length: number?) -> boolean,
	read peek: (self: any, offset: number?) -> string,
}

export type StringReader = {
	read getString: (self: any) -> string,
	read getRemainingLength: (self: any) -> number,
	read getTotalLength: (self: any) -> number,
	read getCursor: (self: any) -> number,
	read getRead: (self: any) -> string,
	read getRemaining: (self: any) -> string,
	read canRead: (self: any, length: number?) -> boolean,
	read peek: (self: any, offset: number?) -> string,
	read setCursor: (self: any, cursor: number) -> (),
	read read: (self: any) -> string,
	read skip: (self: any) -> (),
	read skipWhitespace: (self: any) -> (),
	read readInt: (self: any) -> number,
	read readLong: (self: any) -> number,
	read readDouble: (self: any) -> number,
	read readFloat: (self: any) -> number,
	read readUnquotedString: (self: any) -> string,
	read readQuotedString: (self: any) -> string,
	read readStringUntil: (self: any, terminator: string) -> string,
	read readString: (self: any) -> string,
	read readBoolean: (self: any) -> boolean,
	read expect: (self: any, c: string) -> (),
}

export type StringRange = {
	read getStart: (self: any) -> number,
	read getEnd: (self: any) -> number,
	read get: (self: any, readerOrString: ImmutableStringReader | string) -> string,
	read isEmpty: (self: any) -> boolean,
	read getLength: (self: any) -> number,
	read equals: (self: any, other: unknown) -> boolean,
}

-- A marker, like Java's CommandExceptionType interface: any table can be an exception type.
export type CommandExceptionType = {}

export type CommandSyntaxException = {
	read getMessage: (self: any) -> string,
	read getRawMessage: (self: any) -> Message,
	read getContext: (self: any) -> string?,
	read getType: (self: any) -> CommandExceptionType,
	read getInput: (self: any) -> string?,
	read getCursor: (self: any) -> number,
	-- Throwable.getStackTrace: the traceback where the exception was created, or nil when
	-- ENABLE_COMMAND_STACK_TRACES was off.
	read getStackTrace: (self: any) -> string?,
}

export type SimpleCommandExceptionType = {
	read create: (self: any) -> CommandSyntaxException,
	read createWithContext: (self: any, reader: ImmutableStringReader) -> CommandSyntaxException,
}

export type DynamicCommandExceptionType = {
	read create: (self: any, arg: unknown) -> CommandSyntaxException,
	read createWithContext: (self: any, reader: ImmutableStringReader, arg: unknown) -> CommandSyntaxException,
}

export type Dynamic2CommandExceptionType = {
	read create: (self: any, a: unknown, b: unknown) -> CommandSyntaxException,
	read createWithContext: (
		self: any,
		reader: ImmutableStringReader,
		a: unknown,
		b: unknown
	) -> CommandSyntaxException,
}

export type Dynamic3CommandExceptionType = {
	read create: (self: any, a: unknown, b: unknown, c: unknown) -> CommandSyntaxException,
	read createWithContext: (
		self: any,
		reader: ImmutableStringReader,
		a: unknown,
		b: unknown,
		c: unknown
	) -> CommandSyntaxException,
}

export type Dynamic4CommandExceptionType = {
	read create: (self: any, a: unknown, b: unknown, c: unknown, d: unknown) -> CommandSyntaxException,
	read createWithContext: (
		self: any,
		reader: ImmutableStringReader,
		a: unknown,
		b: unknown,
		c: unknown,
		d: unknown
	) -> CommandSyntaxException,
}

export type DynamicNCommandExceptionType = {
	read create: (self: any, a: unknown, ...unknown) -> CommandSyntaxException,
	read createWithContext: (self: any, reader: ImmutableStringReader, ...unknown) -> CommandSyntaxException,
}

export type BuiltInExceptionProvider = {
	read doubleTooLow: (self: any) -> Dynamic2CommandExceptionType,
	read doubleTooHigh: (self: any) -> Dynamic2CommandExceptionType,
	read floatTooLow: (self: any) -> Dynamic2CommandExceptionType,
	read floatTooHigh: (self: any) -> Dynamic2CommandExceptionType,
	read integerTooLow: (self: any) -> Dynamic2CommandExceptionType,
	read integerTooHigh: (self: any) -> Dynamic2CommandExceptionType,
	read longTooLow: (self: any) -> Dynamic2CommandExceptionType,
	read longTooHigh: (self: any) -> Dynamic2CommandExceptionType,
	read literalIncorrect: (self: any) -> DynamicCommandExceptionType,
	read readerExpectedStartOfQuote: (self: any) -> SimpleCommandExceptionType,
	read readerExpectedEndOfQuote: (self: any) -> SimpleCommandExceptionType,
	read readerInvalidEscape: (self: any) -> DynamicCommandExceptionType,
	read readerInvalidBool: (self: any) -> DynamicCommandExceptionType,
	read readerInvalidInt: (self: any) -> DynamicCommandExceptionType,
	read readerExpectedInt: (self: any) -> SimpleCommandExceptionType,
	read readerInvalidLong: (self: any) -> DynamicCommandExceptionType,
	read readerExpectedLong: (self: any) -> SimpleCommandExceptionType,
	read readerInvalidDouble: (self: any) -> DynamicCommandExceptionType,
	read readerExpectedDouble: (self: any) -> SimpleCommandExceptionType,
	read readerInvalidFloat: (self: any) -> DynamicCommandExceptionType,
	read readerExpectedFloat: (self: any) -> SimpleCommandExceptionType,
	read readerExpectedBool: (self: any) -> SimpleCommandExceptionType,
	read readerExpectedSymbol: (self: any) -> DynamicCommandExceptionType,
	read dispatcherUnknownCommand: (self: any) -> SimpleCommandExceptionType,
	read dispatcherUnknownArgument: (self: any) -> SimpleCommandExceptionType,
	read dispatcherExpectedArgumentSeparator: (self: any) -> SimpleCommandExceptionType,
	read dispatcherParseException: (self: any) -> DynamicCommandExceptionType,
}

export type CompletableFuture<T> = {
	read complete: (self: any, value: T) -> boolean,
	read isDone: (self: any) -> boolean,
	read join: (self: any) -> T,
	read getNow: (self: any, valueIfAbsent: T) -> T,
	-- These return a CompletableFuture of another type, which a recursive Luau type can't name.
	read thenApply: (self: any, fn: (T) -> any) -> any,
	read thenRun: (self: any, action: () -> ()) -> any,
}

export type Suggestion = {
	read getRange: (self: any) -> StringRange,
	read getText: (self: any) -> string,
	read getTooltip: (self: any) -> Message?,
	read apply: (self: any, input: string) -> string,
	read equals: (self: any, other: unknown) -> boolean,
	read compareTo: (self: any, other: Suggestion) -> number,
	read compareToIgnoreCase: (self: any, other: Suggestion) -> number,
	read expand: (self: any, command: string, range: StringRange) -> Suggestion,
}

export type IntegerSuggestion = {
	read getRange: (self: any) -> StringRange,
	read getText: (self: any) -> string,
	read getTooltip: (self: any) -> Message?,
	read apply: (self: any, input: string) -> string,
	read equals: (self: any, other: unknown) -> boolean,
	read compareTo: (self: any, other: Suggestion) -> number,
	read compareToIgnoreCase: (self: any, other: Suggestion) -> number,
	read expand: (self: any, command: string, range: StringRange) -> Suggestion,
	read getValue: (self: any) -> number,
}

export type Suggestions = {
	read getRange: (self: any) -> StringRange,
	read getList: (self: any) -> { Suggestion },
	read isEmpty: (self: any) -> boolean,
	read equals: (self: any, other: unknown) -> boolean,
}

export type SuggestionsBuilder = {
	read getInput: (self: any) -> string,
	read getStart: (self: any) -> number,
	read getRemaining: (self: any) -> string,
	read getRemainingLowerCase: (self: any) -> string,
	read build: (self: any) -> Suggestions,
	read buildFuture: (self: any) -> CompletableFuture<Suggestions>,
	read suggest: (self: any, textOrValue: string | number, tooltip: Message?) -> SuggestionsBuilder,
	read add: (self: any, other: SuggestionsBuilder) -> SuggestionsBuilder,
	read createOffset: (self: any, start: number) -> SuggestionsBuilder,
	read restart: (self: any) -> SuggestionsBuilder,
}

export type Command<S> = (context: CommandContext<S>) -> number
export type Predicate<S> = (source: S) -> boolean
export type RedirectModifier<S> = (context: CommandContext<S>) -> { S }
export type SingleRedirectModifier<S> = (context: CommandContext<S>) -> S
export type ResultConsumer<S> = (context: CommandContext<S>, success: boolean, result: number) -> ()
export type AmbiguityConsumer<S> = (
	parent: CommandNode<S>,
	child: CommandNode<S>,
	sibling: CommandNode<S>,
	inputs: { string }
) -> ()
export type SuggestionProvider<S> = (
	context: CommandContext<S>,
	builder: SuggestionsBuilder
) -> CompletableFuture<Suggestions>

-- Java's interface default methods are optional here: a type without listSuggestions suggests
-- nothing, and one without getExamples has none. The fields are read-only so that a type which
-- does define them, such as IntegerArgumentType, still counts as an ArgumentType.
export type ArgumentType<T> = {
	read parse: (self: any, reader: StringReader, source: any?) -> T,
	read listSuggestions: ((
		self: any,
		context: CommandContext<any>,
		builder: SuggestionsBuilder
	) -> CompletableFuture<Suggestions>)?,
	read getExamples: ((self: any) -> { string })?,
}

export type ParsedArgument<S, T> = {
	read getRange: (self: any) -> StringRange,
	read getResult: (self: any) -> T,
	read equals: (self: any, other: unknown) -> boolean,
}

export type ParsedCommandNode<S> = {
	read getNode: (self: any) -> CommandNode<S>,
	read getRange: (self: any) -> StringRange,
	read equals: (self: any, other: unknown) -> boolean,
}

export type SuggestionContext<S> = {
	read context: CommandContextBuilder<S>,
	read parent: CommandNode<S>,
	read startPos: number,
}

export type CommandContext<S> = {
	read copyFor: (self: any, source: S) -> CommandContext<S>,
	read getChild: (self: any) -> CommandContext<S>?,
	read getLastChild: (self: any) -> CommandContext<S>,
	read getCommand: (self: any) -> Command<S>?,
	read getSource: (self: any) -> S,
	-- The class is a Luau type name ("number", "string", "boolean", "Vector3", ...) or a class
	-- with isInstance. The result is `any` for the same reason Java's is an unchecked cast.
	read getArgument: (self: any, name: string, class: any) -> any,
	read equals: (self: any, other: unknown) -> boolean,
	read getRedirectModifier: (self: any) -> RedirectModifier<S>?,
	read getRange: (self: any) -> StringRange,
	read getInput: (self: any) -> string,
	read getRootNode: (self: any) -> CommandNode<S>,
	read getNodes: (self: any) -> { ParsedCommandNode<S> },
	read hasNodes: (self: any) -> boolean,
	read isForked: (self: any) -> boolean,
}

export type CommandContextBuilder<S> = {
	read withSource: (self: any, source: S) -> CommandContextBuilder<S>,
	read getSource: (self: any) -> S,
	read getRootNode: (self: any) -> CommandNode<S>,
	read withArgument: (self: any, name: string, argument: ParsedArgument<S, any>) -> CommandContextBuilder<S>,
	read getArguments: (self: any) -> { [string]: ParsedArgument<S, any> },
	read withCommand: (self: any, command: Command<S>?) -> CommandContextBuilder<S>,
	read withNode: (self: any, node: CommandNode<S>, range: StringRange) -> CommandContextBuilder<S>,
	read copy: (self: any) -> CommandContextBuilder<S>,
	read withChild: (self: any, child: CommandContextBuilder<S>) -> CommandContextBuilder<S>,
	read getChild: (self: any) -> CommandContextBuilder<S>?,
	read getLastChild: (self: any) -> CommandContextBuilder<S>,
	read getCommand: (self: any) -> Command<S>?,
	read getNodes: (self: any) -> { ParsedCommandNode<S> },
	read build: (self: any, input: string) -> CommandContext<S>,
	read getDispatcher: (self: any) -> CommandDispatcher<S>,
	read getRange: (self: any) -> StringRange,
	read findSuggestionContext: (self: any, cursor: number) -> SuggestionContext<S>,
}

export type ContextChainStage = "MODIFY" | "EXECUTE"

export type ContextChain<S> = {
	read executeAll: (self: any, source: S, resultConsumer: ResultConsumer<S>) -> number,
	read getStage: (self: any) -> ContextChainStage,
	read getTopContext: (self: any) -> CommandContext<S>,
	read nextStage: (self: any) -> ContextChain<S>?,
}

-- The subclasses of CommandNode and ArgumentBuilder repeat their parent's methods instead of
-- intersecting with it, which the new solver handles far better.

export type CommandNode<S> = {
	read getCommand: (self: any) -> Command<S>?,
	read getChildren: (self: any) -> { CommandNode<S> },
	read getChild: (self: any, name: string) -> CommandNode<S>?,
	read getRedirect: (self: any) -> CommandNode<S>?,
	read getRedirectModifier: (self: any) -> RedirectModifier<S>?,
	read canUse: (self: any, source: S) -> boolean,
	read addChild: (self: any, node: CommandNode<S>) -> (),
	read findAmbiguities: (self: any, consumer: AmbiguityConsumer<S>) -> (),
	read isValidInput: (self: any, input: string) -> boolean,
	read equals: (self: any, other: unknown) -> boolean,
	read getRequirement: (self: any) -> Predicate<S>,
	read getName: (self: any) -> string,
	read getUsageText: (self: any) -> string,
	read parse: (self: any, reader: StringReader, contextBuilder: CommandContextBuilder<S>) -> (),
	read listSuggestions: (
		self: any,
		context: CommandContext<S>,
		builder: SuggestionsBuilder
	) -> CompletableFuture<Suggestions>,
	read getSortedKey: (self: any) -> string,
	read getRelevantNodes: (self: any, input: StringReader) -> { CommandNode<S> },
	read compareTo: (self: any, other: CommandNode<S>) -> number,
	read isFork: (self: any) -> boolean,
	read getExamples: (self: any) -> { string },
	read createBuilder: (self: any) -> ArgumentBuilder<S>,
}

export type RootCommandNode<S> = CommandNode<S>

export type LiteralCommandNode<S> = {
	read getCommand: (self: any) -> Command<S>?,
	read getChildren: (self: any) -> { CommandNode<S> },
	read getChild: (self: any, name: string) -> CommandNode<S>?,
	read getRedirect: (self: any) -> CommandNode<S>?,
	read getRedirectModifier: (self: any) -> RedirectModifier<S>?,
	read canUse: (self: any, source: S) -> boolean,
	read addChild: (self: any, node: CommandNode<S>) -> (),
	read findAmbiguities: (self: any, consumer: AmbiguityConsumer<S>) -> (),
	read isValidInput: (self: any, input: string) -> boolean,
	read equals: (self: any, other: unknown) -> boolean,
	read getRequirement: (self: any) -> Predicate<S>,
	read getName: (self: any) -> string,
	read getUsageText: (self: any) -> string,
	read parse: (self: any, reader: StringReader, contextBuilder: CommandContextBuilder<S>) -> (),
	read listSuggestions: (
		self: any,
		context: CommandContext<S>,
		builder: SuggestionsBuilder
	) -> CompletableFuture<Suggestions>,
	read getSortedKey: (self: any) -> string,
	read getRelevantNodes: (self: any, input: StringReader) -> { CommandNode<S> },
	read compareTo: (self: any, other: CommandNode<S>) -> number,
	read isFork: (self: any) -> boolean,
	read getExamples: (self: any) -> { string },
	read createBuilder: (self: any) -> LiteralArgumentBuilder<S>,
	read getLiteral: (self: any) -> string,
}

export type ArgumentCommandNode<S, T> = {
	read getCommand: (self: any) -> Command<S>?,
	read getChildren: (self: any) -> { CommandNode<S> },
	read getChild: (self: any, name: string) -> CommandNode<S>?,
	read getRedirect: (self: any) -> CommandNode<S>?,
	read getRedirectModifier: (self: any) -> RedirectModifier<S>?,
	read canUse: (self: any, source: S) -> boolean,
	read addChild: (self: any, node: CommandNode<S>) -> (),
	read findAmbiguities: (self: any, consumer: AmbiguityConsumer<S>) -> (),
	read isValidInput: (self: any, input: string) -> boolean,
	read equals: (self: any, other: unknown) -> boolean,
	read getRequirement: (self: any) -> Predicate<S>,
	read getName: (self: any) -> string,
	read getUsageText: (self: any) -> string,
	read parse: (self: any, reader: StringReader, contextBuilder: CommandContextBuilder<S>) -> (),
	read listSuggestions: (
		self: any,
		context: CommandContext<S>,
		builder: SuggestionsBuilder
	) -> CompletableFuture<Suggestions>,
	read getSortedKey: (self: any) -> string,
	read getRelevantNodes: (self: any, input: StringReader) -> { CommandNode<S> },
	read compareTo: (self: any, other: CommandNode<S>) -> number,
	read isFork: (self: any) -> boolean,
	read getExamples: (self: any) -> { string },
	read createBuilder: (self: any) -> RequiredArgumentBuilder<S, T>,
	read getType: (self: any) -> ArgumentType<T>,
	read getCustomSuggestions: (self: any) -> SuggestionProvider<S>?,
}

-- Any builder. Java's ArgumentBuilder<S, T extends ArgumentBuilder<S, T>> returns the concrete
-- builder from every chained call, which the concrete types below do.
export type ArgumentBuilder<S> = {
	read with: (self: any, argument: ArgumentBuilder<S> | CommandNode<S>) -> any,
	read getArguments: (self: any) -> { CommandNode<S> },
	read executes: (self: any, command: Command<S>?) -> any,
	read getCommand: (self: any) -> Command<S>?,
	read requires: (self: any, requirement: Predicate<S>) -> any,
	read getRequirement: (self: any) -> Predicate<S>,
	read redirect: (self: any, target: CommandNode<S>?, modifier: SingleRedirectModifier<S>?) -> any,
	read fork: (self: any, target: CommandNode<S>?, modifier: RedirectModifier<S>?) -> any,
	read forward: (self: any, target: CommandNode<S>?, modifier: RedirectModifier<S>?, fork: boolean) -> any,
	read getRedirect: (self: any) -> CommandNode<S>?,
	read getRedirectModifier: (self: any) -> RedirectModifier<S>?,
	read isFork: (self: any) -> boolean,
	read build: (self: any) -> CommandNode<S>,
}

export type LiteralArgumentBuilder<S> = {
	read with: (self: any, argument: ArgumentBuilder<S> | CommandNode<S>) -> LiteralArgumentBuilder<S>,
	read getArguments: (self: any) -> { CommandNode<S> },
	read executes: (self: any, command: Command<S>?) -> LiteralArgumentBuilder<S>,
	read getCommand: (self: any) -> Command<S>?,
	read requires: (self: any, requirement: Predicate<S>) -> LiteralArgumentBuilder<S>,
	read getRequirement: (self: any) -> Predicate<S>,
	read redirect: (
		self: any,
		target: CommandNode<S>?,
		modifier: SingleRedirectModifier<S>?
	) -> LiteralArgumentBuilder<S>,
	read fork: (self: any, target: CommandNode<S>?, modifier: RedirectModifier<S>?) -> LiteralArgumentBuilder<S>,
	read forward: (
		self: any,
		target: CommandNode<S>?,
		modifier: RedirectModifier<S>?,
		fork: boolean
	) -> LiteralArgumentBuilder<S>,
	read getRedirect: (self: any) -> CommandNode<S>?,
	read getRedirectModifier: (self: any) -> RedirectModifier<S>?,
	read isFork: (self: any) -> boolean,
	read getLiteral: (self: any) -> string,
	read build: (self: any) -> LiteralCommandNode<S>,
}

export type RequiredArgumentBuilder<S, T> = {
	read with: (self: any, argument: ArgumentBuilder<S> | CommandNode<S>) -> RequiredArgumentBuilder<S, T>,
	read getArguments: (self: any) -> { CommandNode<S> },
	read executes: (self: any, command: Command<S>?) -> RequiredArgumentBuilder<S, T>,
	read getCommand: (self: any) -> Command<S>?,
	read requires: (self: any, requirement: Predicate<S>) -> RequiredArgumentBuilder<S, T>,
	read getRequirement: (self: any) -> Predicate<S>,
	read redirect: (
		self: any,
		target: CommandNode<S>?,
		modifier: SingleRedirectModifier<S>?
	) -> RequiredArgumentBuilder<S, T>,
	read fork: (self: any, target: CommandNode<S>?, modifier: RedirectModifier<S>?) -> RequiredArgumentBuilder<S, T>,
	read forward: (
		self: any,
		target: CommandNode<S>?,
		modifier: RedirectModifier<S>?,
		fork: boolean
	) -> RequiredArgumentBuilder<S, T>,
	read getRedirect: (self: any) -> CommandNode<S>?,
	read getRedirectModifier: (self: any) -> RedirectModifier<S>?,
	read isFork: (self: any) -> boolean,
	read suggests: (self: any, provider: SuggestionProvider<S>?) -> RequiredArgumentBuilder<S, T>,
	read getSuggestionsProvider: (self: any) -> SuggestionProvider<S>?,
	read getType: (self: any) -> ArgumentType<T>,
	read getName: (self: any) -> string,
	read build: (self: any) -> ArgumentCommandNode<S, T>,
}

export type ParseResults<S> = {
	read getContext: (self: any) -> CommandContextBuilder<S>,
	read getReader: (self: any) -> ImmutableStringReader,
	read getExceptions: (self: any) -> { [CommandNode<S>]: CommandSyntaxException },
}

export type CommandDispatcher<S> = {
	read register: (self: any, command: LiteralArgumentBuilder<S>) -> LiteralCommandNode<S>,
	read setConsumer: (self: any, consumer: ResultConsumer<S>) -> (),
	read execute: (self: any, input: string | StringReader | ParseResults<S>, source: S?) -> number,
	read parse: (self: any, command: string | StringReader, source: S) -> ParseResults<S>,
	read getAllUsage: (self: any, node: CommandNode<S>, source: S, restricted: boolean) -> { string },
	read getSmartUsage: (self: any, node: CommandNode<S>, source: S) -> { [CommandNode<S>]: string },
	read getCompletionSuggestions: (
		self: any,
		parse: ParseResults<S>,
		cursor: number?
	) -> CompletableFuture<Suggestions>,
	read getRoot: (self: any) -> RootCommandNode<S>,
	read getPath: (self: any, target: CommandNode<S>) -> { string },
	read findNode: (self: any, path: { string }) -> CommandNode<S>?,
	read findAmbiguities: (self: any, consumer: AmbiguityConsumer<S>) -> (),
}

export type BoolArgumentType = {
	read parse: (self: any, reader: StringReader, source: any?) -> boolean,
	read listSuggestions: (
		self: any,
		context: CommandContext<any>,
		builder: SuggestionsBuilder
	) -> CompletableFuture<Suggestions>,
	read getExamples: (self: any) -> { string },
}

-- IntegerArgumentType, LongArgumentType, DoubleArgumentType and FloatArgumentType.
export type NumberArgumentType = {
	read parse: (self: any, reader: StringReader, source: any?) -> number,
	read getExamples: (self: any) -> { string },
	read getMinimum: (self: any) -> number,
	read getMaximum: (self: any) -> number,
	read equals: (self: any, other: unknown) -> boolean,
}

export type IntegerArgumentType = NumberArgumentType
export type LongArgumentType = NumberArgumentType
export type DoubleArgumentType = NumberArgumentType
export type FloatArgumentType = NumberArgumentType

-- A Java enum constant: StringArgumentType.StringType.SINGLE_WORD and the other two.
export type StringType = {
	read name: (self: any) -> string,
	read getExamples: (self: any) -> { string },
}

export type StringArgumentType = {
	read parse: (self: any, reader: StringReader, source: any?) -> string,
	read getExamples: (self: any) -> { string },
	read getType: (self: any) -> StringType,
}

return Types
