import type { CommandContext } from "./context";
import type { Suggestions, SuggestionsBuilder } from "./suggestion";
import type { CommandNode } from "./tree";

// Brigadier's functional interfaces are plain functions. Each one may throw a CommandSyntaxException.

export type Command<S> = (context: CommandContext<S>) => number;

export const Command = {
	SINGLE_SUCCESS: 1,
} as const;

export type Predicate<S> = (source: S) => boolean;

export type RedirectModifier<S> = (context: CommandContext<S>) => readonly S[];

export type SingleRedirectModifier<S> = (context: CommandContext<S>) => S;

export type ResultConsumer<S> = (context: CommandContext<S>, success: boolean, result: number) => void;

export type AmbiguityConsumer<S> = (
	parent: CommandNode<S>,
	child: CommandNode<S>,
	sibling: CommandNode<S>,
	inputs: readonly string[],
) => void;

export type SuggestionProvider<S> = (context: CommandContext<S>, builder: SuggestionsBuilder) => Promise<Suggestions>;
