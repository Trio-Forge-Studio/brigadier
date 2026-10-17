--!strict

local Types = require("../Types")
local Class = require("../util/Class")

-- The source type. The public types in Types.luau keep it generic; the implementation uses `any`,
-- which keeps the new solver from giving up on these mutually recursive types.
type S = any

local SuggestionContext = {}
SuggestionContext.__index = SuggestionContext

function SuggestionContext.new(
	context: Types.CommandContextBuilder<S>,
	parent: Types.CommandNode<S>,
	startPos: number
): Types.SuggestionContext<S>
	return setmetatable({ context = context, parent = parent, startPos = startPos }, SuggestionContext) :: any
end

function SuggestionContext.isInstance(value: unknown): boolean
	return Class.isInstance(value, SuggestionContext)
end

return SuggestionContext
