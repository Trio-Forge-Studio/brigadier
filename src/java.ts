// The parts of the Java standard library Brigadier relies on, with Java's behaviour.

export class RuntimeException {
	protected readonly simpleName: string = "RuntimeException";

	constructor(private readonly message?: string) {}

	getMessage(): string | undefined {
		return this.message;
	}

	toString(): string {
		return this.message === undefined
			? `java.lang.${this.simpleName}`
			: `java.lang.${this.simpleName}: ${this.message}`;
	}
}

export class IllegalArgumentException extends RuntimeException {
	protected readonly simpleName: string = "IllegalArgumentException";

	// roblox-ts gives a subclass no __tostring unless it declares toString itself.
	toString(): string {
		return super.toString();
	}
}

export class IllegalStateException extends RuntimeException {
	protected readonly simpleName: string = "IllegalStateException";

	toString(): string {
		return super.toString();
	}
}

export class UnsupportedOperationException extends RuntimeException {
	protected readonly simpleName: string = "UnsupportedOperationException";

	toString(): string {
		return super.toString();
	}
}

export class IndexOutOfBoundsException extends RuntimeException {
	protected readonly simpleName: string = "IndexOutOfBoundsException";

	toString(): string {
		return super.toString();
	}
}

export class StringIndexOutOfBoundsException extends IndexOutOfBoundsException {
	protected readonly simpleName: string = "StringIndexOutOfBoundsException";

	toString(): string {
		return super.toString();
	}
}

// Raises an error value again unchanged. `throw` would prefix a string with the rethrowing line.
export function rethrow(err: unknown): never {
	error(err, 0);
}

// String concatenation of an Object: null prints as "null".
export function str(value: unknown): string {
	return value === undefined ? "null" : tostring(value);
}

// String.substring and String.charAt use 0-based byte offsets and throw where string.sub clamps.
export function substring(text: string, beginIndex: number, endIndex = text.size()): string {
	if (beginIndex < 0 || endIndex > text.size() || beginIndex > endIndex) {
		throw new StringIndexOutOfBoundsException(`begin ${beginIndex}, end ${endIndex}, length ${text.size()}`);
	}
	return text.sub(beginIndex + 1, endIndex);
}

export function charAt(text: string, index: number): string {
	if (index < 0 || index >= text.size()) {
		throw new StringIndexOutOfBoundsException(`index ${index}, length ${text.size()}`);
	}
	return text.sub(index + 1, index + 1);
}

export function startsWith(text: string, prefix: string): boolean {
	return text.sub(1, prefix.size()) === prefix;
}

// toLowerCase(Locale.ROOT) on ASCII, which keeps every offset where it was.
export function toLowerCase(text: string): string {
	return text.lower();
}

// String.compareTo: the difference of the first bytes that differ, or of the lengths.
export function compareStrings(a: string, b: string): number {
	const length = math.min(a.size(), b.size());
	for (let index = 1; index <= length; index++) {
		const [x] = string.byte(a, index);
		const [y] = string.byte(b, index);
		if (x !== y) {
			return x - y;
		}
	}
	return a.size() - b.size();
}

interface Equatable {
	equals(other: unknown): boolean;
}

function definesEquals(value: unknown): value is Equatable {
	return (
		typeIs(value, "table") &&
		getmetatable(value) !== undefined &&
		typeIs((value as { equals?: unknown }).equals, "function")
	);
}

// Objects.equals, with Java's collection equality for arrays and maps.
export function objectsEquals(a: unknown, b: unknown): boolean {
	if (rawequal(a, b)) {
		return true;
	}
	if (a === undefined || b === undefined) {
		return false;
	}
	if (definesEquals(a)) {
		return a.equals(b);
	}
	if (typeIs(a, "table") && typeIs(b, "table") && getmetatable(a) === undefined && getmetatable(b) === undefined) {
		const left = a as Map<unknown, unknown>;
		const right = b as Map<unknown, unknown>;
		for (const [key, value] of pairs(left)) {
			if (!objectsEquals(value, right.get(key))) {
				return false;
			}
		}
		for (const [key] of pairs(right)) {
			if (left.get(key) === undefined) {
				return false;
			}
		}
		return true;
	}
	return a === b;
}

