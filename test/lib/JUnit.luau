--!strict

-- A JUnit 4 test class becomes a suite: `@Before` methods are `suite:before`, `@Test` methods are
-- `suite:test`. Each test gets fresh state from the before hooks, like JUnit's new instance per test.

local JUnit = {}

export type Test = {
	name: string,
	run: () -> (),
}

-- Static helpers of a Java test class, such as CommandDispatcherTest.contextSourceMatches, are
-- extra fields on its suite.
export type Suite = {
	[string]: any,
	name: string,
	befores: { () -> () },
	tests: { Test },
	before: (self: Suite, hook: () -> ()) -> (),
	test: (self: Suite, name: string, run: () -> ()) -> (),
}

function JUnit.suite(name: string): Suite
	local suite = {
		name = name,
		befores = {},
		tests = {},
	}
	function suite.before(self: Suite, hook: () -> ())
		table.insert(self.befores, hook)
	end
	function suite.test(self: Suite, testName: string, run: () -> ())
		for _, existing in self.tests do
			assert(existing.name ~= testName, `{name}: duplicate test {testName}`)
		end
		table.insert(self.tests, { name = testName, run = run })
	end
	return suite :: Suite
end

function JUnit.fail(message: string?): never
	error(`AssertionError: {message or "fail()"}`, 2)
end

type ExceptionClass = {
	isInstance: (value: unknown) -> boolean,
}

local function describeError(err: unknown): string
	if type(err) == "table" and type((err :: any).getMessage) == "function" then
		return `{tostring(err)} ({(err :: any):getMessage()})`
	end
	return tostring(err)
end

-- `try { ...; fail(); } catch (final X ex) { ... }` and `@Test(expected = X.class)`: runs the body,
-- fails if it doesn't throw, raises anything that isn't an X again, and returns the exception.
function JUnit.assertThrows(class: ExceptionClass, body: () -> ()): any
	local ok, err = pcall(body)
	if ok then
		error("AssertionError: expected an exception to be thrown, but nothing was", 2)
	end
	if not class.isInstance(err) then
		error(`Unexpected exception type thrown: {describeError(err)}`, 2)
	end
	return err
end

return JUnit
