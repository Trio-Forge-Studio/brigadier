import { StringRange } from "./context";
import { compareStrings, formatInteger, objectsEquals, stableSort, substring, toLowerCase } from "./java";
import type { Message } from "./literal-message";

function describeTooltip(tooltip: Message | undefined): string {
	return tooltip === undefined ? "null" : tostring(tooltip);
}

export class Suggestion {
	constructor(
		protected readonly range: StringRange,
		protected readonly text: string,
		protected readonly tooltip?: Message,
	) {}

	getRange(): StringRange {
		return this.range;
	}

	getText(): string {
		return this.text;
	}

	getTooltip(): Message | undefined {
		return this.tooltip;
	}

	apply(input: string): string {
		if (this.range.getStart() === 0 && this.range.getEnd() === input.size()) {
			return this.text;
		}
		let result = "";
		if (this.range.getStart() > 0) {
			result += substring(input, 0, this.range.getStart());
		}
		result += this.text;
		if (this.range.getEnd() < input.size()) {
			result += substring(input, this.range.getEnd());
		}
		return result;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof Suggestion)) {
			return false;
		}
		return (
			objectsEquals(this.range, other.range) &&
			objectsEquals(this.text, other.text) &&
			objectsEquals(this.tooltip, other.tooltip)
		);
	}

	toString(): string {
		return `Suggestion{range=${this.range}, text='${this.text}', tooltip='${describeTooltip(this.tooltip)}'}`;
	}

	compareTo(other: Suggestion): number {
		return compareStrings(this.text, other.getText());
	}

	compareToIgnoreCase(other: Suggestion): number {
		return compareStrings(this.text.lower(), other.getText().lower());
	}

	expand(command: string, range: StringRange): Suggestion {
		if (range.equals(this.range)) {
			return this;
		}
		let result = "";
		if (range.getStart() < this.range.getStart()) {
			result += substring(command, range.getStart(), this.range.getStart());
		}
		result += this.text;
		if (range.getEnd() > this.range.getEnd()) {
			result += substring(command, this.range.getEnd(), range.getEnd());
		}
		return new Suggestion(range, result, this.tooltip);
	}
}

export class IntegerSuggestion extends Suggestion {
	constructor(
		range: StringRange,
		private readonly value: number,
		tooltip?: Message,
	) {
		super(range, formatInteger(value), tooltip);
	}

	getValue(): number {
		return this.value;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof IntegerSuggestion)) {
			return false;
		}
		return this.value === other.value && super.equals(other);
	}

	toString(): string {
		return `IntegerSuggestion{value=${formatInteger(this.value)}, range=${this.range}, text='${this.text}', tooltip='${describeTooltip(this.tooltip)}'}`;
	}

	compareTo(other: Suggestion): number {
		if (other instanceof IntegerSuggestion) {
			return this.value < other.value ? -1 : this.value === other.value ? 0 : 1;
		}
		return super.compareTo(other);
	}

	compareToIgnoreCase(other: Suggestion): number {
		return this.compareTo(other);
	}
}

// A HashSet<Suggestion> keeps the first of each group of equal suggestions. Equal suggestions share their range,
// text and class, so those key the buckets that `equals` searches.
type Buckets = Map<object, Map<string, Suggestion[]>>;

function addToSet(set: Suggestion[], buckets: Buckets, suggestion: Suggestion) {
	const clazz = getmetatable(suggestion) as object;
	let byKey = buckets.get(clazz);
	if (byKey === undefined) {
		byKey = new Map();
		buckets.set(clazz, byKey);
	}
	const range = suggestion.getRange();
	const key = `${range.getStart()}:${range.getEnd()}:${suggestion.getText()}`;
	let bucket = byKey.get(key);
	if (bucket === undefined) {
		bucket = [];
		byKey.set(key, bucket);
	}
	for (const existing of bucket) {
		if (existing.equals(suggestion)) {
			return;
		}
	}
	bucket.push(suggestion);
	set.push(suggestion);
}

export class Suggestions {
	private static readonly EMPTY = new Suggestions(StringRange.at(0), []);

	constructor(
		private readonly range: StringRange,
		private readonly suggestions: readonly Suggestion[],
	) {}

