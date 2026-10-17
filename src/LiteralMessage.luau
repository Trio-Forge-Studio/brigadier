--!strict

local Types = require("./Types")
local Class = require("./util/Class")

type LiteralMessage = Types.Message & { _string: string }

local LiteralMessage = {}
LiteralMessage.__index = LiteralMessage

function LiteralMessage.new(text: string): Types.Message
	local self: LiteralMessage = setmetatable({ _string = text }, LiteralMessage) :: any
	return self
end

function LiteralMessage.isInstance(value: unknown): boolean
	return Class.isInstance(value, LiteralMessage)
end

function LiteralMessage.getString(self: LiteralMessage): string
	return self._string
end

function LiteralMessage.__tostring(self: LiteralMessage): string
	return self._string
end

return LiteralMessage
