--!strict

-- List.sort: a stable merge sort with a Java comparator. table.sort isn't stable, and Brigadier relies
-- on equal elements keeping their order.

local Sort = {}

local function merge<T>(list: { T }, buffer: { T }, low: number, middle: number, high: number, compare: (T, T) -> number)
	for index = low, high do
		buffer[index] = list[index]
	end
	local left, right = low, middle + 1
	for index = low, high do
		-- Ties take from the left run, which keeps equal elements in order.
		if left <= middle and (right > high or compare(buffer[right], buffer[left]) >= 0) then
			list[index] = buffer[left]
			left += 1
		else
			list[index] = buffer[right]
			right += 1
		end
	end
end

local function sortRange<T>(list: { T }, buffer: { T }, low: number, high: number, compare: (T, T) -> number)
	if low >= high then
		return
	end
	local middle = (low + high) // 2
	sortRange(list, buffer, low, middle, compare)
	sortRange(list, buffer, middle + 1, high, compare)
	merge(list, buffer, low, middle, high, compare)
end

function Sort.sort<T>(list: { T }, compare: (T, T) -> number)
	sortRange(list, {}, 1, #list, compare)
end

-- String.compareTo: the difference of the first bytes that differ, or of the lengths.
function Sort.compareStrings(a: string, b: string): number
	local length = math.min(#a, #b)
	for index = 1, length do
		local x, y = string.byte(a, index), string.byte(b, index)
		if x ~= y then
			return x - y
		end
	end
	return #a - #b
end

return Sort
