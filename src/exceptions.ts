import { formatDouble, formatFloat, formatInteger, rethrow, str, substring } from "./java";
import { LiteralMessage, type Message } from "./literal-message";
import type { ImmutableStringReader } from "./string-reader";

// A marker, as in Java: any value that names a kind of syntax error.
export type CommandExceptionType = object;

export class CommandSyntaxException {
	static readonly CONTEXT_AMOUNT = 10;
	static ENABLE_COMMAND_STACK_TRACES = true;
	static BUILT_IN_EXCEPTIONS: BuiltInExceptionProvider;

	private readonly cursor: number;
	private readonly stackTrace?: string;

	constructor(
		private readonly exceptionType: CommandExceptionType,
		private readonly message: Message,
		private readonly input?: string,
		cursor?: number,
	) {
		this.cursor = input === undefined ? -1 : (cursor ?? -1);
		if (CommandSyntaxException.ENABLE_COMMAND_STACK_TRACES) {
			this.stackTrace = debug.traceback(undefined, 2);
		}
	}

	getMessage(): string {
		let message = this.message.getString();
		const context = this.getContext();
		if (context !== undefined) {
			message += ` at position ${this.cursor}: ${context}`;
		}
		return message;
	}

	getRawMessage(): Message {
		return this.message;
	}

	getContext(): string | undefined {
		const input = this.input;
		if (input === undefined || this.cursor < 0) {
			return undefined;
		}
		const cursor = math.min(input.size(), this.cursor);
		let builder = "";
		if (cursor > CommandSyntaxException.CONTEXT_AMOUNT) {
			builder += "...";
		}
		builder += substring(input, math.max(0, cursor - CommandSyntaxException.CONTEXT_AMOUNT), cursor);
		builder += "<--[HERE]";
		return builder;
	}

	getType(): CommandExceptionType {
		return this.exceptionType;
	}

	getInput(): string | undefined {
		return this.input;
	}

	getCursor(): number {
		return this.cursor;
	}

	getStackTrace(): string | undefined {
		return this.stackTrace;
	}

	toString(): string {
		return `com.mojang.brigadier.exceptions.CommandSyntaxException: ${this.getMessage()}`;
	}
}

// Runs `body`, handing a CommandSyntaxException it throws to `onSyntaxException`. Java catches only that checked
// exception, so any other error propagates unchanged.
export function catchSyntax<T>(body: () => T, onSyntaxException: (exception: CommandSyntaxException) => T): T {
	try {
		return body();
	} catch (err) {
		if (err instanceof CommandSyntaxException) {
			return onSyntaxException(err);
		}
		return rethrow(err);
	}
}

export class SimpleCommandExceptionType implements CommandExceptionType {
	constructor(private readonly message: Message) {}

	create(): CommandSyntaxException {
		return new CommandSyntaxException(this, this.message);
	}

	createWithContext(reader: ImmutableStringReader): CommandSyntaxException {
		return new CommandSyntaxException(this, this.message, reader.getString(), reader.getCursor());
	}

	toString(): string {
		return this.message.getString();
	}
}

export class DynamicCommandExceptionType implements CommandExceptionType {
	constructor(private readonly fn: (arg: unknown) => Message) {}

	create(arg: unknown): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(arg));
	}

	createWithContext(reader: ImmutableStringReader, arg: unknown): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(arg), reader.getString(), reader.getCursor());
	}
}

export class Dynamic2CommandExceptionType implements CommandExceptionType {
	constructor(private readonly fn: (a: unknown, b: unknown) => Message) {}

	create(a: unknown, b: unknown): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(a, b));
	}

	createWithContext(reader: ImmutableStringReader, a: unknown, b: unknown): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(a, b), reader.getString(), reader.getCursor());
	}
}

export class Dynamic3CommandExceptionType implements CommandExceptionType {
	constructor(private readonly fn: (a: unknown, b: unknown, c: unknown) => Message) {}

	create(a: unknown, b: unknown, c: unknown): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(a, b, c));
	}

	createWithContext(reader: ImmutableStringReader, a: unknown, b: unknown, c: unknown): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(a, b, c), reader.getString(), reader.getCursor());
	}
}

export class Dynamic4CommandExceptionType implements CommandExceptionType {
	constructor(private readonly fn: (a: unknown, b: unknown, c: unknown, d: unknown) => Message) {}

	create(a: unknown, b: unknown, c: unknown, d: unknown): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(a, b, c, d));
	}

	createWithContext(
		reader: ImmutableStringReader,
		a: unknown,
		b: unknown,
		c: unknown,
		d: unknown,
	): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(a, b, c, d), reader.getString(), reader.getCursor());
	}
}