	static empty(): Promise<Suggestions> {
		return Promise.resolve(Suggestions.EMPTY);
	}

	static merge(command: string, input: readonly Suggestions[]): Suggestions {
		if (input.size() === 0) {
			return Suggestions.EMPTY;
		} else if (input.size() === 1) {
			return input[0];
		}

		const texts: Suggestion[] = [];
		const buckets: Buckets = new Map();
		for (const suggestions of input) {
			for (const suggestion of suggestions.getList()) {
				addToSet(texts, buckets, suggestion);
			}
		}
		return Suggestions.create(command, texts);
	}

	static create(command: string, suggestions: readonly Suggestion[]): Suggestions {
		if (suggestions.size() === 0) {
			return Suggestions.EMPTY;
		}
		let start = math.huge;
		let finish = -math.huge;
		for (const suggestion of suggestions) {
			start = math.min(suggestion.getRange().getStart(), start);
			finish = math.max(suggestion.getRange().getEnd(), finish);
		}
		const range = new StringRange(start, finish);
		const texts: Suggestion[] = [];
		const buckets: Buckets = new Map();
		for (const suggestion of suggestions) {
			addToSet(texts, buckets, suggestion.expand(command, range));
		}
		stableSort(texts, (a, b) => a.compareToIgnoreCase(b));
		return new Suggestions(range, texts);
	}

	getRange(): StringRange {
		return this.range;
	}

	getList(): readonly Suggestion[] {
		return this.suggestions;
	}

	isEmpty(): boolean {
		return this.suggestions.size() === 0;
	}

	equals(other: unknown): boolean {
		if (rawequal(this, other)) {
			return true;
		}
		if (!(other instanceof Suggestions)) {
			return false;
		}
		return objectsEquals(this.range, other.range) && objectsEquals(this.suggestions, other.suggestions);
	}

	toString(): string {
		const parts = this.suggestions.map((suggestion) => tostring(suggestion));
		return `Suggestions{range=${this.range}, suggestions=[${parts.join(", ")}]}`;
	}
}

export class SuggestionsBuilder {
	private readonly inputLowerCase: string;
	private readonly start: number;
	private readonly remaining: string;
	private readonly remainingLowerCase: string;
	private readonly result: Suggestion[] = [];

	constructor(input: string, start: number);
	constructor(input: string, inputLowerCase: string, start: number);
	constructor(
		private readonly input: string,
		inputLowerCaseOrStart: string | number,
		start?: number,
	) {
		if (typeIs(inputLowerCaseOrStart, "number")) {
			this.inputLowerCase = toLowerCase(input);
			this.start = inputLowerCaseOrStart;
		} else {
			this.inputLowerCase = inputLowerCaseOrStart;
			this.start = start!;
		}
		this.remaining = substring(input, this.start);
		this.remainingLowerCase = substring(this.inputLowerCase, this.start);
	}

	getInput(): string {
		return this.input;
	}

	getStart(): number {
		return this.start;
	}

	getRemaining(): string {
		return this.remaining;
	}

	getRemainingLowerCase(): string {
		return this.remainingLowerCase;
	}

	build(): Suggestions {
		return Suggestions.create(this.input, this.result);
	}

	buildFuture(): Promise<Suggestions> {
		return Promise.resolve(this.build());
	}

	// suggest(String), suggest(String, Message), suggest(int) and suggest(int, Message). A number makes an
	// IntegerSuggestion.
	suggest(textOrValue: string | number, tooltip?: Message): this {
		const range = StringRange.between(this.start, this.input.size());
		if (typeIs(textOrValue, "number")) {
			this.result.push(new IntegerSuggestion(range, textOrValue, tooltip));
			return this;
		}
		if (textOrValue === this.remaining) {
			return this;
		}
		this.result.push(new Suggestion(range, textOrValue, tooltip));
		return this;
	}

	add(other: SuggestionsBuilder): this {
		for (const suggestion of other.result) {
			this.result.push(suggestion);
		}
		return this;
	}

	createOffset(start: number): SuggestionsBuilder {
		return new SuggestionsBuilder(this.input, this.inputLowerCase, start);
	}

	restart(): SuggestionsBuilder {
		return this.createOffset(this.start);
	}
}
