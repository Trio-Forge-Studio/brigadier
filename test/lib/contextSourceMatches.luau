--!strict
local B = require("./load")
local Class = require("./Class")
local Hamcrest = require("./Hamcrest")

return function(source: unknown): Hamcrest.Matcher
	return Hamcrest.CustomMatcher("source " .. tostring(source), function(object)
		return Class.isInstance(object, B.CommandContext) and rawequal((object :: any):getSource(), source)
	end)
end
