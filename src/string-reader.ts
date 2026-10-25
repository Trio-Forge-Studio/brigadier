import { CommandSyntaxException } from "./exceptions";
import { charAt, substring, toFloat } from "./java";

export interface ImmutableStringReader {
	getString(): string;
	getRemainingLength(): number;
	getTotalLength(): number;
	getCursor(): number;
	getRead(): string;
	getRemaining(): string;
	canRead(length?: number): boolean;
	peek(offset?: number): string;
}

const SYNTAX_ESCAPE = "\\";
const SYNTAX_DOUBLE_QUOTE = '"';
const SYNTAX_SINGLE_QUOTE = "'";

const INT_MIN = -2147483648;
const INT_MAX = 2147483647;

// Character.isWhitespace for the one-byte characters it accepts.
function isWhitespace(c: string): boolean {
	const [code] = string.byte(c);
	return code !== undefined && ((code >= 9 && code <= 13) || (code >= 28 && code <= 32));
}

// Integer.parseInt and Long.parseLong: an optional sign, then decimal digits that fit the type.
function parseWholeNumber(text: string, minDigits: string, maxDigits: string): number | undefined {
	const [sign, digits] = string.match(text, "^([+-]?)(%d+)$");
	if (!typeIs(digits, "string")) {
		return undefined;
	}
	const significant = string.match(digits, "^0*(%d-)$")[0] as string;
	const limit = sign === "-" ? minDigits : maxDigits;
	if (significant.size() > limit.size() || (significant.size() === limit.size() && significant > limit)) {
		return undefined;
	}
	// Adding zero turns "-0" into 0, which is what an int holds.
	return tonumber(text)! + 0;
}

function parseInt(text: string): number | undefined {
	const value = parseWholeNumber(text, "2147483648", "2147483647");
	if (value === undefined || value < INT_MIN || value > INT_MAX) {
		return undefined;
	}
	return value;
}

function parseLong(text: string): number | undefined {
	return parseWholeNumber(text, "9223372036854775808", "9223372036854775807");
}

// Double.parseDouble for what isAllowedNumber lets through: an optional minus, then digits with at most one point.
function parseDouble(text: string): number | undefined {
	const [body] = string.match(text, "^%-?([%d%.]+)$");
	if (!typeIs(body, "string") || string.find(body, "%d")[0] === undefined) {
		return undefined;
	}
	const [, points] = string.gsub(body, "%.", "");
	if (points > 1) {
		return undefined;
	}
	return tonumber(text);
}

// Float.parseFloat rounds the decimal straight to a float. Rounding through a double first differs only for
// decimals within half a double ulp of the midpoint between two floats.
function parseFloat(text: string): number | undefined {
	const value = parseDouble(text);
	return value === undefined ? undefined : toFloat(value);
}

export class StringReader implements ImmutableStringReader {
	private readonly text: string;
	private cursor: number;

	constructor(other: string | StringReader) {
		if (typeIs(other, "string")) {
			this.text = other;
			this.cursor = 0;
		} else {
			this.text = other.text;
			this.cursor = other.cursor;
		}
	}

	static isAllowedNumber(c: string): boolean {
		return (c >= "0" && c <= "9") || c === "." || c === "-";
	}

	static isQuotedStringStart(c: string): boolean {
		return c === SYNTAX_DOUBLE_QUOTE || c === SYNTAX_SINGLE_QUOTE;
	}

	static isAllowedInUnquotedString(c: string): boolean {
		return (
			(c >= "0" && c <= "9") ||
			(c >= "A" && c <= "Z") ||
			(c >= "a" && c <= "z") ||
			c === "_" ||
			c === "-" ||
			c === "." ||
			c === "+"
		);
	}

	getString(): string {
		return this.text;
	}

	setCursor(cursor: number) {
		this.cursor = cursor;
	}

	getRemainingLength(): number {
		return this.text.size() - this.cursor;
	}

	getTotalLength(): number {
		return this.text.size();
	}

	getCursor(): number {
		return this.cursor;
	}

	getRead(): string {
		return substring(this.text, 0, this.cursor);
	}

