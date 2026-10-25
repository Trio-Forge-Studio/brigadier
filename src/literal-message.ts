export interface Message {
	getString(): string;
}

export class LiteralMessage implements Message {
	constructor(private readonly text: string) {}

	getString(): string {
		return this.text;
	}

	toString(): string {
		return this.text;
	}
}