export class DynamicNCommandExceptionType implements CommandExceptionType {
	constructor(private readonly fn: (args: unknown[]) => Message) {}

	// Java's create(Object a, Object... args) passes only the varargs on and drops `a`.
	create(_a: unknown, ...args: unknown[]): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(args));
	}

	createWithContext(reader: ImmutableStringReader, ...args: unknown[]): CommandSyntaxException {
		return new CommandSyntaxException(this, this.fn(args), reader.getString(), reader.getCursor());
	}
}

export interface BuiltInExceptionProvider {
	doubleTooLow(): Dynamic2CommandExceptionType;
	doubleTooHigh(): Dynamic2CommandExceptionType;
	floatTooLow(): Dynamic2CommandExceptionType;
	floatTooHigh(): Dynamic2CommandExceptionType;
	integerTooLow(): Dynamic2CommandExceptionType;
	integerTooHigh(): Dynamic2CommandExceptionType;
	longTooLow(): Dynamic2CommandExceptionType;
	longTooHigh(): Dynamic2CommandExceptionType;
	literalIncorrect(): DynamicCommandExceptionType;
	readerExpectedStartOfQuote(): SimpleCommandExceptionType;
	readerExpectedEndOfQuote(): SimpleCommandExceptionType;
	readerInvalidEscape(): DynamicCommandExceptionType;
	readerInvalidBool(): DynamicCommandExceptionType;
	readerInvalidInt(): DynamicCommandExceptionType;
	readerExpectedInt(): SimpleCommandExceptionType;
	readerInvalidLong(): DynamicCommandExceptionType;
	readerExpectedLong(): SimpleCommandExceptionType;
	readerInvalidDouble(): DynamicCommandExceptionType;
	readerExpectedDouble(): SimpleCommandExceptionType;
	readerInvalidFloat(): DynamicCommandExceptionType;
	readerExpectedFloat(): SimpleCommandExceptionType;
	readerExpectedBool(): SimpleCommandExceptionType;
	readerExpectedSymbol(): DynamicCommandExceptionType;
	dispatcherUnknownCommand(): SimpleCommandExceptionType;
	dispatcherUnknownArgument(): SimpleCommandExceptionType;
	dispatcherExpectedArgumentSeparator(): SimpleCommandExceptionType;
	dispatcherParseException(): DynamicCommandExceptionType;
}

function literal(text: string): Message {
	return new LiteralMessage(text);
}

const DOUBLE_TOO_SMALL = new Dynamic2CommandExceptionType((found, min) =>
	literal(`Double must not be less than ${formatDouble(min as number)}, found ${formatDouble(found as number)}`),
);
const DOUBLE_TOO_BIG = new Dynamic2CommandExceptionType((found, max) =>
	literal(`Double must not be more than ${formatDouble(max as number)}, found ${formatDouble(found as number)}`),
);

const FLOAT_TOO_SMALL = new Dynamic2CommandExceptionType((found, min) =>
	literal(`Float must not be less than ${formatFloat(min as number)}, found ${formatFloat(found as number)}`),
);
const FLOAT_TOO_BIG = new Dynamic2CommandExceptionType((found, max) =>
	literal(`Float must not be more than ${formatFloat(max as number)}, found ${formatFloat(found as number)}`),
);

const INTEGER_TOO_SMALL = new Dynamic2CommandExceptionType((found, min) =>
	literal(`Integer must not be less than ${formatInteger(min as number)}, found ${formatInteger(found as number)}`),
);
const INTEGER_TOO_BIG = new Dynamic2CommandExceptionType((found, max) =>
	literal(`Integer must not be more than ${formatInteger(max as number)}, found ${formatInteger(found as number)}`),
);

const LONG_TOO_SMALL = new Dynamic2CommandExceptionType((found, min) =>
	literal(`Long must not be less than ${formatInteger(min as number)}, found ${formatInteger(found as number)}`),
);
const LONG_TOO_BIG = new Dynamic2CommandExceptionType((found, max) =>
	literal(`Long must not be more than ${formatInteger(max as number)}, found ${formatInteger(found as number)}`),
);

const LITERAL_INCORRECT = new DynamicCommandExceptionType((expected) => literal(`Expected literal ${str(expected)}`));

