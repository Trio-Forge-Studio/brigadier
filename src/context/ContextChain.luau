--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local CommandSyntaxException = require("../exceptions/CommandSyntaxException")
local RuntimeException = require("../util/RuntimeException")

-- The source type. The public types in Types.luau keep it generic; the implementation uses `any`,
-- which keeps the new solver from giving up on these mutually recursive types.
type S = any

type ContextChain = Types.ContextChain<S> & {
	-- TODO ideally those two would have separate types, but modifiers and executables expect full context
	_modifiers: { Types.CommandContext<S> },
	_executable: Types.CommandContext<S>,
	_nextStageCache: Types.ContextChain<S>?,
}

local ContextChain = {}
ContextChain.__index = ContextChain

ContextChain.Stage = table.freeze({
	MODIFY = "MODIFY" :: "MODIFY",
	EXECUTE = "EXECUTE" :: "EXECUTE",
})

function ContextChain.new(
	modifiers: { Types.CommandContext<S> },
	executable: Types.CommandContext<S>
): Types.ContextChain<S>
	if executable:getCommand() == nil then
		error(RuntimeException.IllegalArgumentException.new("Last command in chain must be executable"))
	end
	local self: ContextChain = setmetatable({
		_modifiers = modifiers,
		_executable = executable,
		_nextStageCache = nil,
	}, ContextChain) :: any
	return self
end

function ContextChain.isInstance(value: unknown): boolean
	return Class.isInstance(value, ContextChain)
end

function ContextChain.tryFlatten(rootContext: Types.CommandContext<S>): Types.ContextChain<S>?
	local modifiers = {}

	local current = rootContext

	while true do
		local child = current:getChild()
		if child == nil then
			-- Last entry must be executable command
			if current:getCommand() == nil then
				return nil
			end

			return ContextChain.new(modifiers, current)
		end

		table.insert(modifiers, current)
		current = child
	end
end

-- Runs `body` and calls `onSyntaxException` with a CommandSyntaxException it throws; any other error
-- propagates unchanged, as only the checked exception is caught in Java.
local function catchSyntax<T>(body: () -> T, onSyntaxException: (Types.CommandSyntaxException) -> T): T
	local ok, result = pcall(body)
	if ok then
		return result
	end
	if CommandSyntaxException.isInstance(result) then
		return onSyntaxException(result :: any)
	end
	error(result, 0)
end

function ContextChain.runModifier(
	modifier: Types.CommandContext<S>,
	source: S,
	resultConsumer: Types.ResultConsumer<S>,
	forkedMode: boolean
): { S }
	local sourceModifier = modifier:getRedirectModifier()

	-- Note: source currently in context is irrelevant at this point, since we might have updated it in one of earlier stages
	if sourceModifier == nil then
		-- Simple redirect, just propagate source to next node
		return { source }
	end

	local contextToUse = modifier:copyFor(source)
	return catchSyntax(function(): { S }
		return sourceModifier(contextToUse)
	end, function(ex): { S }
		resultConsumer(contextToUse, false, 0)
		if forkedMode then
			return {}
		end
		error(ex)
	end)
end

function ContextChain.runExecutable(
	executable: Types.CommandContext<S>,
	source: S,
	resultConsumer: Types.ResultConsumer<S>,
	forkedMode: boolean
): number
	local contextToUse = executable:copyFor(source)
	return catchSyntax(function(): number
		local command = executable:getCommand() :: Types.Command<S>
		local result = command(contextToUse)
		resultConsumer(contextToUse, true, result)
		return if forkedMode then 1 else result
	end, function(ex): number
		resultConsumer(contextToUse, false, 0)
		if forkedMode then
			return 0
		end
		error(ex)
	end)
end

function ContextChain.executeAll(self: ContextChain, source: S, resultConsumer: Types.ResultConsumer<S>): number
	if #self._modifiers == 0 then
		-- Fast path - just a single stage
		return ContextChain.runExecutable(self._executable, source, resultConsumer, false)
	end

	local forkedMode = false
	local currentSources = { source }

	for _, modifier in self._modifiers do
		forkedMode = forkedMode or modifier:isForked()

		local nextSources = {}
		for _, sourceToRun in currentSources do
			for _, nextSource in ContextChain.runModifier(modifier, sourceToRun, resultConsumer, forkedMode) do
				table.insert(nextSources, nextSource)
			end
		end
		if #nextSources == 0 then
			return 0
		end
		currentSources = nextSources
	end

	local result = 0
	for _, executionSource in currentSources do
		result += ContextChain.runExecutable(self._executable, executionSource, resultConsumer, forkedMode)
	end

	return result
end

function ContextChain.getStage(self: ContextChain): Types.ContextChainStage
	return if #self._modifiers == 0 then ContextChain.Stage.EXECUTE else ContextChain.Stage.MODIFY
end

function ContextChain.getTopContext(self: ContextChain): Types.CommandContext<S>
	if #self._modifiers == 0 then
		return self._executable
	end
	return self._modifiers[1]
end

function ContextChain.nextStage(self: ContextChain): Types.ContextChain<S>?
	local modifierCount = #self._modifiers
	if modifierCount == 0 then
		return nil
	end

	if self._nextStageCache == nil then
		self._nextStageCache = ContextChain.new(table.move(self._modifiers, 2, modifierCount, 1, {}), self._executable)
	end
	return self._nextStageCache
end

return ContextChain
