--!strict

local Types = require("./Types")
local Class = require("./util/Class")
local CommandSyntaxException = require("./exceptions/CommandSyntaxException")
local JavaFormat = require("./util/JavaFormat")
local JavaString = require("./util/JavaString")

type StringReader = Types.StringReader & {
	_string: string,
	_cursor: number,
}

local SYNTAX_ESCAPE = "\\"
local SYNTAX_DOUBLE_QUOTE = '"'
local SYNTAX_SINGLE_QUOTE = "'"

local INT_MIN = -2147483648
local INT_MAX = 2147483647
local LONG_MIN_DIGITS = "9223372036854775808"
local LONG_MAX_DIGITS = "9223372036854775807"

local StringReader = {}
StringReader.__index = StringReader

function StringReader.new(stringOrReader: string | Types.StringReader): Types.StringReader
	local text, cursor
	if type(stringOrReader) == "string" then
		text, cursor = stringOrReader, 0
	else
		local other = stringOrReader :: StringReader
		text, cursor = other._string, other._cursor
	end
	local self: StringReader = setmetatable({ _string = text, _cursor = cursor }, StringReader) :: any
	return self
end

function StringReader.isInstance(value: unknown): boolean
	return Class.isInstance(value, StringReader)
end

function StringReader.getString(self: StringReader): string
	return self._string
end

function StringReader.setCursor(self: StringReader, cursor: number)
	self._cursor = cursor
end

function StringReader.getRemainingLength(self: StringReader): number
	return #self._string - self._cursor
end

function StringReader.getTotalLength(self: StringReader): number
	return #self._string
end

function StringReader.getCursor(self: StringReader): number
	return self._cursor
end

function StringReader.getRead(self: StringReader): string
	return JavaString.substring(self._string, 0, self._cursor)
end

function StringReader.getRemaining(self: StringReader): string
	return JavaString.substring(self._string, self._cursor)
end

function StringReader.canRead(self: StringReader, length: number?): boolean
	return self._cursor + (length or 1) <= #self._string
end

function StringReader.peek(self: StringReader, offset: number?): string
	return JavaString.charAt(self._string, self._cursor + (offset or 0))
end

function StringReader.read(self: StringReader): string
	local c = JavaString.charAt(self._string, self._cursor)
	self._cursor += 1
	return c
end

function StringReader.skip(self: StringReader)
	self._cursor += 1
end

function StringReader.isAllowedNumber(c: string): boolean
	return c >= "0" and c <= "9" or c == "." or c == "-"
end

function StringReader.isQuotedStringStart(c: string): boolean
	return c == SYNTAX_DOUBLE_QUOTE or c == SYNTAX_SINGLE_QUOTE
end

-- Character.isWhitespace for the one-byte characters it accepts.
local function isWhitespace(c: string): boolean
	local byte = string.byte(c)
	return byte ~= nil and (byte >= 9 and byte <= 13 or byte >= 28 and byte <= 32)
end

function StringReader.skipWhitespace(self: StringReader)
	while self:canRead() and isWhitespace(self:peek()) do
		self:skip()
	end
end

-- Integer.parseInt and Long.parseLong: an optional sign, then decimal digits that fit the type.
local function parseWholeNumber(text: string, minDigits: string, maxDigits: string): number?
	local sign, digits = string.match(text, "^([+-]?)(%d+)$")
	if digits == nil then
		return nil
	end
	local significant = string.match(digits, "^0*(%d-)$") :: string
	local limit = if sign == "-" then minDigits else maxDigits
	if #significant > #limit or #significant == #limit and significant > limit then
		return nil
	end
	-- Adding zero turns "-0" into 0, which is what an int holds.
	return (tonumber(text) :: number) + 0
end

local function parseInt(text: string): number?
	local value = parseWholeNumber(text, "2147483648", "2147483647")
	if value == nil or value < INT_MIN or value > INT_MAX then
		return nil
	end
	return value
end

local function parseLong(text: string): number?
	return parseWholeNumber(text, LONG_MIN_DIGITS, LONG_MAX_DIGITS)
end

-- Double.parseDouble for the characters isAllowedNumber lets through: an optional minus, then digits
-- with at most one point and at least one digit.
local function parseDouble(text: string): number?
	local body = string.match(text, "^%-?([%d%.]+)$")
	if body == nil or not string.find(body, "%d") then
		return nil
	end
	local _, points = string.gsub(body, "%.", "")
	if points > 1 then
		return nil
	end
	return tonumber(text)
end

