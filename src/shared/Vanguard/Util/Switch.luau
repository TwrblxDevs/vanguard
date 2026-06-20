export type Switch = {
	Case: (Switch, expected: any, result: any) -> Switch,
	Cases: (Switch, expectedValues: { any }, result: any) -> Switch,
	Default: (Switch, result: any) -> Switch,
	HasMatch: (Switch) -> boolean,
	Run: (Switch, ...any) -> ...any,
}

local VanguardError = if script ~= nil then require(script.Parent.Error) else require("./Error")

local Switch = {}
local SwitchBuilder = {}
SwitchBuilder.__index = SwitchBuilder

local function evaluate(result, value, ...)
	if type(result) == "function" then
		return result(value, ...)
	end

	return result
end

local function valuesMatch(left, right)
	return left == right
end

function Switch.new(value): Switch
	return setmetatable({
		_value = value,
		_cases = {},
		_default = nil,
		_hasDefault = false,
	}, SwitchBuilder) :: any
end

function SwitchBuilder:Case(expected, result)
	table.insert(self._cases, {
		Values = { expected },
		Result = result,
	})
	return self
end

function SwitchBuilder:Cases(expectedValues, result)
	VanguardError.assert(type(expectedValues) == "table", "VG-SWITCH-001", "Switch:Cases expects an array", 2)
	VanguardError.assert(#expectedValues > 0, "VG-SWITCH-001", "Switch:Cases expects at least one value", 2)

	local values = table.create(#expectedValues)
	for index, expected in expectedValues do
		values[index] = expected
	end

	table.insert(self._cases, {
		Values = values,
		Result = result,
	})
	return self
end

function SwitchBuilder:Default(result)
	self._default = result
	self._hasDefault = true
	return self
end

function SwitchBuilder:HasMatch(): boolean
	for _, caseDefinition in self._cases do
		for _, expected in caseDefinition.Values do
			if valuesMatch(self._value, expected) then
				return true
			end
		end
	end

	return false
end

function SwitchBuilder:Run(...)
	for _, caseDefinition in self._cases do
		for _, expected in caseDefinition.Values do
			if valuesMatch(self._value, expected) then
				return evaluate(caseDefinition.Result, self._value, ...)
			end
		end
	end

	if self._hasDefault then
		return evaluate(self._default, self._value, ...)
	end

	return nil
end

function Switch.match(value, cases, defaultResult, ...)
	VanguardError.assert(type(cases) == "table", "VG-SWITCH-001", "Switch.match cases must be a table", 2)

	local result = rawget(cases, value)
	if result ~= nil then
		return evaluate(result, value, ...)
	end

	return evaluate(defaultResult, value, ...)
end

return Switch
