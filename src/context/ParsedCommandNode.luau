--!strict

local Types = require("../Types")
local Class = require("../util/Class")
local Objects = require("../util/Objects")

-- The source type. The public types in Types.luau keep it generic; the implementation uses `any`,
-- which keeps the new solver from giving up on these mutually recursive types.
type S = any

type ParsedCommandNode = Types.ParsedCommandNode<S> & {
	_node: Types.CommandNode<S>,
	_range: Types.StringRange,
}

local ParsedCommandNode = {}
ParsedCommandNode.__index = ParsedCommandNode

function ParsedCommandNode.new(node: Types.CommandNode<S>, range: Types.StringRange): Types.ParsedCommandNode<S>
	local self: ParsedCommandNode = setmetatable({ _node = node, _range = range }, ParsedCommandNode) :: any
	return self
end

function ParsedCommandNode.isInstance(value: unknown): boolean
	return Class.isInstance(value, ParsedCommandNode)
end

function ParsedCommandNode.getNode(self: ParsedCommandNode): Types.CommandNode<S>
	return self._node
end

function ParsedCommandNode.getRange(self: ParsedCommandNode): Types.StringRange
	return self._range
end

function ParsedCommandNode.__tostring(self: ParsedCommandNode): string
	return tostring(self._node) .. "@" .. tostring(self._range)
end

-- Java compares getClass(), so a subclass instance is never equal to a ParsedCommandNode.
function ParsedCommandNode.equals(self: ParsedCommandNode, other: unknown): boolean
	if rawequal(self, other) then
		return true
	end
	if other == nil or getmetatable(other :: any) ~= getmetatable(self :: any) then
		return false
	end
	local that = other :: ParsedCommandNode
	return Objects.equals(self._node, that._node) and Objects.equals(self._range, that._range)
end

return ParsedCommandNode
