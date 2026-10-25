--!strict

-- A JUnit 4 test class becomes a suite: `@Before` methods are `suite:before`, `@Test` methods are
-- `suite:test`. Each test gets fresh state from the before hooks, like JUnit's new instance per test.

local Class = require("./Class")

local JUnit = {}

export type Test = {
	name: string,
	run: () -> (),
}

export type Suite = {
	name: string,
	befores: { () -> () },
	cases: { Test },
	before: (self: Suite, hook: () -> ()) -> (),
	test: (self: Suite, name: string, run: () -> ()) -> (),
	tests: (self: Suite) -> { [string]: () -> () },
}

function JUnit.suite(name: string): Suite
	local suite = {
		name = name,
		befores = {},
		cases = {},
	}
	function suite.before(self: Suite, hook: () -> ())
		table.insert(self.befores, hook)
	end
	function suite.test(self: Suite, testName: string, run: () -> ())
		for _, existing in self.cases do
			assert(existing.name ~= testName, `{name}: duplicate test {testName}`)
		end
		table.insert(self.cases, { name = testName, run = run })
	end
	function suite.tests(self: Suite): { [string]: () -> () }
		local tests: { [string]: () -> () } = {}
		for _, case in self.cases do
			tests[case.name] = function()
				for _, hook in self.befores do
					hook()
				end
				case.run()
			end
		end
		return tests
	end
	return suite :: Suite
end

function JUnit.fail(message: string?): never
	error(`AssertionError: {message or "fail()"}`, 2)
end

local function describeError(err: unknown): string
	if type(err) == "table" and type((err :: any).getMessage) == "function" then
		return `{tostring(err)} ({(err :: any):getMessage()})`
	end
	return tostring(err)
end

-- `try { ...; fail(); } catch (final X ex) { ... }` and `@Test(expected = X.class)`: runs the body,
-- fails if it doesn't throw, raises anything that isn't an X again, and returns the exception.
function JUnit.assertThrows(class: unknown, body: () -> ()): any
	local ok, err = pcall(body)
	if ok then
		error("AssertionError: expected an exception to be thrown, but nothing was", 2)
	end
	if not Class.isInstance(err, class) then
		error(`Unexpected exception type thrown: {describeError(err)}`, 2)
	end
	return err
end

return JUnit
