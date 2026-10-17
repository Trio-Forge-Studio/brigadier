--!strict

local Types = require("@self/Types")

export type AmbiguityConsumer<S> = Types.AmbiguityConsumer<S>
export type ArgumentBuilder<S> = Types.ArgumentBuilder<S>
export type ArgumentCommandNode<S, T> = Types.ArgumentCommandNode<S, T>
export type ArgumentType<T> = Types.ArgumentType<T>
export type BoolArgumentType = Types.BoolArgumentType
export type BuiltInExceptionProvider = Types.BuiltInExceptionProvider
export type Command<S> = Types.Command<S>
export type CommandContext<S> = Types.CommandContext<S>
export type CommandContextBuilder<S> = Types.CommandContextBuilder<S>
export type CommandDispatcher<S> = Types.CommandDispatcher<S>
export type CommandExceptionType = Types.CommandExceptionType
export type CommandNode<S> = Types.CommandNode<S>
export type CommandSyntaxException = Types.CommandSyntaxException
export type CompletableFuture<T> = Types.CompletableFuture<T>
export type ContextChain<S> = Types.ContextChain<S>
export type DoubleArgumentType = Types.DoubleArgumentType
export type Dynamic2CommandExceptionType = Types.Dynamic2CommandExceptionType
export type Dynamic3CommandExceptionType = Types.Dynamic3CommandExceptionType
export type Dynamic4CommandExceptionType = Types.Dynamic4CommandExceptionType
export type DynamicCommandExceptionType = Types.DynamicCommandExceptionType
export type DynamicNCommandExceptionType = Types.DynamicNCommandExceptionType
export type FloatArgumentType = Types.FloatArgumentType
export type ImmutableStringReader = Types.ImmutableStringReader
export type IntegerArgumentType = Types.IntegerArgumentType
export type IntegerSuggestion = Types.IntegerSuggestion
export type LiteralArgumentBuilder<S> = Types.LiteralArgumentBuilder<S>
export type LiteralCommandNode<S> = Types.LiteralCommandNode<S>
export type LongArgumentType = Types.LongArgumentType
export type Message = Types.Message
export type ParseResults<S> = Types.ParseResults<S>
export type ParsedArgument<S, T> = Types.ParsedArgument<S, T>
export type ParsedCommandNode<S> = Types.ParsedCommandNode<S>
export type Predicate<S> = Types.Predicate<S>
export type RedirectModifier<S> = Types.RedirectModifier<S>
export type RequiredArgumentBuilder<S, T> = Types.RequiredArgumentBuilder<S, T>
export type ResultConsumer<S> = Types.ResultConsumer<S>
export type RootCommandNode<S> = Types.RootCommandNode<S>
export type SimpleCommandExceptionType = Types.SimpleCommandExceptionType
export type SingleRedirectModifier<S> = Types.SingleRedirectModifier<S>
export type StringArgumentType = Types.StringArgumentType
export type StringRange = Types.StringRange
export type StringReader = Types.StringReader
export type StringType = Types.StringType
export type Suggestion = Types.Suggestion
export type SuggestionContext<S> = Types.SuggestionContext<S>
export type SuggestionProvider<S> = Types.SuggestionProvider<S>
export type Suggestions = Types.Suggestions
export type SuggestionsBuilder = Types.SuggestionsBuilder

local RuntimeException = require("@self/util/RuntimeException")

return {
	-- com.mojang.brigadier
	Command = require("@self/Command"),
	CommandDispatcher = require("@self/CommandDispatcher"),
	LiteralMessage = require("@self/LiteralMessage"),
	ParseResults = require("@self/ParseResults"),
	StringReader = require("@self/StringReader"),

	-- com.mojang.brigadier.arguments
	BoolArgumentType = require("@self/arguments/BoolArgumentType"),
	DoubleArgumentType = require("@self/arguments/DoubleArgumentType"),
	FloatArgumentType = require("@self/arguments/FloatArgumentType"),
	IntegerArgumentType = require("@self/arguments/IntegerArgumentType"),
	LongArgumentType = require("@self/arguments/LongArgumentType"),
	StringArgumentType = require("@self/arguments/StringArgumentType"),

	-- com.mojang.brigadier.builder
	ArgumentBuilder = require("@self/builder/ArgumentBuilder"),
	LiteralArgumentBuilder = require("@self/builder/LiteralArgumentBuilder"),
	RequiredArgumentBuilder = require("@self/builder/RequiredArgumentBuilder"),

	-- com.mojang.brigadier.context
	CommandContext = require("@self/context/CommandContext"),
	CommandContextBuilder = require("@self/context/CommandContextBuilder"),
	ContextChain = require("@self/context/ContextChain"),
	ParsedArgument = require("@self/context/ParsedArgument"),
	ParsedCommandNode = require("@self/context/ParsedCommandNode"),
	StringRange = require("@self/context/StringRange"),
	SuggestionContext = require("@self/context/SuggestionContext"),

	-- com.mojang.brigadier.exceptions
	BuiltInExceptions = require("@self/exceptions/BuiltInExceptions"),
	CommandSyntaxException = require("@self/exceptions/CommandSyntaxException"),
	Dynamic2CommandExceptionType = require("@self/exceptions/Dynamic2CommandExceptionType"),
	Dynamic3CommandExceptionType = require("@self/exceptions/Dynamic3CommandExceptionType"),
	Dynamic4CommandExceptionType = require("@self/exceptions/Dynamic4CommandExceptionType"),
	DynamicCommandExceptionType = require("@self/exceptions/DynamicCommandExceptionType"),
	DynamicNCommandExceptionType = require("@self/exceptions/DynamicNCommandExceptionType"),
	SimpleCommandExceptionType = require("@self/exceptions/SimpleCommandExceptionType"),

	-- com.mojang.brigadier.suggestion
	IntegerSuggestion = require("@self/suggestion/IntegerSuggestion"),
	Suggestion = require("@self/suggestion/Suggestion"),
	Suggestions = require("@self/suggestion/Suggestions"),
	SuggestionsBuilder = require("@self/suggestion/SuggestionsBuilder"),

	-- com.mojang.brigadier.tree
	ArgumentCommandNode = require("@self/tree/ArgumentCommandNode"),
	CommandNode = require("@self/tree/CommandNode"),
	LiteralCommandNode = require("@self/tree/LiteralCommandNode"),
	RootCommandNode = require("@self/tree/RootCommandNode"),

	-- java.util.concurrent and java.lang
	CompletableFuture = require("@self/util/CompletableFuture"),
	IllegalArgumentException = RuntimeException.IllegalArgumentException,
	IllegalStateException = RuntimeException.IllegalStateException,
	RuntimeException = RuntimeException.RuntimeException,
	UnsupportedOperationException = RuntimeException.UnsupportedOperationException,
}
