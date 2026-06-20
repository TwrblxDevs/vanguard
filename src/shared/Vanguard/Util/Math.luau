local VanguardError = if script ~= nil then require(script.Parent.Error) else require("./Error")

local Math = {}

Math.EPSILON = 1e-6
Math.TAU = math.pi * 2

local function expectNumber(value, label)
	VanguardError.assert(type(value) == "number", "VG-MATH-001", `{label} must be a number; got {type(value)}`, 3)
	return value
end

local function expectRange(minimum, maximum, label)
	expectNumber(minimum, `{label} minimum`)
	expectNumber(maximum, `{label} maximum`)
	VanguardError.assert(maximum > minimum, "VG-MATH-002", `{label} maximum must be greater than its minimum`, 3)
end

function Math.round(value: number, decimalPlaces: number?): number
	expectNumber(value, "value")
	decimalPlaces = decimalPlaces or 0
	expectNumber(decimalPlaces, "decimalPlaces")
	VanguardError.assert(decimalPlaces % 1 == 0, "VG-MATH-001", "decimalPlaces must be an integer", 2)

	local multiplier = 10 ^ decimalPlaces
	return math.round(value * multiplier) / multiplier
end

function Math.lerp(startValue: number, endValue: number, alpha: number): number
	expectNumber(startValue, "startValue")
	expectNumber(endValue, "endValue")
	expectNumber(alpha, "alpha")
	return startValue + (endValue - startValue) * alpha
end

function Math.inverseLerp(startValue: number, endValue: number, value: number): number
	expectRange(startValue, endValue, "inverseLerp")
	expectNumber(value, "value")
	return (value - startValue) / (endValue - startValue)
end

function Math.map(
	value: number,
	inputMinimum: number,
	inputMaximum: number,
	outputMinimum: number,
	outputMaximum: number,
	clampResult: boolean?
): number
	expectRange(inputMinimum, inputMaximum, "input")
	expectNumber(outputMinimum, "outputMinimum")
	expectNumber(outputMaximum, "outputMaximum")
	VanguardError.assert(
		clampResult == nil or type(clampResult) == "boolean",
		"VG-MATH-001",
		"clampResult must be a boolean or nil",
		2
	)

	local alpha = (expectNumber(value, "value") - inputMinimum) / (inputMaximum - inputMinimum)
	if clampResult then
		alpha = math.clamp(alpha, 0, 1)
	end

	return Math.lerp(outputMinimum, outputMaximum, alpha)
end

function Math.approximatelyEqual(left: number, right: number, epsilon: number?): boolean
	expectNumber(left, "left")
	expectNumber(right, "right")
	epsilon = epsilon or Math.EPSILON
	expectNumber(epsilon, "epsilon")
	VanguardError.assert(epsilon >= 0, "VG-MATH-001", "epsilon must be greater than or equal to zero", 2)

	return math.abs(left - right) <= epsilon * math.max(1, math.abs(left), math.abs(right))
end

function Math.wrap(value: number, minimum: number, maximum: number): number
	expectRange(minimum, maximum, "wrap")
	expectNumber(value, "value")
	return ((value - minimum) % (maximum - minimum)) + minimum
end

function Math.pingPong(value: number, length: number): number
	expectNumber(value, "value")
	expectNumber(length, "length")
	VanguardError.assert(length > 0, "VG-MATH-002", "pingPong length must be greater than zero", 2)

	local wrapped = value % (length * 2)
	return length - math.abs(wrapped - length)
end

function Math.smoothstep(minimum: number, maximum: number, value: number): number
	expectRange(minimum, maximum, "smoothstep")
	local alpha = math.clamp((expectNumber(value, "value") - minimum) / (maximum - minimum), 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

function Math.smootherstep(minimum: number, maximum: number, value: number): number
	expectRange(minimum, maximum, "smootherstep")
	local alpha = math.clamp((expectNumber(value, "value") - minimum) / (maximum - minimum), 0, 1)
	return alpha * alpha * alpha * (alpha * (alpha * 6 - 15) + 10)
end

function Math.moveTowards(current: number, target: number, maxDelta: number): number
	expectNumber(current, "current")
	expectNumber(target, "target")
	expectNumber(maxDelta, "maxDelta")
	VanguardError.assert(maxDelta >= 0, "VG-MATH-001", "maxDelta must be greater than or equal to zero", 2)

	local difference = target - current
	if math.abs(difference) <= maxDelta then
		return target
	end

	return current + math.sign(difference) * maxDelta
end

function Math.snap(value: number, increment: number): number
	expectNumber(value, "value")
	expectNumber(increment, "increment")
	VanguardError.assert(increment > 0, "VG-MATH-002", "snap increment must be greater than zero", 2)
	return math.round(value / increment) * increment
end

function Math.average(...: number): number
	local count = select("#", ...)
	VanguardError.assert(count > 0, "VG-MATH-001", "average requires at least one value", 2)

	local total = 0
	for index = 1, count do
		total += expectNumber(select(index, ...), `value #{index}`)
	end

	return total / count
end

return Math
