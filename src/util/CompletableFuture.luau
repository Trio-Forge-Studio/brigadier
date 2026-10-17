--!strict

-- The part of java.util.concurrent.CompletableFuture Brigadier uses. `join` on a future that isn't
-- done yields the running coroutine until another thread completes it.

local Types = require("../Types")
local Class = require("./Class")

type CompletableFuture<T> = Types.CompletableFuture<T> & {
	_done: boolean,
	_value: T?,
	_callbacks: { (T) -> () },
	_waiting: { thread },
	_whenDone: (self: any, callback: (T) -> ()) -> (),
}

local CompletableFuture = {}
CompletableFuture.__index = CompletableFuture

local function resume(thread: thread)
	-- Roblox's scheduler must own threads that wait on engine calls; Lune and plain Luau have no
	-- global task library, and resume the thread directly.
	if task ~= nil then
		task.spawn(thread)
	else
		local ok, err = coroutine.resume(thread)
		if not ok then
			error(err, 0)
		end
	end
end

-- Like `new CompletableFuture<>()`: the caller's annotation gives the value type, which Luau can't
-- infer for a call without arguments.
function CompletableFuture.new(): Types.CompletableFuture<any>
	local self: CompletableFuture<any> = setmetatable({
		_done = false,
		_value = nil,
		_callbacks = {},
		_waiting = {},
	}, CompletableFuture) :: any
	return self
end

function CompletableFuture.completedFuture<T>(value: T): Types.CompletableFuture<T>
	local future = CompletableFuture.new()
	future:complete(value)
	return future
end

function CompletableFuture.isInstance(value: unknown): boolean
	return Class.isInstance(value, CompletableFuture)
end

-- Done when every future is done; the result is nil, as Java's CompletableFuture<Void>.
function CompletableFuture.allOf(futures: { Types.CompletableFuture<any> }): Types.CompletableFuture<nil>
	local result: Types.CompletableFuture<nil> = CompletableFuture.new()
	local remaining = #futures
	if remaining == 0 then
		result:complete(nil)
		return result
	end
	for _, future in futures do
		(future :: any):_whenDone(function()
			remaining -= 1
			if remaining == 0 then
				result:complete(nil)
			end
		end)
	end
	return result
end

function CompletableFuture._whenDone<T>(self: CompletableFuture<T>, callback: (T) -> ())
	if self._done then
		callback(self._value :: T)
	else
		table.insert(self._callbacks, callback)
	end
end

function CompletableFuture.complete<T>(self: CompletableFuture<T>, value: T): boolean
	if self._done then
		return false
	end
	self._done = true
	self._value = value
	local callbacks = self._callbacks
	local waiting = self._waiting
	self._callbacks = {}
	self._waiting = {}
	for _, callback in callbacks do
		callback(value)
	end
	for _, thread in waiting do
		resume(thread)
	end
	return true
end

function CompletableFuture.isDone<T>(self: CompletableFuture<T>): boolean
	return self._done
end

function CompletableFuture.join<T>(self: CompletableFuture<T>): T
	if not self._done then
		if not coroutine.isyieldable() then
			error("CompletableFuture:join() can only wait for an incomplete future from inside a coroutine", 2)
		end
		table.insert(self._waiting, coroutine.running())
		while not self._done do
			coroutine.yield()
		end
	end
	return self._value :: T
end

function CompletableFuture.getNow<T>(self: CompletableFuture<T>, valueIfAbsent: T): T
	if self._done then
		return self._value :: T
	end
	return valueIfAbsent
end

function CompletableFuture.thenApply<T>(self: CompletableFuture<T>, fn: (T) -> any): any
	local result: Types.CompletableFuture<any> = CompletableFuture.new()
	self:_whenDone(function(value)
		result:complete(fn(value))
	end)
	return result
end

function CompletableFuture.thenRun<T>(self: CompletableFuture<T>, action: () -> ()): any
	local result: Types.CompletableFuture<nil> = CompletableFuture.new()
	self:_whenDone(function()
		action()
		result:complete(nil)
	end)
	return result
end

return CompletableFuture
