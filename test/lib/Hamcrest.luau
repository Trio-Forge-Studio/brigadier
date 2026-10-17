--!strict

-- The Hamcrest matchers the Java tests use, with the same names. `not` is a Luau keyword, so its
-- matcher is `not_`.

local Equality = require("./Equality")

local Hamcrest = {}

export type Matcher = {
	matches: (actual: unknown) -> boolean,
	describe: () -> string,
	isMatcher: true,
}

local function matcher(matches: (actual: unknown) -> boolean, describe: () -> string): Matcher
	return { matches = matches, describe = describe, isMatcher = true }
end

function Hamcrest.isMatcher(value: unknown): boolean
	return type(value) == "table" and getmetatable(value :: any) == nil and (value :: any).isMatcher == true
end

local function asMatcher(value: unknown): Matcher
	if Hamcrest.isMatcher(value) then
		return value :: Matcher
	end
	return Hamcrest.equalTo(value)
end

function Hamcrest.equalTo(expected: unknown): Matcher
	return matcher(function(actual)
		return Equality.equals(actual, expected)
	end, function()
		return Equality.describe(expected)
	end)
end

function Hamcrest.is(expected: unknown): Matcher
	return asMatcher(expected)
end

function Hamcrest.not_(expected: unknown): Matcher
	local inner = asMatcher(expected)
	return matcher(function(actual)
		return not inner.matches(actual)
	end, function()
		return "not " .. inner.describe()
	end)
end

function Hamcrest.nullValue(): Matcher
	return matcher(function(actual)
		return actual == nil
	end, function()
		return "null"
	end)
end

function Hamcrest.notNullValue(): Matcher
	return matcher(function(actual)
		return actual ~= nil
	end, function()
		return "not null"
	end)
end

function Hamcrest.sameInstance(expected: unknown): Matcher
	return matcher(function(actual)
		return rawequal(actual, expected)
	end, function()
		return "sameInstance(" .. Equality.describe(expected) .. ")"
	end)
end

local function sizeOf(value: unknown): number?
	if type(value) ~= "table" then
		return nil
	end
	local count = 0
	for _ in value :: any do
		count += 1
	end
	return count
end

function Hamcrest.hasSize(size: number): Matcher
	return matcher(function(actual)
		return sizeOf(actual) == size
	end, function()
		return `a collection with size {size}`
	end)
end

function Hamcrest.empty(): Matcher
	return matcher(function(actual)
		return sizeOf(actual) == 0
	end, function()
		return "an empty collection"
	end)
end

function Hamcrest.hasItem(item: unknown): Matcher
	local inner = asMatcher(item)
	return matcher(function(actual)
		if type(actual) ~= "table" then
			return false
		end
		for _, value in actual :: any do
			if inner.matches(value) then
				return true
			end
		end
		return false
	end, function()
		return "a collection containing " .. inner.describe()
	end)
end

function Hamcrest.hasToString(expected: unknown): Matcher
	local inner = asMatcher(expected)
	return matcher(function(actual)
		return inner.matches(tostring(actual))
	end, function()
		return "with toString() " .. inner.describe()
	end)
end

-- new CustomMatcher<T>(description) { boolean matches(Object item) { ... } }
function Hamcrest.CustomMatcher(description: string, matches: (actual: unknown) -> boolean): Matcher
	return matcher(matches, function()
		return description
	end)
end

-- Reads a JavaBeans property through its getter: hasProperty("source", ...) calls getSource().
function Hamcrest.hasProperty(name: string, expected: unknown): Matcher
	local inner = asMatcher(expected)
	local getter = "get" .. name:sub(1, 1):upper() .. name:sub(2)
	return matcher(function(actual)
		if type(actual) ~= "table" then
			return false
		end
		local method: unknown = (actual :: any)[getter]
		if type(method) ~= "function" then
			return false
		end
		return inner.matches((method :: (any) -> unknown)(actual))
	end, function()
		return `hasProperty("{name}", {inner.describe()})`
	end)
end

-- assertThat(actual, matcher) and assertThat(reason, boolean), as in org.hamcrest.MatcherAssert.
function Hamcrest.assertThat(actual: unknown, expected: unknown)
	if type(actual) == "string" and type(expected) == "boolean" then
		if not expected then
			error(`AssertionError: {actual}`, 2)
		end
		return
	end
	local inner = asMatcher(expected)
	if not inner.matches(actual) then
		error(`AssertionError:\nExpected: {inner.describe()}\n     but: was {Equality.describe(actual)}`, 2)
	end
end

return Hamcrest
