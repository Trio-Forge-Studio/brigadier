--!strict

-- The java.lang exceptions Brigadier throws besides CommandSyntaxException, so callers can tell them
-- apart.

local Class = require("./Class")

export type RuntimeException = {
	getMessage: (self: RuntimeException) -> string?,
}

type Impl = RuntimeException & { _message: string? }

local function define(name: string, parent: any?)
	local class = {}
	class.__index = class
	if parent then
		Class.extend(class, parent)
	end
	class.__tostring = function(self: Impl): string
		if self._message ~= nil then
			return `java.lang.{name}: {self._message}`
		end
		return `java.lang.{name}`
	end
	function class.new(message: string?): RuntimeException
		local self: Impl = setmetatable({ _message = message }, class) :: any
		return self
	end
	function class.isInstance(value: unknown): boolean
		return Class.isInstance(value, class)
	end
	function class.getMessage(self: Impl): string?
		return self._message
	end
	return class
end

local RuntimeException = define("RuntimeException")

local IndexOutOfBoundsException = define("IndexOutOfBoundsException", RuntimeException)

return {
	RuntimeException = RuntimeException,
	IllegalArgumentException = define("IllegalArgumentException", RuntimeException),
	IllegalStateException = define("IllegalStateException", RuntimeException),
	UnsupportedOperationException = define("UnsupportedOperationException", RuntimeException),
	IndexOutOfBoundsException = IndexOutOfBoundsException,
	StringIndexOutOfBoundsException = define("StringIndexOutOfBoundsException", IndexOutOfBoundsException),
}
