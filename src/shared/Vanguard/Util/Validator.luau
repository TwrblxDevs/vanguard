local VanguardError = if script ~= nil then require(script.Parent.Error) else require("./Error")

local function assert(condition, message)
	return VanguardError.assert(condition, "VG-UTIL-001", message, 3)
end

export type Validator = (value: any, path: string?) -> (boolean, string?)

export type StringOptions = {
	MinLength: number?,
	MaxLength: number?,
	Pattern: string?,
}

export type NumberOptions = {
	Min: number?,
	Max: number?,
	Finite: boolean?,
}

export type CollectionOptions = {
	MinLength: number?,
	MaxLength: number?,
}

export type ShapeOptions = {
	AllowExtra: boolean?,
}

local Validator = {}

local function valuePath(path)
	return path or "value"
end

local function childPath(path, key)
	if type(key) == "number" then
		return `{valuePath(path)}[{key}]`
	end

	return `{valuePath(path)}.{key}`
end

local function runValidator(validator, value, path)
	assert(type(validator) == "function", "Expected a validator function")

	local ok, valid, message = pcall(validator, value, path)
	if not ok then
		return false, `{valuePath(path)} validator failed: {valid}`
	end

	if valid == true then
		return true
	end

	return false, message or `{valuePath(path)} is invalid`
end

local function validateLengthOptions(options, label)
	assert(
		options.MinLength == nil or (type(options.MinLength) == "number" and options.MinLength >= 0),
		`{label} MinLength must be a non-negative number or nil`
	)
	assert(
		options.MaxLength == nil or (type(options.MaxLength) == "number" and options.MaxLength >= 0),
		`{label} MaxLength must be a non-negative number or nil`
	)
	assert(
		options.MinLength == nil or options.MaxLength == nil or options.MinLength <= options.MaxLength,
		`{label} MinLength cannot exceed MaxLength`
	)
end

function Validator.validate(validator: Validator, value, path)
	return runValidator(validator, value, path)
end

function Validator.any()
	return function()
		return true
	end
end