// List.sort is stable and Brigadier relies on equal elements keeping their order. table.sort isn't.
export function stableSort<T extends defined>(list: T[], compare: (a: T, b: T) => number) {
	const buffer = [...list];
	const sortRange = (low: number, high: number) => {
		if (low >= high) {
			return;
		}
		const middle = math.floor((low + high) / 2);
		sortRange(low, middle);
		sortRange(middle + 1, high);
		for (let index = low; index <= high; index++) {
			buffer[index] = list[index];
		}
		let left = low;
		let right = middle + 1;
		for (let index = low; index <= high; index++) {
			if (left <= middle && (right > high || compare(buffer[right], buffer[left]) >= 0)) {
				list[index] = buffer[left];
				left++;
			} else {
				list[index] = buffer[right];
				right++;
			}
		}
	};
	sortRange(0, list.size() - 1);
}

const LONG_MAX_DOUBLE = 2 ** 63;

// Integer.toString and Long.toString. Long.MAX_VALUE is stored as 2^63, its nearest double.
export function formatInteger(value: number): string {
	if (value >= LONG_MAX_DOUBLE) {
		return "9223372036854775807";
	}
	return string.format("%d", value);
}

export function toFloat(value: number): number {
	const [single] = string.unpack("<f", string.pack("<f", value));
	return single as number;
}

// The shortest digits and exponent that `readsBack` accepts for a positive finite value.
function shortest(value: number, maxDigits: number, readsBack: (candidate: number) => boolean): [string, number] {
	let text = "";
	for (let precision = 1; precision <= maxDigits; precision++) {
		text = string.format(`%.${precision - 1}e`, value);
		if (readsBack(tonumber(text)!)) {
			break;
		}
	}
	const [mantissa, exponent] = string.match(text, "^([%d%.]+)e([%+%-]%d+)$");
	let [digits] = string.gsub(mantissa as string, "%.", "");
	[digits] = string.gsub(digits, "0+$", "");
	return [digits === "" ? "0" : digits, tonumber(exponent as string)!];
}

function formatDecimal(value: number, maxDigits: number, readsBack: (candidate: number) => boolean): string {
	if (value !== value) {
		return "NaN";
	}
	if (value === math.huge) {
		return "Infinity";
	}
	if (value === -math.huge) {
		return "-Infinity";
	}
	if (value === 0) {
		return 1 / value < 0 ? "-0.0" : "0.0";
	}
	const sign = value < 0 ? "-" : "";
	const magnitude = math.abs(value);
	const [digits, exponent] = shortest(magnitude, maxDigits, readsBack);

	if (magnitude >= 1e-3 && magnitude < 1e7) {
		if (exponent >= 0) {
			let whole = digits.sub(1, exponent + 1);
			whole += string.rep("0", exponent + 1 - whole.size());
			const fraction = digits.sub(exponent + 2);
			return `${sign}${whole}.${fraction === "" ? "0" : fraction}`;
		}
		return `${sign}0.${string.rep("0", -exponent - 1)}${digits}`;
	}
	const fraction = digits.sub(2);
	return `${sign}${digits.sub(1, 1)}.${fraction === "" ? "0" : fraction}E${exponent}`;
}

// Double.toString and Float.toString print the fewest digits that read back as the same value, as JDK 19 and
// later do. JDK 8 sometimes printed one more.
export function formatDouble(value: number): string {
	return formatDecimal(value, 17, (candidate) => candidate === math.abs(value));
}

export function formatFloat(value: number): string {
	const single = toFloat(value);
	return formatDecimal(single, 9, (candidate) => toFloat(candidate) === math.abs(single));
}
