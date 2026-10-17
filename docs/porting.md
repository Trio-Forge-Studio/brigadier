# Porting rules

This package is a line-by-line port of [Mojang/brigadier](https://github.com/Mojang/brigadier) 1.3 at commit `9ba4f13`. When the Java and the Luau disagree, the Java is right unless this page says otherwise. Every deviation is listed here.

## Layout

Each Java class keeps its package and name: `com.mojang.brigadier.tree.LiteralCommandNode` is `src/tree/LiteralCommandNode.luau`, and its test is `test/tree/LiteralCommandNodeTest.luau`. `src/init.luau` re-exports every public module.

Luau can't type-check a require cycle, and Brigadier has two:

- Nodes create builders (`createBuilder`) and builders create nodes (`build`). Both live in `src/internal/Tree.luau`. The public files under `tree/` and `builder/` return their class from it.
- `CommandSyntaxException.BUILT_IN_EXCEPTIONS` builds exception types that create `CommandSyntaxException`s. The exception, its types and `BuiltInExceptions` live in `src/internal/Exceptions.luau`, and the public files under `exceptions/` return their class from it.

The shapes of all classes are declared once in `src/Types.luau`, since the classes refer to each other.

## Names

- Classes keep their Java names. Methods and fields keep their Java names, in camelCase: `reader:getRemainingLength()`, `dispatcher:getCompletionSuggestions(parse, cursor)`.
- Constructors are `Class.new(...)`. Static methods and constants are fields of the class: `StringRange.at(0)`, `Command.SINGLE_SUCCESS`, `CommandDispatcher.ARGUMENT_SEPARATOR`.
- `then` is a Luau keyword, so `ArgumentBuilder.then` is `ArgumentBuilder:with`.
- `Class.isInstance(value)` replaces `value instanceof Class` and works through inheritance.
- Enums are tables of strings: `ContextChain.Stage.EXECUTE`, `StringArgumentType.StringType.GREEDY_PHRASE`.

## Overloads

Overloads become one function that dispatches on its arguments:

| Java | Luau |
| --- | --- |
| `new StringReader(String)`, `new StringReader(StringReader)` | `StringReader.new(string \| StringReader)` |
| `canRead()`, `canRead(int)`; `peek()`, `peek(int)` | `canRead(length?)`; `peek(offset?)` |
| `execute(String, S)`, `execute(StringReader, S)`, `execute(ParseResults)` | `execute(input, source?)` |
| `parse(String, S)`, `parse(StringReader, S)` | `parse(command, source)` |
| `getCompletionSuggestions(parse)`, `(parse, cursor)` | `getCompletionSuggestions(parse, cursor?)` |
| `then(ArgumentBuilder)`, `then(CommandNode)` | `with(builderOrNode)` |
| `redirect(target)`, `redirect(target, SingleRedirectModifier)` | `redirect(target, modifier?)` |
| `StringRange.get(ImmutableStringReader)`, `get(String)` | `get(readerOrString)` |
| `new SuggestionsBuilder(input, inputLowerCase, start)`, `(input, start)` | `SuggestionsBuilder.new(input, inputLowerCaseOrStart, start?)` |
| `suggest(String)`, `suggest(String, Message)`, `suggest(int)`, `suggest(int, Message)` | `suggest(textOrValue, tooltip?)`: a number makes an `IntegerSuggestion` |
| `new Suggestion(range, text)`, `(range, text, tooltip)` | `Suggestion.new(range, text, tooltip?)` |
| `new CommandSyntaxException(type, message)`, `(type, message, input, cursor)` | `CommandSyntaxException.new(type, message, input?, cursor?)` |
| `new ParseResults(context)`, `(context, reader, exceptions)` | `ParseResults.new(context, reader?, exceptions?)` |
| `ArgumentType.parse(reader)`, `parse(reader, source)` | `parse(reader, source?)` |
| `integer()`, `integer(min)`, `integer(min, max)`, and the same for the other number types | `integer(min?, max?)` |

Private overloads get their own names, for example `getAllUsage`'s recursive form is `getAllUsageRecursive`.

## Values

- **Cursors and ranges are 0-based byte offsets**, as in Java, so ranges and cursors in tests match the Java tests exactly. Convert to `string.sub` with `+ 1` at the call.
- **`char` is a one-byte string**: `reader:peek()` returns `"a"`. Strings are bytes, so non-ASCII text counts its UTF-8 bytes.
- **`Character.isWhitespace`** is the ASCII set it covers: tab, line feed, vertical tab, form feed, carriage return, the four separators `\x1C` to `\x1F`, and space. Unicode spaces are not whitespace.
- **`toLowerCase(Locale.ROOT)`** is `string.lower`, which only folds ASCII, so the lowercase input keeps the same offsets.
- **Numbers**: `int` and `long` values are Luau numbers. `readInt` rejects anything outside the 32-bit range, as `Integer.parseInt` does. `readLong` checks the 64-bit range exactly on the digits, but values beyond 2^53 lose precision once converted. `float` values are rounded to single precision with `string.pack("f", ...)`.
- **`toString`** is `__tostring`, and the number formatting follows Java: `Double.toString` and `Float.toString` give `100.0` and `-2.147483648E9`.
- **`null`** is `nil`. `Optional<T>` is `T?`.

## Collections

- A `List` or `Collection` is an array. Methods that return a node's children return the node's own array, in insertion order, like the live `LinkedHashMap` view in Java. Don't modify it.
- A `Map` is a table keyed by the same value: `getExceptions()` is `{ [CommandNode]: CommandSyntaxException }` and `getSmartUsage()` is `{ [CommandNode]: string }`. These maps have no order; Java's `LinkedHashMap` followed the order of the node's children, so iterate `node:getChildren()` and look each child up to get that order.
- Java's `HashSet<Suggestion>` keeps one of each equal suggestion. The port does the same with `equals`, keeps the first, and sorts with a stable sort, so ties keep their insertion order where Java's would be arbitrary.

## Functional interfaces

`Command`, `Predicate`, `RedirectModifier`, `SingleRedirectModifier`, `ResultConsumer`, `AmbiguityConsumer` and `SuggestionProvider` are plain functions. `Command.SINGLE_SUCCESS` is `1`.

## Exceptions

- `throw ex` is `error(ex)`. `try`/`catch (CommandSyntaxException ex)` is `pcall` followed by `CommandSyntaxException.isInstance(err)`. Anything else is raised again unchanged.
- `IllegalArgumentException`, `IllegalStateException` and `UnsupportedOperationException` are classes in `src/util/RuntimeException.luau`, so callers and tests can tell them apart.
- The dispatcher wraps a non-syntax error raised while parsing an argument into `dispatcherParseException`, as Java wraps a `RuntimeException`. The message is the error's `getMessage()`, or `tostring` of it.
- `CommandSyntaxException.ENABLE_COMMAND_STACK_TRACES` decides whether a new exception keeps `debug.traceback()`, like Java's writable stack trace.

## CompletableFuture

Suggestions are asynchronous in Brigadier, so `src/util/CompletableFuture.luau` ports the part of `java.util.concurrent.CompletableFuture` it uses: `completedFuture`, `new`, `complete`, `isDone`, `join`, `getNow`, `thenApply`, `thenRun` and `allOf`. `join` on a future that isn't done yields the running coroutine until it is. Waiting threads resume with `task.spawn` on Roblox and `coroutine.resume` elsewhere.

## Equality

Classes that override `equals` in Java have an `equals` method. `src/util/Objects.luau` ports `Objects.equals`: same value, or `a:equals(b)` when `a` has one. Lists compare element by element and maps key by key, as Java's collections do. `hashCode` isn't ported; nothing outside Java's hash collections needs it.

## Tests

The tests are ported before the code and stay as close to the Java as Lua allows. `test/lib` provides the parts of JUnit 4, Hamcrest, Mockito and Guava's `EqualsTester` the tests use, with the same names: `assertThat(actual, is(expected))`, `verify(mock, times(2))`, `EqualsTester.new():addEqualityGroup(a, b):testEquals()`. `not` is a Luau keyword, so the matcher is `not_`. Run them with `lune run test`.

## Where the port behaves differently

These are the only places where the port's behaviour or its tests differ from Brigadier's:

- **`Float.toString`** prints the fewest digits that identify the float, as the JDK specifies and does since JDK 19. Brigadier's tests were written against JDK 8, which sometimes prints one more digit: `FloatArgumentTypeTest.testToString` expects `-2.14748365E9` there, and the port's test expects `-2.1474836E9`.
- **Mixed suggestion order.** When numbers and words are suggested together, numbers compare by value with each other but by text with words, which isn't a consistent order, so the result depends on how the sort walks the list. Java's order comes from `HashSet`'s hash order and TimSort; the port keeps insertion order and uses a stable merge sort. `SuggestionsBuilderTest.sort_mixed` expects the port's order. Lists of only words or only numbers sort the same as in Java.
- **`Float.parseFloat`** rounds through a double, which differs from Java's direct rounding only for decimals within half a double ulp of the midpoint between two floats.
- **`long` values** beyond 2^53 lose precision once read, and `Long.MAX_VALUE` is stored as 2^63.
- **`hashCode`** isn't ported, and neither is the unused private `hasCommand` predicate of `CommandDispatcher`.
- **`LiteralArgumentBuilderTest`** keeps its `command` field nil: the Java class declares it `@Mock` but doesn't run with `MockitoJUnitRunner`, so it stays null there too.

## Types

`src/Types.luau` declares every class with `self: any` on its methods, and spells out each subclass instead of intersecting it with its parent. Otherwise the new type solver gives up ("code is too complex") on the deeply recursive generic types. Inside the implementation, the source type `S` is `any` for the same reason; the public types keep it generic. Each constructor casts its new instance to the public type once, since a metatable instance can't be compared with a table type.

## Module surface

Each module returns its class. Instance methods are declared in `src/Types.luau`; constructors, statics and constants are these:

| Module | Members |
| --- | --- |
| `StringReader` | `new(stringOrReader)`, `isAllowedNumber(c)`, `isQuotedStringStart(c)`, `isAllowedInUnquotedString(c)` |
| `LiteralMessage` | `new(text)` |
| `Command` | `SINGLE_SUCCESS` |
| `CommandDispatcher` | `new(root?)`, `ARGUMENT_SEPARATOR`, `ARGUMENT_SEPARATOR_CHAR` |
| `ParseResults` | `new(context, reader?, exceptions?)` |
| `arguments/BoolArgumentType` | `bool()`, `getBool(context, name)` |
| `arguments/IntegerArgumentType` | `integer(min?, max?)`, `getInteger(context, name)` |
| `arguments/LongArgumentType` | `longArg(min?, max?)`, `getLong(context, name)` |
| `arguments/DoubleArgumentType` | `doubleArg(min?, max?)`, `getDouble(context, name)` |
| `arguments/FloatArgumentType` | `floatArg(min?, max?)`, `getFloat(context, name)` |
| `arguments/StringArgumentType` | `word()`, `string()`, `greedyString()`, `getString(context, name)`, `escapeIfRequired(input)`, `StringType.SINGLE_WORD`, `StringType.QUOTABLE_PHRASE`, `StringType.GREEDY_PHRASE` |
| `builder/ArgumentBuilder` | the abstract base |
| `builder/LiteralArgumentBuilder` | `literal(name)` |
| `builder/RequiredArgumentBuilder` | `argument(name, type)` |
| `context/CommandContext` | `new(source, input, arguments, command, rootNode, nodes, range, child, modifier, forks)` |
| `context/CommandContextBuilder` | `new(dispatcher, source, rootNode, start)` |
| `context/ContextChain` | `new(modifiers, executable)`, `tryFlatten(rootContext)`, `runModifier(modifier, source, resultConsumer, forkedMode)`, `runExecutable(executable, source, resultConsumer, forkedMode)`, `Stage.MODIFY`, `Stage.EXECUTE` |
| `context/ParsedArgument` | `new(start, end, result)` |
| `context/ParsedCommandNode` | `new(node, range)` |
| `context/StringRange` | `new(start, end)`, `at(pos)`, `between(start, end)`, `encompassing(a, b)` |
| `context/SuggestionContext` | `new(context, parent, startPos)` |
| `exceptions/CommandSyntaxException` | `new(type, message, input?, cursor?)`, `CONTEXT_AMOUNT`, `ENABLE_COMMAND_STACK_TRACES`, `BUILT_IN_EXCEPTIONS` |
| `exceptions/SimpleCommandExceptionType` | `new(message)` |
| `exceptions/DynamicCommandExceptionType` | `new(function(arg): Message)` |
| `exceptions/Dynamic2CommandExceptionType` to `Dynamic4CommandExceptionType` | `new(function(a, b, ...): Message)` |
| `exceptions/DynamicNCommandExceptionType` | `new(function(args: { any }): Message)` |
| `exceptions/BuiltInExceptions` | `new()` |
| `suggestion/Suggestion` | `new(range, text, tooltip?)` |
| `suggestion/IntegerSuggestion` | `new(range, value, tooltip?)` |
| `suggestion/Suggestions` | `new(range, suggestions)`, `empty()`, `merge(command, input)`, `create(command, suggestions)` |
| `suggestion/SuggestionsBuilder` | `new(input, inputLowerCaseOrStart, start?)` |
| `tree/CommandNode` | the abstract base |
| `tree/RootCommandNode` | `new()` |
| `tree/LiteralCommandNode` | `new(literal, command, requirement, redirect, modifier, forks)` |
| `tree/ArgumentCommandNode` | `new(name, type, command, requirement, redirect, modifier, forks, customSuggestions)` |
| `util/CompletableFuture` | `new()`, `completedFuture(value)`, `allOf(futures)` |
| `util/RuntimeException` | `RuntimeException`, `IllegalArgumentException`, `IllegalStateException`, `UnsupportedOperationException`, each with `new(message?)` and `getMessage()` |

Every class also has `isInstance(value)`.
