--!strict
-- Port of the JMH ExecuteBenchmarks: `lune run bench/ExecuteBenchmarks`.

local Types = require("@brigadier/Types")
local CommandDispatcher = require("@brigadier/CommandDispatcher")
local LiteralArgumentBuilder = require("@brigadier/builder/LiteralArgumentBuilder")

local literal = LiteralArgumentBuilder.literal

local WARMUP_ITERATIONS = 10_000
local ITERATIONS = 100_000

local dispatcher: Types.CommandDispatcher<any>
local simple: Types.ParseResults<any>
local singleRedirect: Types.ParseResults<any>
local forkedRedirect: Types.ParseResults<any>

local function setup()
	dispatcher = CommandDispatcher.new()
	dispatcher:register(literal("command"):executes(function(_c)
		return 0
	end))
	dispatcher:register(literal("redirect"):redirect(dispatcher:getRoot()))
	dispatcher:register(literal("fork"):fork(dispatcher:getRoot(), function(_o)
		return { {}, {}, {} }
	end))
	simple = dispatcher:parse("command", {})
	singleRedirect = dispatcher:parse("redirect command", {})
	forkedRedirect = dispatcher:parse("fork command", {})
end

local function execute_simple()
	dispatcher:execute(simple)
end

local function execute_single_redirect()
	dispatcher:execute(singleRedirect)
end

local function execute_forked_redirect()
	dispatcher:execute(forkedRedirect)
end

local function benchmark(name: string, run: () -> ())
	for _ = 1, WARMUP_ITERATIONS do
		run()
	end
	local start = os.clock()
	for _ = 1, ITERATIONS do
		run()
	end
	local elapsed = os.clock() - start
	print(string.format("ExecuteBenchmarks.%-24s %12.1f ns/op", name, elapsed / ITERATIONS * 1e9))
end

setup()
benchmark("execute_simple", execute_simple)
benchmark("execute_single_redirect", execute_single_redirect)
benchmark("execute_forked_redirect", execute_forked_redirect)
