--!strict

-- The JDK constants the tests use. Long.MAX_VALUE (2^63 - 1) has no exact double, so it is 2^63,
-- the double Java would round it to.

return {
	Integer = {
		MIN_VALUE = -2147483648,
		MAX_VALUE = 2147483647,
	},
	Long = {
		MIN_VALUE = -2 ^ 63,
		MAX_VALUE = 2 ^ 63,
	},
	Float = {
		MAX_VALUE = 3.4028234663852886e38,
		MIN_VALUE = 1.401298464324817e-45,
	},
	Double = {
		MAX_VALUE = 1.7976931348623157e308,
		MIN_VALUE = 4.9e-324,
	},
}