	getRemaining(): string {
		return substring(this.text, this.cursor);
	}

	canRead(length = 1): boolean {
		return this.cursor + length <= this.text.size();
	}

	peek(offset = 0): string {
		return charAt(this.text, this.cursor + offset);
	}

	read(): string {
		const c = charAt(this.text, this.cursor);
		this.cursor++;
		return c;
	}

	skip() {
		this.cursor++;
	}

	skipWhitespace() {
		while (this.canRead() && isWhitespace(this.peek())) {
			this.skip();
		}
	}

	private readNumber(): string {
		const start = this.cursor;
		while (this.canRead() && StringReader.isAllowedNumber(this.peek())) {
			this.skip();
		}
		return substring(this.text, start, this.cursor);
	}

	readInt(): number {
		const start = this.cursor;
		const text = this.readNumber();
		if (text === "") {
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerExpectedInt().createWithContext(this);
		}
		const value = parseInt(text);
		if (value === undefined) {
			this.cursor = start;
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerInvalidInt().createWithContext(this, text);
		}
		return value;
	}

	readLong(): number {
		const start = this.cursor;
		const text = this.readNumber();
		if (text === "") {
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerExpectedLong().createWithContext(this);
		}
		const value = parseLong(text);
		if (value === undefined) {
			this.cursor = start;
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerInvalidLong().createWithContext(this, text);
		}
		return value;
	}

	readDouble(): number {
		const start = this.cursor;
		const text = this.readNumber();
		if (text === "") {
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerExpectedDouble().createWithContext(this);
		}
		const value = parseDouble(text);
		if (value === undefined) {
			this.cursor = start;
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerInvalidDouble().createWithContext(this, text);
		}
		return value;
	}

	readFloat(): number {
		const start = this.cursor;
		const text = this.readNumber();
		if (text === "") {
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerExpectedFloat().createWithContext(this);
		}
		const value = parseFloat(text);
		if (value === undefined) {
			this.cursor = start;
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerInvalidFloat().createWithContext(this, text);
		}
		return value;
	}

	readUnquotedString(): string {
		const start = this.cursor;
		while (this.canRead() && StringReader.isAllowedInUnquotedString(this.peek())) {
			this.skip();
		}
		return substring(this.text, start, this.cursor);
	}

	readQuotedString(): string {
		if (!this.canRead()) {
			return "";
		}
		const nextChar = this.peek();
		if (!StringReader.isQuotedStringStart(nextChar)) {
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerExpectedStartOfQuote().createWithContext(this);
		}
		this.skip();
		return this.readStringUntil(nextChar);
	}

	readStringUntil(terminator: string): string {
		const result: string[] = [];
		let escaped = false;
		while (this.canRead()) {
			const c = this.read();
			if (escaped) {
				if (c === terminator || c === SYNTAX_ESCAPE) {
					result.push(c);
					escaped = false;
				} else {
					this.setCursor(this.getCursor() - 1);
					throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerInvalidEscape().createWithContext(this, c);
				}
			} else if (c === SYNTAX_ESCAPE) {
				escaped = true;
			} else if (c === terminator) {
				return result.join("");
			} else {
				result.push(c);
			}
		}

		throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerExpectedEndOfQuote().createWithContext(this);
	}

	readString(): string {
		if (!this.canRead()) {
			return "";
		}
		const nextChar = this.peek();
		if (StringReader.isQuotedStringStart(nextChar)) {
			this.skip();
			return this.readStringUntil(nextChar);
		}
		return this.readUnquotedString();
	}

	readBoolean(): boolean {
		const start = this.cursor;
		const value = this.readString();
		if (value === "") {
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerExpectedBool().createWithContext(this);
		}

		if (value === "true") {
			return true;
		} else if (value === "false") {
			return false;
		}
		this.cursor = start;
		throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerInvalidBool().createWithContext(this, value);
	}

	expect(c: string) {
		if (!this.canRead() || this.peek() !== c) {
			throw CommandSyntaxException.BUILT_IN_EXCEPTIONS.readerExpectedSymbol().createWithContext(this, c);
		}
		this.skip();
	}
}
