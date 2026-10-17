--!strict
-- Port of the JMH ParsingBenchmarks: `lune run bench/ParsingBenchmarks`.

local Types = require("@brigadier/Types")
local CommandDispatcher = require("@brigadier/CommandDispatcher")
local LiteralArgumentBuilder = require("@brigadier/builder/LiteralArgumentBuilder")

local literal = LiteralArgumentBuilder.literal

local WARMUP_ITERATIONS = 10_000
local ITERATIONS = 100_000

local subject: Types.CommandDispatcher<any>

local function run0(_c: Types.CommandContext<any>): number
	return 0
end

local function never(_s: any): boolean
	return false
end

local function setup()
	subject = CommandDispatcher.new()
	subject:register(
		literal("a")
			:then_(literal("1"):then_(literal("i"):executes(run0)):then_(literal("ii"):executes(run0)))
			:then_(literal("2"):then_(literal("i"):executes(run0)):then_(literal("ii"):executes(run0)))
	)
	subject:register(literal("b"):then_(literal("1"):executes(run0)))
	subject:register(literal("c"):executes(run0))
	subject:register(literal("d"):requires(never):executes(run0))
	subject:register(
		literal("e")
			:executes(run0)
			:then_(literal("1"):executes(run0):then_(literal("i"):executes(run0)):then_(literal("ii"):executes(run0)))
	)
	subject:register(
		literal("f")
			:then_(literal("1"):then_(literal("i"):executes(run0)):then_(literal("ii"):executes(run0):requires(never)))
			:then_(literal("2"):then_(literal("i"):executes(run0):requires(never)):then_(literal("ii"):executes(run0)))
	)
	subject:register(literal("g"):executes(run0):then_(literal("1"):then_(literal("i"):executes(run0))))
	local h = subject:register(
		literal("h")
			:executes(run0)
			:then_(literal("1"):then_(literal("i"):executes(run0)))
			:then_(literal("2"):then_(literal("i"):then_(literal("ii"):executes(run0))))
			:then_(literal("3"):executes(run0))
	)
	subject:register(literal("i"):executes(run0):then_(literal("1"):executes(run0)):then_(literal("2"):executes(run0)))
	subject:register(literal("j"):redirect(subject:getRoot()))
	subject:register(literal("k"):redirect(h))
end

local function parse_a1i()
	subject:parse("a 1 i", {})
end

local function parse_c()
	subject:parse("c", {})
end

local function parse_k1i()
	subject:parse("k 1 i", {})
end

local function parse_()
	subject:parse("c", {})
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
	print(string.format("ParsingBenchmarks.%-10s %12.1f ns/op", name, elapsed / ITERATIONS * 1e9))
end

setup()
benchmark("parse_a1i", parse_a1i)
benchmark("parse_c", parse_c)
benchmark("parse_k1i", parse_k1i)
benchmark("parse_", parse_)