-- Float.parseFloat rounds the decimal straight to a float; this rounds through a double first, which
-- differs only for decimals that land within half a double ulp of the midpoint between two floats.
local function parseFloat(text: string): number?
	local value = parseDouble(text)
	if value == nil then
		return nil
	end
	return JavaFormat.toFloat(value)
end

function StringReader.readInt(self: StringReader): number
	local start = self._cursor
	while self:canRead() and StringReader.isAllowedNumber(self:peek()) do
		self:skip()
	end
	local number = JavaString.substring(self._string, start, self._cursor)
	if number == "" then
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedInt():createWithContext(self))
	end
	local value = parseInt(number)
	if value == nil then
		self._cursor = start
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerInvalidInt():createWithContext(self, number))
	end
	return value
end

function StringReader.readLong(self: StringReader): number
	local start = self._cursor
	while self:canRead() and StringReader.isAllowedNumber(self:peek()) do
		self:skip()
	end
	local number = JavaString.substring(self._string, start, self._cursor)
	if number == "" then
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedLong():createWithContext(self))
	end
	local value = parseLong(number)
	if value == nil then
		self._cursor = start
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerInvalidLong():createWithContext(self, number))
	end
	return value
end

function StringReader.readDouble(self: StringReader): number
	local start = self._cursor
	while self:canRead() and StringReader.isAllowedNumber(self:peek()) do
		self:skip()
	end
	local number = JavaString.substring(self._string, start, self._cursor)
	if number == "" then
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedDouble():createWithContext(self))
	end
	local value = parseDouble(number)
	if value == nil then
		self._cursor = start
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerInvalidDouble():createWithContext(self, number))
	end
	return value
end

function StringReader.readFloat(self: StringReader): number
	local start = self._cursor
	while self:canRead() and StringReader.isAllowedNumber(self:peek()) do
		self:skip()
	end
	local number = JavaString.substring(self._string, start, self._cursor)
	if number == "" then
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedFloat():createWithContext(self))
	end
	local value = parseFloat(number)
	if value == nil then
		self._cursor = start
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerInvalidFloat():createWithContext(self, number))
	end
	return value
end

function StringReader.isAllowedInUnquotedString(c: string): boolean
	return c >= "0" and c <= "9"
		or c >= "A" and c <= "Z"
		or c >= "a" and c <= "z"
		or c == "_"
		or c == "-"
		or c == "."
		or c == "+"
end

function StringReader.readUnquotedString(self: StringReader): string
	local start = self._cursor
	while self:canRead() and StringReader.isAllowedInUnquotedString(self:peek()) do
		self:skip()
	end
	return JavaString.substring(self._string, start, self._cursor)
end

function StringReader.readQuotedString(self: StringReader): string
	if not self:canRead() then
		return ""
	end
	local nextChar = self:peek()
	if not StringReader.isQuotedStringStart(nextChar) then
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedStartOfQuote():createWithContext(self))
	end
	self:skip()
	return self:readStringUntil(nextChar)
end

function StringReader.readStringUntil(self: StringReader, terminator: string): string
	local result = {}
	local escaped = false
	while self:canRead() do
		local c = self:read()
		if escaped then
			if c == terminator or c == SYNTAX_ESCAPE then
				table.insert(result, c)
				escaped = false
			else
				self:setCursor(self:getCursor() - 1)
				error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerInvalidEscape():createWithContext(self, c))
			end
		elseif c == SYNTAX_ESCAPE then
			escaped = true
		elseif c == terminator then
			return table.concat(result)
		else
			table.insert(result, c)
		end
	end

	error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedEndOfQuote():createWithContext(self))
end

function StringReader.readString(self: StringReader): string
	if not self:canRead() then
		return ""
	end
	local nextChar = self:peek()
	if StringReader.isQuotedStringStart(nextChar) then
		self:skip()
		return self:readStringUntil(nextChar)
	end
	return self:readUnquotedString()
end

function StringReader.readBoolean(self: StringReader): boolean
	local start = self._cursor
	local value = self:readString()
	if value == "" then
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedBool():createWithContext(self))
	end

	if value == "true" then
		return true
	elseif value == "false" then
		return false
	else
		self._cursor = start
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerInvalidBool():createWithContext(self, value))
	end
end

function StringReader.expect(self: StringReader, c: string)
	if not self:canRead() or self:peek() ~= c then
		error(CommandSyntaxException.BUILT_IN_EXCEPTIONS:readerExpectedSymbol():createWithContext(self, c))
	end
	self:skip()
end

return StringReader
