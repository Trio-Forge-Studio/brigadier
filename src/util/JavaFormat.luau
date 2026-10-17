--!strict

-- Java's string conversion of numbers, which Brigadier's messages and toString methods use.
--
-- Double.toString and Float.toString print the fewest digits that read back as the same value, as
-- the JDK specifies and does since JDK 19. Older JDKs sometimes printed one more digit: JDK 8 gives
-- "-2.14748365E9" for (float) Integer.MIN_VALUE where this gives "-2.1474836E9".

local JavaFormat = {}

local LONG_MAX_DOUBLE = 2 ^ 63

-- Integer.toString and Long.toString. Long.MAX_VALUE has no exact double: the port stores it as
-- 2^63, which prints as the long it stands for.
function JavaFormat.integer(value: number): string
	if value >= LONG_MAX_DOUBLE then
		return "9223372036854775807"
	end
	return string.format("%d", value)
end

local function toFloat(value: number): number
	return string.unpack("<f", string.pack("<f", value)) :: number
end

-- The shortest decimal digits and exponent that `readsBack` accepts for a positive finite value.
local function shortest(value: number, maxDigits: number, readsBack: (number) -> boolean): (string, number)
	local text = ""
	for precision = 1, maxDigits do
		text = string.format(`%.{precision - 1}e`, value)
		if readsBack(tonumber(text) :: number) then
			break
		end
	end
	local mantissa, exponent = string.match(text, "^([%d%.]+)e([%+%-]%d+)$")
	assert(mantissa and exponent, "unexpected number format")
	local digits = string.gsub(mantissa, "%.", "")
	digits = string.gsub(digits, "0+$", "")
	if digits == "" then
		digits = "0"
	end
	return digits, tonumber(exponent) :: number
end

local function format(value: number, maxDigits: number, readsBack: (number) -> boolean): string
	if value ~= value then
		return "NaN"
	end
	if value == math.huge then
		return "Infinity"
	end
	if value == -math.huge then
		return "-Infinity"
	end
	if value == 0 then
		return if 1 / value < 0 then "-0.0" else "0.0"
	end
	local sign = if value < 0 then "-" else ""
	local magnitude = math.abs(value)
	local digits, exponent = shortest(magnitude, maxDigits, readsBack)

	if magnitude >= 1e-3 and magnitude < 1e7 then
		if exponent >= 0 then
			local whole = digits:sub(1, exponent + 1)
			whole ..= string.rep("0", exponent + 1 - #whole)
			local fraction = digits:sub(exponent + 2)
			return `{sign}{whole}.{if fraction == "" then "0" else fraction}`
		end
		return `{sign}0.{string.rep("0", -exponent - 1)}{digits}`
	end
	local fraction = digits:sub(2)
	return `{sign}{digits:sub(1, 1)}.{if fraction == "" then "0" else fraction}E{exponent}`
end

function JavaFormat.double(value: number): string
	return format(value, 17, function(candidate)
		return candidate == math.abs(value)
	end)
end

function JavaFormat.float(value: number): string
	local single = toFloat(value)
	return format(single, 9, function(candidate)
		return toFloat(candidate) == math.abs(single)
	end)
end

JavaFormat.toFloat = toFloat

return JavaFormat
