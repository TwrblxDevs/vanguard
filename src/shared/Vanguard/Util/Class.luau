export type Class = {
	Name: string,
	Super: Class?,
	Constructor: ((self: any, ...any) -> ())?,
	new: (...any) -> any,
	Extend: (Class, { [string]: any }) -> Class,
	IsA: (any, Class | string) -> boolean,
	[string]: any,
}

export type Definition = {
	Name: string,
	Extends: Class?,
	Constructor: ((self: any, ...any) -> ())?,
	[string]: any,
}

local Class = {}

local RESERVED_KEYS = {
	Extends = true,
	Extend = true,
	IsA = true,
	Super = true,
	new = true,
	__index = true,
	__vanguardClass = true,
}

function Class.isClass(value)
	return type(value) == "table" and rawget(value, "__vanguardClass") == true
end

local function classMatches(class, expected)
	if type(expected) == "string" then
		return class.Name == expected
	end

	return class == expected
end

function Class.isA(value, expected)
	assert(Class.isClass(expected) or type(expected) == "string", "Expected a Vanguard class or class name")

	local current = if Class.isClass(value) then value else getmetatable(value)
	while Class.isClass(current) do
		if classMatches(current, expected) then
			return true
		end

		current = current.Super
	end

	return false
end

function Class.isInstance(value, expected)
	if type(value) ~= "table" or Class.isClass(value) then
		return false
	end

	local instanceClass = getmetatable(value)
	if not Class.isClass(instanceClass) then
		return false
	end

	if expected == nil then
		return true
	end

	return Class.isA(instanceClass, expected)
end

function Class.getClass(value)
	if Class.isClass(value) then
		return value
	end

	local class = if type(value) == "table" then getmetatable(value) else nil
	return if Class.isClass(class) then class else nil
end

local function construct(class, ...)
	local chain = {}
	local current = class

	while current ~= nil do
		table.insert(chain, 1, current)
		current = current.Super
	end

	local instance = setmetatable({}, class)
	for _, chainClass in chain do
		local constructor = rawget(chainClass, "Constructor")
		if type(constructor) == "function" then
			constructor(instance, ...)
		end
	end

	return instance
end

local function instanceIsA(self, expected)
	return Class.isA(self, expected)
end

local function extend(self, definition)
	assert(Class.isClass(self), "Class:Extend must be called on a Vanguard class")
	return Class.create(definition, self)
end

function Class.create(definition: Definition, baseClass: Class?)
	assert(type(definition) == "table", `Class definition must be a table; got {type(definition)}`)
	assert(type(definition.Name) == "string" and #definition.Name > 0, "Class.Name must be a non-empty string")
	assert(definition.new == nil, "Class definitions must use Constructor instead of new")

	baseClass = baseClass or definition.Extends
	assert(baseClass == nil or Class.isClass(baseClass), "Class.Extends must be a Vanguard class or nil")
	assert(
		definition.Constructor == nil or type(definition.Constructor) == "function",
		"Class.Constructor must be a function or nil"
	)

	local class = {}
	for key, value in definition do
		if not RESERVED_KEYS[key] then
			class[key] = value
		end
	end

	if baseClass ~= nil then
		for key, value in next, baseClass do
			if
			type(key) == "string"
			and string.sub(key, 1, 2) == "__"
			and key ~= "__index"
			and key ~= "__metatable"
			and key ~= "__vanguardClass"
			and class[key] == nil
			then
				class[key] = value
			end
		end
	end

	class.Name = definition.Name
	class.Super = baseClass
	class.__index = class
	class.__vanguardClass = true
	class.IsA = instanceIsA
	class.Extend = extend
	class.new = function(...)
		return construct(class, ...)
	end

	return setmetatable(class, {
		__index = baseClass,
		__call = function(_, ...)
			return class.new(...)
		end,
		__tostring = function()
			return class.Name
		end,
	})
end

function Class.extend(baseClass: Class, definition: Definition)
	assert(Class.isClass(baseClass), "Class.extend base must be a Vanguard class")
	return Class.create(definition, baseClass)
end

return Class
