import type { CommandContext } from "./context";
import { CommandSyntaxException } from "./exceptions";
import { formatDouble, formatFloat, formatInteger, startsWith, toFloat } from "./java";
import { StringReader } from "./string-reader";
import type { Suggestions, SuggestionsBuilder } from "./suggestion";

// Java's default methods are optional: a type without listSuggestions suggests nothing, and one without
// getExamples has none.
export interface ArgumentType<T> {
	parse(reader: StringReader, source?: unknown): T;
	listSuggestions?<S>(context: CommandContext<S>, builder: SuggestionsBuilder): Promise<Suggestions>;
	getExamples?(): readonly string[];
}

const BOOL_EXAMPLES = ["true", "false"];

export class BoolArgumentType implements ArgumentType<boolean> {
	parse(reader: StringReader): boolean {
		return reader.readBoolean();
	}

	listSuggestions<S>(_context: CommandContext<S>, builder: SuggestionsBuilder): Promise<Suggestions> {
		if (startsWith("true", builder.getRemainingLowerCase())) {
			builder.suggest("true");
		}
		if (startsWith("false", builder.getRemainingLowerCase())) {
			builder.suggest("false");
		}
		return builder.buildFuture();
	}

	getExamples(): readonly string[] {
		return BOOL_EXAMPLES;
	}
}

export function bool(): BoolArgumentType {
	return new BoolArgumentType();
}

export function getBool<S>(context: CommandContext<S>, name: string): boolean {
	return context.getArgument(name, "boolean");
}

const INTEGER_EXAMPLES = ["0", "123", "-123"];
const INTEGER_MIN = -2147483648;
const INTEGER_MAX = 2147483647;

export class IntegerArgumentType implements ArgumentType<number> {
	constructor(
		private readonly minimum: number,
		private readonly maximum: number,
	) {}

	getMinimum(): number {
		return this.minimum;
	}

	getMaximum(): number {
		return this.maximum;
	}

	parse(reader: StringReader): number {
		const start = reader.getCursor();
		const result = reader.readInt();
		if (result < this.minimum) {
			reader.setCursor(start);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.integerTooLow().createWithContext(
				reader,
				result,
				this.minimum,
			);
		}
		if (result > this.maximum) {
			reader.setCursor(start);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.integerTooHigh().createWithContext(
				reader,
				result,
				this.maximum,
			);
		}
		return result;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof IntegerArgumentType)) {
			return false;
		}
		return this.maximum === other.maximum && this.minimum === other.minimum;
	}

	toString(): string {
		if (this.minimum === INTEGER_MIN && this.maximum === INTEGER_MAX) {
			return "integer()";
		} else if (this.maximum === INTEGER_MAX) {
			return `integer(${formatInteger(this.minimum)})`;
		}
		return `integer(${formatInteger(this.minimum)}, ${formatInteger(this.maximum)})`;
	}

	getExamples(): readonly string[] {
		return INTEGER_EXAMPLES;
	}
}

export function integer(min = INTEGER_MIN, max = INTEGER_MAX): IntegerArgumentType {
	return new IntegerArgumentType(min, max);
}

export function getInteger<S>(context: CommandContext<S>, name: string): number {
	return context.getArgument(name, "number");
}

const LONG_MIN = -(2 ** 63);
const LONG_MAX = 2 ** 63;

export class LongArgumentType implements ArgumentType<number> {
	constructor(
		private readonly minimum: number,
		private readonly maximum: number,
	) {}

	getMinimum(): number {
		return this.minimum;
	}

	getMaximum(): number {
		return this.maximum;
	}

	parse(reader: StringReader): number {
		const start = reader.getCursor();
		const result = reader.readLong();
		if (result < this.minimum) {
			reader.setCursor(start);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.longTooLow().createWithContext(
				reader,
				result,
				this.minimum,
			);
		}
		if (result > this.maximum) {
			reader.setCursor(start);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.longTooHigh().createWithContext(
				reader,
				result,
				this.maximum,
			);
		}
		return result;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof LongArgumentType)) {
			return false;
		}
		return this.maximum === other.maximum && this.minimum === other.minimum;
	}

	toString(): string {
		if (this.minimum === LONG_MIN && this.maximum === LONG_MAX) {
			return "longArg()";
		} else if (this.maximum === LONG_MAX) {
			return `longArg(${formatInteger(this.minimum)})`;
		}
		return `longArg(${formatInteger(this.minimum)}, ${formatInteger(this.maximum)})`;
	}

	getExamples(): readonly string[] {
		return INTEGER_EXAMPLES;
	}
}

export function longArg(min = LONG_MIN, max = LONG_MAX): LongArgumentType {
	return new LongArgumentType(min, max);
}

export function getLong<S>(context: CommandContext<S>, name: string): number {
	return context.getArgument(name, "number");
}

const DECIMAL_EXAMPLES = ["0", "1.2", ".5", "-1", "-.5", "-1234.56"];
const DOUBLE_MIN = -1.7976931348623157e308;
const DOUBLE_MAX = 1.7976931348623157e308;

export class DoubleArgumentType implements ArgumentType<number> {
	constructor(
		private readonly minimum: number,
		private readonly maximum: number,
	) {}

	getMinimum(): number {
		return this.minimum;
	}

	getMaximum(): number {
		return this.maximum;
	}

