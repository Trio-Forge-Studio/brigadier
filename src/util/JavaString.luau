--!strict

-- String.substring and String.charAt with Java's 0-based indices and bounds checks: Luau's
-- string.sub clamps where Java throws StringIndexOutOfBoundsException.

local RuntimeException = require("./RuntimeException")

local JavaString = {}

function JavaString.substring(text: string, beginIndex: number, endIndex: number?): string
	local finish = if endIndex == nil then #text else endIndex
	if beginIndex < 0 or finish > #text or beginIndex > finish then
		error(RuntimeException.StringIndexOutOfBoundsException.new(`begin {beginIndex}, end {finish}, length {#text}`))
	end
	return string.sub(text, beginIndex + 1, finish)
end

function JavaString.charAt(text: string, index: number): string
	if index < 0 or index >= #text then
		error(RuntimeException.StringIndexOutOfBoundsException.new(`index {index}, length {#text}`))
	end
	return string.sub(text, index + 1, index + 1)
end

function JavaString.startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- toLowerCase(Locale.ROOT) for ASCII, which keeps every offset where it was.
function JavaString.toLowerCase(text: string): string
	return string.lower(text)
end

return JavaString