const READER_EXPECTED_START_OF_QUOTE = new SimpleCommandExceptionType(literal("Expected quote to start a string"));
const READER_EXPECTED_END_OF_QUOTE = new SimpleCommandExceptionType(literal("Unclosed quoted string"));
const READER_INVALID_ESCAPE = new DynamicCommandExceptionType((character) =>
	literal(`Invalid escape sequence '${str(character)}' in quoted string`),
);
const READER_INVALID_BOOL = new DynamicCommandExceptionType((value) =>
	literal(`Invalid bool, expected true or false but found '${str(value)}'`),
);
const READER_INVALID_INT = new DynamicCommandExceptionType((value) => literal(`Invalid integer '${str(value)}'`));
const READER_EXPECTED_INT = new SimpleCommandExceptionType(literal("Expected integer"));
const READER_INVALID_LONG = new DynamicCommandExceptionType((value) => literal(`Invalid long '${str(value)}'`));
const READER_EXPECTED_LONG = new SimpleCommandExceptionType(literal("Expected long"));
const READER_INVALID_DOUBLE = new DynamicCommandExceptionType((value) => literal(`Invalid double '${str(value)}'`));
const READER_EXPECTED_DOUBLE = new SimpleCommandExceptionType(literal("Expected double"));
const READER_INVALID_FLOAT = new DynamicCommandExceptionType((value) => literal(`Invalid float '${str(value)}'`));
const READER_EXPECTED_FLOAT = new SimpleCommandExceptionType(literal("Expected float"));
const READER_EXPECTED_BOOL = new SimpleCommandExceptionType(literal("Expected bool"));
const READER_EXPECTED_SYMBOL = new DynamicCommandExceptionType((symbol) => literal(`Expected '${str(symbol)}'`));

const DISPATCHER_UNKNOWN_COMMAND = new SimpleCommandExceptionType(literal("Unknown command"));
const DISPATCHER_UNKNOWN_ARGUMENT = new SimpleCommandExceptionType(literal("Incorrect argument for command"));
const DISPATCHER_EXPECTED_ARGUMENT_SEPARATOR = new SimpleCommandExceptionType(
	literal("Expected whitespace to end one argument, but found trailing data"),
);
const DISPATCHER_PARSE_EXCEPTION = new DynamicCommandExceptionType((message) =>
	literal(`Could not parse command: ${str(message)}`),
);

export class BuiltInExceptions implements BuiltInExceptionProvider {
	doubleTooLow() {
		return DOUBLE_TOO_SMALL;
	}

	doubleTooHigh() {
		return DOUBLE_TOO_BIG;
	}

	floatTooLow() {
		return FLOAT_TOO_SMALL;
	}

	floatTooHigh() {
		return FLOAT_TOO_BIG;
	}

	integerTooLow() {
		return INTEGER_TOO_SMALL;
	}

	integerTooHigh() {
		return INTEGER_TOO_BIG;
	}

	longTooLow() {
		return LONG_TOO_SMALL;
	}

	longTooHigh() {
		return LONG_TOO_BIG;
	}

	literalIncorrect() {
		return LITERAL_INCORRECT;
	}

	readerExpectedStartOfQuote() {
		return READER_EXPECTED_START_OF_QUOTE;
	}

	readerExpectedEndOfQuote() {
		return READER_EXPECTED_END_OF_QUOTE;
	}

	readerInvalidEscape() {
		return READER_INVALID_ESCAPE;
	}

	readerInvalidBool() {
		return READER_INVALID_BOOL;
	}

	readerInvalidInt() {
		return READER_INVALID_INT;
	}

	readerExpectedInt() {
		return READER_EXPECTED_INT;
	}

	readerInvalidLong() {
		return READER_INVALID_LONG;
	}

	readerExpectedLong() {
		return READER_EXPECTED_LONG;
	}

	readerInvalidDouble() {
		return READER_INVALID_DOUBLE;
	}

	readerExpectedDouble() {
		return READER_EXPECTED_DOUBLE;
	}

	readerInvalidFloat() {
		return READER_INVALID_FLOAT;
	}

	readerExpectedFloat() {
		return READER_EXPECTED_FLOAT;
	}

	readerExpectedBool() {
		return READER_EXPECTED_BOOL;
	}

	readerExpectedSymbol() {
		return READER_EXPECTED_SYMBOL;
	}

	dispatcherUnknownCommand() {
		return DISPATCHER_UNKNOWN_COMMAND;
	}

	dispatcherUnknownArgument() {
		return DISPATCHER_UNKNOWN_ARGUMENT;
	}

	dispatcherExpectedArgumentSeparator() {
		return DISPATCHER_EXPECTED_ARGUMENT_SEPARATOR;
	}

	dispatcherParseException() {
		return DISPATCHER_PARSE_EXCEPTION;
	}
}

CommandSyntaxException.BUILT_IN_EXCEPTIONS = new BuiltInExceptions();