function Validator.type(expectedType: string)
	assert(type(expectedType) == "string" and #expectedType > 0, "Expected type must be a non-empty string")

	return function(value, path)
		if type(value) ~= expectedType then
			return false, `{valuePath(path)} must be a {expectedType}; got {type(value)}`
		end

		return true
	end
end

function Validator.robloxType(expectedType: string)
	assert(type(expectedType) == "string" and #expectedType > 0, "Expected Roblox type must be a non-empty string")

	return function(value, path)
		if typeof(value) ~= expectedType then
			return false, `{valuePath(path)} must be a {expectedType}; got {typeof(value)}`
		end

		return true
	end
end

function Validator.string(options: StringOptions?)
	options = options or {}
	assert(type(options) == "table", "String validator options must be a table or nil")
	validateLengthOptions(options, "String validator")
	assert(options.Pattern == nil or type(options.Pattern) == "string", "String Pattern must be a string or nil")

	return function(value, path)
		path = valuePath(path)
		if type(value) ~= "string" then
			return false, `{path} must be a string; got {type(value)}`
		end

		local length = #value
		if options.MinLength ~= nil and length < options.MinLength then
			return false, `{path} must contain at least {options.MinLength} characters`
		end

		if options.MaxLength ~= nil and length > options.MaxLength then
			return false, `{path} must contain at most {options.MaxLength} characters`
		end

		if options.Pattern ~= nil and string.match(value, options.Pattern) == nil then
			return false, `{path} does not match the required pattern`
		end

		return true
	end
end

function Validator.number(options: NumberOptions?)
	options = options or {}
	assert(type(options) == "table", "Number validator options must be a table or nil")
	assert(options.Min == nil or type(options.Min) == "number", "Number Min must be a number or nil")
	assert(options.Max == nil or type(options.Max) == "number", "Number Max must be a number or nil")
	assert(options.Min == nil or options.Max == nil or options.Min <= options.Max, "Number Min cannot exceed Max")
	assert(options.Finite == nil or type(options.Finite) == "boolean", "Number Finite must be a boolean or nil")

	return function(value, path)
		path = valuePath(path)
		if type(value) ~= "number" then
			return false, `{path} must be a number; got {type(value)}`
		end

		if options.Finite ~= false and (value ~= value or value == math.huge or value == -math.huge) then
			return false, `{path} must be finite`
		end

		if options.Min ~= nil and value < options.Min then
			return false, `{path} must be at least {options.Min}`
		end

		if options.Max ~= nil and value > options.Max then
			return false, `{path} must be at most {options.Max}`
		end

		return true
	end
end

function Validator.integer(options: NumberOptions?)
	local numberValidator = Validator.number(options)

	return function(value, path)
		local valid, message = numberValidator(value, path)
		if not valid then
			return false, message
		end

		if value % 1 ~= 0 then
			return false, `{valuePath(path)} must be an integer`
		end

		return true
	end
end

function Validator.boolean()
	return Validator.type("boolean")
end

function Validator.literal(expected)
	return function(value, path)
		if value ~= expected then
			return false, `{valuePath(path)} must equal {tostring(expected)}`
		end

		return true
	end
end

function Validator.optional(validator: Validator)
	assert(type(validator) == "function", "Optional value validator must be a function")

	return function(value, path)
		if value == nil then
			return true
		end

		return runValidator(validator, value, path)
	end
end

Validator.nullable = Validator.optional

function Validator.oneOf(...)
	local validators = { ... }
	assert(#validators > 0, "Validator.oneOf requires at least one validator")

	for _, validator in validators do
		assert(type(validator) == "function", "Validator.oneOf entries must be functions")
	end

	return function(value, path)
		for _, validator in validators do
			local valid = runValidator(validator, value, path)
			if valid then
				return true
			end
		end

		return false, `{valuePath(path)} did not match any allowed shape`
	end
end

function Validator.array(itemValidator: Validator, options: CollectionOptions?)
	assert(type(itemValidator) == "function", "Array item validator must be a function")
	options = options or {}
	assert(type(options) == "table", "Array validator options must be a table or nil")
	validateLengthOptions(options, "Array validator")

	return function(value, path)
		path = valuePath(path)
		if type(value) ~= "table" then
			return false, `{path} must be an array; got {type(value)}`
		end

		local length = #value
		if options.MinLength ~= nil and length < options.MinLength then
			return false, `{path} must contain at least {options.MinLength} items`
		end

		if options.MaxLength ~= nil and length > options.MaxLength then
			return false, `{path} must contain at most {options.MaxLength} items`
		end

		local keyCount = 0
		for key in value do
			keyCount += 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > length then
				return false, `{path} must only contain sequential numeric keys`
			end
		end

		if keyCount ~= length then
			return false, `{path} must not contain gaps`
		end

		for index = 1, length do
			local valid, message = runValidator(itemValidator, value[index], childPath(path, index))
			if not valid then
				return false, message
			end
		end

		return true
	end
end

function Validator.map(keyValidator: Validator, itemValidator: Validator)
	assert(type(keyValidator) == "function", "Map key validator must be a function")
	assert(type(itemValidator) == "function", "Map item validator must be a function")

	return function(value, path)
		path = valuePath(path)
		if type(value) ~= "table" then
			return false, `{path} must be a table; got {type(value)}`
		end

		for key, item in value do
			local keyValid, keyMessage = runValidator(keyValidator, key, `{path} key`)
			if not keyValid then
				return false, keyMessage
			end

			local itemValid, itemMessage = runValidator(itemValidator, item, childPath(path, key))
			if not itemValid then
				return false, itemMessage
			end
		end

		return true
	end
end

function Validator.shape(schema: { [string]: Validator }, options: ShapeOptions?)
	assert(type(schema) == "table", "Shape schema must be a table")
	options = options or {}
	assert(type(options) == "table", "Shape validator options must be a table or nil")
	assert(options.AllowExtra == nil or type(options.AllowExtra) == "boolean", "Shape AllowExtra must be a boolean or nil")

	for key, validator in schema do
		assert(type(key) == "string", "Shape schema keys must be strings")
		assert(type(validator) == "function", `Shape validator for "{key}" must be a function`)
	end

	return function(value, path)
		path = valuePath(path)
		if type(value) ~= "table" then
			return false, `{path} must be a table; got {type(value)}`
		end

		for key, validator in schema do
			local valid, message = runValidator(validator, value[key], childPath(path, key))
			if not valid then
				return false, message
			end
		end

		if not options.AllowExtra then
			for key in value do
				if schema[key] == nil then
					return false, `{childPath(path, key)} is not allowed`
				end
			end
		end

		return true
	end
end

function Validator.instance(className: string?, ancestor: Instance?)
	assert(className == nil or type(className) == "string", "Instance class name must be a string or nil")
	assert(ancestor == nil or typeof(ancestor) == "Instance", "Instance ancestor must be an Instance or nil")

	return function(value, path)
		path = valuePath(path)
		if typeof(value) ~= "Instance" then
			return false, `{path} must be an Instance; got {typeof(value)}`
		end

		if className ~= nil and not value:IsA(className) then
			return false, `{path} must be a {className}; got {value.ClassName}`
		end

		if ancestor ~= nil and value ~= ancestor and not value:IsDescendantOf(ancestor) then
			return false, `{path} must be inside {ancestor:GetFullName()}`
		end

		return true
	end
end

function Validator.custom(callback, defaultMessage: string?)
	assert(type(callback) == "function", "Custom validator callback must be a function")
	assert(defaultMessage == nil or type(defaultMessage) == "string", "Custom validator message must be a string or nil")

	return function(value, path)
		local valid, message = callback(value)
		if valid == true then
			return true
		end

		return false, message or defaultMessage or `{valuePath(path)} is invalid`
	end
end

function Validator.tuple(...)
	local validators = { ... }
	assert(#validators > 0, "Validator.tuple requires at least one validator")

	for _, validator in validators do
		assert(type(validator) == "function", "Validator.tuple entries must be functions")
	end

	return function(...)
		local argumentCount = select("#", ...)
		local arguments = { ... }

		if argumentCount > #validators then
			return false, `expected at most {#validators} arguments; got {argumentCount}`
		end

		for index, validator in validators do
			local valid, message = runValidator(validator, arguments[index], `argument {index}`)
			if not valid then
				return false, message
			end
		end

		return true
	end
end

return Validator
