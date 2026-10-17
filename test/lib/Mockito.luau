--!strict

-- The part of Mockito the Java tests use.
--
-- A functional interface (Command, ResultConsumer, RedirectModifier) is a function in the port, so
-- `mock()` returns a callable mock. `mockObject()` stands in for a mocked class: every method it is
-- asked for is a callable mock, and `equals` is identity unless stubbed, as in Mockito.
--
--   Java                                            Luau
--   when(command.run(any())).thenReturn(42)          when(command, any()):thenReturn(42)
--   when(reader.readInt()).thenReturn(1)             when(reader.readInt):thenReturn(1)
--   verify(command).run(any())                       verify(command, any())
--   verify(command, times(2)).run(any())             verify(command, times(2), any())
--   verify(consumer).onCommandComplete(any(), eq(true), eq(5))
--                                                    verify(consumer, any(), eq(true), eq(5))

local Equality = require("./Equality")
local Hamcrest = require("./Hamcrest")

local Mockito = {}

type ArgMatcher = {
	matchesArg: (value: unknown) -> boolean,
	describe: () -> string,
	isArgMatcher: true,
}

type Invocation = {
	args: { unknown },
	count: number,
	verified: boolean,
}

type Stubbing = {
	matchers: { ArgMatcher },
	answers: { () -> ...unknown },
}

type MockState = {
	name: string,
	owner: unknown?,
	invocations: { Invocation },
	stubbings: { Stubbing },
}

type VerificationMode = {
	wanted: number?,
	atLeast: number?,
	isVerificationMode: true,
}

local states: { [unknown]: MockState } = setmetatable({}, { __mode = "k" }) :: any
local objects: { [unknown]: { MockState } } = setmetatable({}, { __mode = "k" }) :: any

local function isArgMatcher(value: unknown): boolean
	return type(value) == "table" and getmetatable(value :: any) == nil and (value :: any).isArgMatcher == true
end

local function eq(value: unknown): ArgMatcher
	return {
		matchesArg = function(actual)
			return Equality.equals(actual, value)
		end,
		describe = function()
			return Equality.describe(value)
		end,
		isArgMatcher = true,
	}
end

local function asArgMatchers(values: { unknown }, count: number): { ArgMatcher }
	local result = {}
	for index = 1, count do
		local value = values[index]
		if isArgMatcher(value) then
			table.insert(result, value :: ArgMatcher)
		else
			table.insert(result, eq(value))
		end
	end
	return result
end

local function matchesAll(matchers: { ArgMatcher }, invocation: Invocation): boolean
	if #matchers ~= invocation.count then
		return false
	end
	for index, argMatcher in matchers do
		if not argMatcher.matchesArg(invocation.args[index]) then
			return false
		end
	end
	return true
end

local function describeInvocation(state: MockState, args: { unknown }, count: number): string
	local parts = {}
	for index = 1, count do
		table.insert(parts, Equality.describe(args[index]))
	end
	return `{state.name}({table.concat(parts, ", ")})`
end

local function describeMatchers(state: MockState, matchers: { ArgMatcher }): string
	local parts = {}
	for _, argMatcher in matchers do
		table.insert(parts, argMatcher.describe())
	end
	return `{state.name}({table.concat(parts, ", ")})`
end

local function stateOf(mock: unknown): MockState
	local state = states[mock]
	if state == nil then
		error("Argument passed to Mockito is not a mock", 3)
	end
	return state
end

local function newMock(name: string, owner: unknown?): any
	local state: MockState = { name = name, owner = owner, invocations = {}, stubbings = {} }
	local callable = setmetatable({}, {
		__call = function(_self, ...)
			local count = select("#", ...)
			local args = { ... }
			-- A method called with `:` passes its object first; Java's invocation doesn't include it.
			if owner ~= nil and count > 0 and rawequal(args[1], owner) then
				table.remove(args, 1)
				count -= 1
			end
			local invocation: Invocation = { args = args, count = count, verified = false }
			table.insert(state.invocations, invocation)
			for index = #state.stubbings, 1, -1 do
				local stubbing = state.stubbings[index]
				if matchesAll(stubbing.matchers, invocation) then
					local answer = stubbing.answers[1]
					if #stubbing.answers > 1 then
						table.remove(stubbing.answers, 1)
					end
					return answer()
				end
			end
			return nil
		end,
		__tostring = function()
			return state.name
		end,
	})
	states[callable] = state
	return callable
end

-- mock(Command.class) and the other functional interfaces.
function Mockito.mock(name: string?): any
	return newMock(name or "mock")
end

-- mock(SomeClass.class): an object whose methods are mocks.
function Mockito.mockObject(name: string?): any
	local objectName = name or "mockObject"
	local methods: { [string]: any } = {}
	local list: { MockState } = {}
	local object: any
	object = setmetatable({}, {
		__index = function(_self, key: string)
			local method = methods[key]
			if method == nil then
				method = newMock(`{objectName}.{key}`, object)
				methods[key] = method
				table.insert(list, states[method])
				if key == "equals" then
					Mockito.when(method, Mockito.any()):thenAnswer(function(other)
						return rawequal(object, other)
					end)
					-- The default answer above is setup, not an interaction.
					table.clear(states[method].invocations)
				end
			end
			return method
		end,
		__tostring = function()
			return objectName
		end,
	})
	objects[object] = list
	return object