	parse(reader: StringReader): number {
		const start = reader.getCursor();
		const result = reader.readDouble();
		if (result < this.minimum) {
			reader.setCursor(start);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.doubleTooLow().createWithContext(
				reader,
				result,
				this.minimum,
			);
		}
		if (result > this.maximum) {
			reader.setCursor(start);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.doubleTooHigh().createWithContext(
				reader,
				result,
				this.maximum,
			);
		}
		return result;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof DoubleArgumentType)) {
			return false;
		}
		return this.maximum === other.maximum && this.minimum === other.minimum;
	}

	toString(): string {
		if (this.minimum === DOUBLE_MIN && this.maximum === DOUBLE_MAX) {
			return "double()";
		} else if (this.maximum === DOUBLE_MAX) {
			return `double(${formatDouble(this.minimum)})`;
		}
		return `double(${formatDouble(this.minimum)}, ${formatDouble(this.maximum)})`;
	}

	getExamples(): readonly string[] {
		return DECIMAL_EXAMPLES;
	}
}

export function doubleArg(min = DOUBLE_MIN, max = DOUBLE_MAX): DoubleArgumentType {
	return new DoubleArgumentType(min, max);
}

export function getDouble<S>(context: CommandContext<S>, name: string): number {
	return context.getArgument(name, "number");
}

const FLOAT_MIN = -3.4028234663852886e38;
const FLOAT_MAX = 3.4028234663852886e38;

export class FloatArgumentType implements ArgumentType<number> {
	private readonly minimum: number;
	private readonly maximum: number;

	// The bounds are floats in Java, so they are rounded to single precision.
	constructor(minimum: number, maximum: number) {
		this.minimum = toFloat(minimum);
		this.maximum = toFloat(maximum);
	}

	getMinimum(): number {
		return this.minimum;
	}

	getMaximum(): number {
		return this.maximum;
	}

	parse(reader: StringReader): number {
		const start = reader.getCursor();
		const result = reader.readFloat();
		if (result < this.minimum) {
			reader.setCursor(start);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.floatTooLow().createWithContext(
				reader,
				result,
				this.minimum,
			);
		}
		if (result > this.maximum) {
			reader.setCursor(start);
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.floatTooHigh().createWithContext(
				reader,
				result,
				this.maximum,
			);
		}
		return result;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof FloatArgumentType)) {
			return false;
		}
		return this.maximum === other.maximum && this.minimum === other.minimum;
	}

	toString(): string {
		if (this.minimum === FLOAT_MIN && this.maximum === FLOAT_MAX) {
			return "float()";
		} else if (this.maximum === FLOAT_MAX) {
			return `float(${formatFloat(this.minimum)})`;
		}
		return `float(${formatFloat(this.minimum)}, ${formatFloat(this.maximum)})`;
	}

	getExamples(): readonly string[] {
		return DECIMAL_EXAMPLES;
	}
}

export function floatArg(min = FLOAT_MIN, max = FLOAT_MAX): FloatArgumentType {
	return new FloatArgumentType(min, max);
}

export function getFloat<S>(context: CommandContext<S>, name: string): number {
	return context.getArgument(name, "number");
}

export class StringType {
	static readonly SINGLE_WORD = new StringType("SINGLE_WORD", ["word", "words_with_underscores"]);
	static readonly QUOTABLE_PHRASE = new StringType("QUOTABLE_PHRASE", ['"quoted phrase"', "word", '""']);
	static readonly GREEDY_PHRASE = new StringType("GREEDY_PHRASE", ["word", "words with spaces", '"and symbols"']);

	private constructor(
		private readonly constantName: string,
		private readonly examples: readonly string[],
	) {}

	name(): string {
		return this.constantName;
	}

	getExamples(): readonly string[] {
		return this.examples;
	}

	toString(): string {
		return this.constantName;
	}
}

export class StringArgumentType implements ArgumentType<string> {
	constructor(private readonly stringType: StringType) {}

	getType(): StringType {
		return this.stringType;
	}

	parse(reader: StringReader): string {
		if (this.stringType === StringType.GREEDY_PHRASE) {
			const text = reader.getRemaining();
			reader.setCursor(reader.getTotalLength());
			return text;
		} else if (this.stringType === StringType.SINGLE_WORD) {
			return reader.readUnquotedString();
		}
		return reader.readString();
	}

	toString(): string {
		return "string()";
	}

	getExamples(): readonly string[] {
		return this.stringType.getExamples();
	}
}

export function word(): StringArgumentType {
	return new StringArgumentType(StringType.SINGLE_WORD);
}

export function stringArg(): StringArgumentType {
	return new StringArgumentType(StringType.QUOTABLE_PHRASE);
}

export function greedyString(): StringArgumentType {
	return new StringArgumentType(StringType.GREEDY_PHRASE);
}

export function getString<S>(context: CommandContext<S>, name: string): string {
	return context.getArgument(name, "string");
}

function escape(input: string): string {
	const result = ['"'];
	for (let index = 1; index <= input.size(); index++) {
		const c = input.sub(index, index);
		if (c === "\\" || c === '"') {
			result.push("\\");
		}
		result.push(c);
	}
	result.push('"');
	return result.join("");
}

export function escapeIfRequired(input: string): string {
	for (let index = 1; index <= input.size(); index++) {
		if (!StringReader.isAllowedInUnquotedString(input.sub(index, index))) {
			return escape(input);
		}
	}
	return input;
}
