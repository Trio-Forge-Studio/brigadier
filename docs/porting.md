# Porting rules

This package ports [Mojang/brigadier](https://github.com/Mojang/brigadier) 1.3 at commit `9ba4f13` to roblox-ts, class for class. When the Java and the port disagree, the Java is right unless this page says otherwise. Every deviation is listed here.

## Names and modules

- Classes, methods and fields keep their Java names. Classes are grouped into modules by package, in kebab-case. `tree.ts` holds the nodes and the builders, since each creates the other. `context.ts` holds `StringRange`, the contexts and `ContextChain`. `java.ts` holds the parts of the standard library Brigadier needs. `index.ts` exports everything public.
- **Static imports are functions.** `literal`, `argument`, `bool`, `integer`, `longArg`, `floatArg`, `doubleArg`, `word`, `stringArg`, `greedyString`, the `get*` readers and `escapeIfRequired` are exported functions. roblox-ts reserves `string`, so `StringArgumentType.string()` is `stringArg()`, after Brigadier's own `longArg`. `StringType` is a top-level class.
- **Overloads** become optional parameters or unions: `canRead(length?)`, `peek(offset?)`, `execute(input, source)` or `execute(parse)`, `getCompletionSuggestions(parse, cursor?)`, `redirect(target, modifier?)`, and `SuggestionsBuilder.suggest(textOrValue, tooltip?)`, where a number makes an `IntegerSuggestion`. `getThis()` is gone, because builder methods return `this`.
- **Generics.** `ArgumentBuilder<S, T>` is `ArgumentBuilder<S>`, and `ParsedArgument<S, T>` is `ParsedArgument<T>`, since neither uses the other parameter.
- **Functional interfaces** are plain function types. `Command.SINGLE_SUCCESS` is `1`.
- **`ArgumentType`** marks the Java default methods `listSuggestions` and `getExamples` optional.
- **`getArgument(name, class)`** takes a Luau type name such as `"number"`, `"any"` for `Object`, or a class.

## Values

- **Cursors and ranges are 0-based byte offsets**, as in Java, so ranges and cursors in the tests match the Java tests exactly. Add 1 for `string.sub`. Text outside ASCII counts its UTF-8 bytes.
- **`char` is a one-byte string.** `reader.peek()` returns `"a"`.
- **`Character.isWhitespace`** is the ASCII set it covers: tab, line feed, vertical tab, form feed, carriage return, the four separators `\x1C` to `\x1F`, and space.
- **`toLowerCase(Locale.ROOT)`** folds only ASCII, so the lowercase input keeps the same offsets.
- **Numbers.** `int` and `long` values are numbers. `readInt` rejects anything outside 32 bits, as `Integer.parseInt` does. `readLong` checks 64 bits exactly on the digits, but values beyond 2^53 lose precision once read, and `Long.MAX_VALUE` is stored as 2^63. `float` values are rounded to single precision with `string.pack`.
- **`toString`** follows Java's number formatting: `Double.toString` and `Float.toString` give `100.0` and `-2.147483648E9`.
- **`null`** is `undefined`.

## Collections

- A `List` is an array. A node's children are the node's own array, in insertion order. Don't modify it.
- A `Map` compiles to a table with no order. `getSmartUsage()` and `getExceptions()` return one keyed by node. Java's `LinkedHashMap` followed the order of the node's children, so iterate `getChildren()` and look each child up to get that order.
- Java's `HashSet<Suggestion>` keeps one of each equal suggestion. The port does the same with `equals`, keeps the first, and sorts with a stable sort, so ties keep their insertion order where Java's would be arbitrary.

## Exceptions and futures

- `CommandSyntaxException` is thrown as a table. Java's `catch (CommandSyntaxException ex)` is a `catch` that checks `instanceof` and throws anything else on unchanged.
- `IllegalArgumentException`, `IllegalStateException` and `UnsupportedOperationException` are classes that extend `RuntimeException`, so callers and tests can tell them apart.
- The dispatcher wraps a non-syntax error thrown while parsing an argument into `dispatcherParseException`, as Java wraps a `RuntimeException`.
- `CompletableFuture<Suggestions>` is `Promise<Suggestions>`. Suggestions that need no waiting resolve immediately.

## Where the port behaves differently

- **`Float.toString`** prints the fewest digits that identify the float, as the JDK specifies and does since JDK 19. Brigadier's tests were written against JDK 8, which sometimes prints one more digit: `FloatArgumentTypeTest.testToString` expects `-2.14748365E9` there, and the port's test expects `-2.1474836E9`.
- **Mixed suggestion order.** When numbers and words are suggested together, Java's order comes from `HashSet`'s hash order. The port keeps insertion order. Lists of only words or only numbers sort the same as in Java.
- **`Float.parseFloat`** rounds through a double, which differs from Java only for decimals within half a double ulp of the midpoint between two floats.
- **`hashCode`** isn't ported, and neither is the unused private `hasCommand` predicate of `CommandDispatcher`.

## Tests

The tests in `test/` are Brigadier's JUnit tests, ported to Luau one to one: same names, same order, same assertions. They run in Lune against the compiled package, through a small JUnit, Hamcrest and Mockito harness in `test/lib`. From Luau, constructors are `Class.new`, instance and static methods use a colon (`StringRange:at(0)`), and exported functions use a dot. `then` is a Luau keyword, so `test/lib/load.luau` gives `ArgumentBuilder.then` the name `with`.

roblox-ts gives a subclass no `__tostring` unless the subclass declares `toString` itself. Every subclass that Java gives a `toString` declares one.