end

export type OngoingStubbing = {
	thenReturn: (self: OngoingStubbing, ...unknown) -> OngoingStubbing,
	thenThrow: (self: OngoingStubbing, ...unknown) -> OngoingStubbing,
	thenAnswer: (self: OngoingStubbing, answer: (...any) -> ...unknown) -> OngoingStubbing,
}

-- when(mock, ...argument matchers). Later stubbings win over earlier ones, as in Mockito.
function Mockito.when(mock: unknown, ...: unknown): OngoingStubbing
	local state = stateOf(mock)
	local stubbing: Stubbing = { matchers = asArgMatchers({ ... }, select("#", ...)), answers = {} }
	table.insert(state.stubbings, stubbing)

	local ongoing = {}
	function ongoing.thenReturn(self: OngoingStubbing, ...: unknown): OngoingStubbing
		for index = 1, math.max(select("#", ...), 1) do
			local value = select(index, ...)
			table.insert(stubbing.answers, function()
				return value
			end)
		end
		return self
	end
	function ongoing.thenThrow(self: OngoingStubbing, ...: unknown): OngoingStubbing
		for index = 1, select("#", ...) do
			local err = select(index, ...)
			table.insert(stubbing.answers, function(): ()
				error(err, 0)
			end)
		end
		return self
	end
	function ongoing.thenAnswer(self: OngoingStubbing, answer: (...any) -> ...unknown): OngoingStubbing
		local invocations = state.invocations
		table.insert(stubbing.answers, function()
			local invocation = invocations[#invocations]
			return answer(table.unpack(invocation.args, 1, invocation.count))
		end)
		return self
	end
	return ongoing :: any
end

function Mockito.times(wanted: number): VerificationMode
	return { wanted = wanted, isVerificationMode = true }
end

function Mockito.never(): VerificationMode
	return Mockito.times(0)
end

function Mockito.atLeastOnce(): VerificationMode
	return { atLeast = 1, isVerificationMode = true }
end

-- verify(mock, [mode], ...argument matchers)
function Mockito.verify(mock: unknown, ...: unknown)
	local state = stateOf(mock)
	local args = { ... }
	local count = select("#", ...)
	local mode: VerificationMode = Mockito.times(1)
	if count > 0 and type(args[1]) == "table" and (args[1] :: any).isVerificationMode == true then
		mode = table.remove(args, 1) :: any
		count -= 1
	end
	local matchers = asArgMatchers(args, count)

	local matched = {}
	for _, invocation in state.invocations do
		if matchesAll(matchers, invocation) then
			table.insert(matched, invocation)
		end
	end

	local ok
	if mode.atLeast ~= nil then
		ok = #matched >= mode.atLeast
	else
		ok = #matched == mode.wanted
	end
	if not ok then
		local seen = {}
		for _, invocation in state.invocations do
			table.insert(seen, "  " .. describeInvocation(state, invocation.args, invocation.count))
		end
		local wanted = if mode.atLeast ~= nil then `at least {mode.atLeast}` else tostring(mode.wanted)
		error(
			`Wanted {wanted} time(s): {describeMatchers(state, matchers)}\nbut was {#matched} time(s). Invocations:\n{table.concat(
				seen,
				"\n"
			)}`,
			2
		)
	end
	for _, invocation in matched do
		invocation.verified = true
	end
end

local function statesOf(mock: unknown): { MockState }
	local list = objects[mock]
	if list ~= nil then
		return list
	end
	return { stateOf(mock) }
end

function Mockito.verifyNoMoreInteractions(...: unknown)
	for index = 1, select("#", ...) do
		for _, state in statesOf((select(index, ...))) do
			for _, invocation in state.invocations do
				if not invocation.verified then
					error(
						`No interactions wanted here, but found {describeInvocation(
							state,
							invocation.args,
							invocation.count
						)}`,
						2
					)
				end
			end
		end
	end
end

function Mockito.verifyZeroInteractions(...: unknown)
	for index = 1, select("#", ...) do
		for _, state in statesOf((select(index, ...))) do
			local invocation = state.invocations[1]
			if invocation ~= nil then
				error(
					`No interactions wanted, but found {describeInvocation(state, invocation.args, invocation.count)}`,
					2
				)
			end
		end
	end
end

function Mockito.any(): ArgMatcher
	return {
		matchesArg = function()
			return true
		end,
		describe = function()
			return "any()"
		end,
		isArgMatcher = true,
	}
end

Mockito.eq = eq

-- argThat(hamcrestMatcher) or argThat(function(value): boolean), Mockito's ArgumentMatcher.
function Mockito.argThat(expected: unknown): ArgMatcher
	if Hamcrest.isMatcher(expected) then
		local inner = expected :: Hamcrest.Matcher
		return {
			matchesArg = function(actual)
				return inner.matches(actual)
			end,
			describe = function()
				return inner.describe()
			end,
			isArgMatcher = true,
		}
	end
	local predicate = expected :: (unknown) -> boolean
	return {
		matchesArg = function(actual)
			return predicate(actual)
		end,
		describe = function()
			return "argThat(<predicate>)"
		end,
		isArgMatcher = true,
	}
end

return Mockito
