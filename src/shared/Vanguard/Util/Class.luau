export type Class = {
	Name: string,
	Super: Class?,
	Constructor: ((self: any, ...any) -> ())?,
	new: (...any) -> any,
	Extend: (Class, { [string]: any }) -> Class,
	IsA: (any, Class | string) -> boolean,
	SetStatic: (Class, string, any) -> Class,
	[string]: any,
}

export type Definition = {
	Name: string,
	Extends: Class?,
	Constructor: ((self: any, ...any) -> ())?,
	Public: { [string]: any }?,
	Private: { [string]: any }?,
	Static: { [string]: any }?,
	[string]: any,
}

local VanguardError = if script ~= nil then require(script.Parent.Error) else require("./Error")

local Class = {}

local RESERVED_KEYS = {
	Extends = true,
	Extend = true,
	IsA = true,
	Name = true,
	Private = true,
	Public = true,
	SetStatic = true,
	Static = true,
	Super = true,
	new = true,
	__index = true,
	__metatable = true,
	__vanguardClass = true,
}

local PRIVATE_DEFINITIONS = setmetatable({}, { __mode = "k" })
local PRIVATE_STATES = setmetatable({}, { __mode = "k" })
local STATIC_KEYS = setmetatable({}, { __mode = "k" })

local function classAssert(condition, code, message, level)
	return VanguardError.assert(condition, code, message, (level or 1) + 1)
end

local function cloneValue(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] ~= nil then
		return seen[value]
	end

	local clone = {}
	seen[value] = clone
	for key, childValue in value do
		clone[cloneValue(key, seen)] = cloneValue(childValue, seen)
	end

	return clone
end

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
	classAssert(
		Class.isClass(expected) or type(expected) == "string",
		"VG-CLASS-001",
		"Expected a Vanguard class or class name",
		2
	)

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

local function findInstanceMember(class, key)
	local current = class
	while current ~= nil do
		local staticKeys = STATIC_KEYS[current]
		local value = rawget(current, key)
		if value ~= nil then
			if staticKeys ~= nil and staticKeys[key] then
				return nil
			end

			return value
		end

		current = current.Super
	end

	return nil
end

local function createPrivateState(instance, ownerClass)
	local definition = PRIVATE_DEFINITIONS[ownerClass] or {}
	local private = {}

	for key, value in definition do
		if key ~= "Constructor" and type(value) ~= "function" then
			private[key] = cloneValue(value)
		end
	end

	for key, value in definition do
		if key ~= "Constructor" and type(value) == "function" then
			private[key] = function(first, ...)
				if first == private then
					return value(instance, private, ...)
				end

				return value(instance, private, first, ...)
			end
		end
	end

	return private
end

local function construct(class, ...)
	local chain = {}
	local current = class

	while current ~= nil do
		table.insert(chain, 1, current)
		current = current.Super
	end

	local instance = setmetatable({}, class)
	local statesByClass = {}
	PRIVATE_STATES[instance] = statesByClass

	for _, chainClass in chain do
		statesByClass[chainClass] = createPrivateState(instance, chainClass)
	end

	for _, chainClass in chain do
		local private = statesByClass[chainClass]
		local privateConstructor = (PRIVATE_DEFINITIONS[chainClass] or {}).Constructor
		if type(privateConstructor) == "function" then
			privateConstructor(instance, private, ...)
		end

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
	classAssert(Class.isClass(self), "VG-CLASS-001", "Class:Extend must be called on a Vanguard class", 2)
	return Class.create(definition, self)
end

local function setStatic(self, key, value)
	classAssert(Class.isClass(self), "VG-CLASS-001", "Class:SetStatic must be called on a Vanguard class", 2)
	classAssert(type(key) == "string" and #key > 0, "VG-CLASS-001", "Static member names must be non-empty strings", 2)
	classAssert(not RESERVED_KEYS[key], "VG-CLASS-002", `Static member "{key}" is reserved by Vanguard`, 2)

	STATIC_KEYS[self][key] = true
	rawset(self, key, value)
	return self
end

local function validateMemberGroup(group, label)
	classAssert(group == nil or type(group) == "table", "VG-CLASS-001", `Class.{label} must be a table or nil`, 3)

	for key in group or {} do
		classAssert(
			type(key) == "string" and #key > 0,
			"VG-CLASS-001",
			`Class.{label} member names must be non-empty strings`,
			3
		)
	end
end

local function validateMemberConflicts(definition)
	local public = definition.Public or {}
	local private = definition.Private or {}
	local static = definition.Static or {}

	for key in public do
		classAssert(not RESERVED_KEYS[key], "VG-CLASS-002", `Public member "{key}" is reserved by Vanguard`, 3)
		classAssert(private[key] == nil, "VG-CLASS-002", `Member "{key}" cannot be both public and private`, 3)
		classAssert(static[key] == nil, "VG-CLASS-002", `Member "{key}" cannot be both public and static`, 3)
		classAssert(
			definition[key] == nil,
			"VG-CLASS-002",
			`Public member "{key}" is also declared at the class definition root`,
			3
		)
	end

	for key in private do
		if key ~= "Constructor" then
			classAssert(not RESERVED_KEYS[key], "VG-CLASS-002", `Private member "{key}" is reserved by Vanguard`, 3)
		end
		classAssert(static[key] == nil, "VG-CLASS-002", `Member "{key}" cannot be both private and static`, 3)
	end

	for key in static do
		classAssert(not RESERVED_KEYS[key], "VG-CLASS-002", `Static member "{key}" is reserved by Vanguard`, 3)
		classAssert(string.sub(key, 1, 2) ~= "__", "VG-CLASS-002", "Metamethods cannot be static", 3)
		classAssert(
			definition[key] == nil,
			"VG-CLASS-002",
			`Static member "{key}" is also declared at the class definition root`,
			3
		)
	end
end

local function hasPublicMember(class, key)
	local current = class
	while current ~= nil do
		if rawget(current, key) ~= nil then
			local staticKeys = STATIC_KEYS[current]
			return staticKeys == nil or not staticKeys[key]
		end
		current = current.Super
	end

	return false
end

local function hasStaticMember(class, key)
	local current = class
	while current ~= nil do
		local staticKeys = STATIC_KEYS[current]
		if staticKeys ~= nil and staticKeys[key] then
			return true
		end
		if rawget(current, key) ~= nil then
			return false
		end
		current = current.Super
	end

	return false
end

function Class.create(definition: Definition, baseClass: Class?)
	classAssert(type(definition) == "table", "VG-CLASS-001", `Class definition must be a table; got {type(definition)}`, 2)
	classAssert(
		type(definition.Name) == "string" and #definition.Name > 0,
		"VG-CLASS-001",
		"Class.Name must be a non-empty string",
		2
	)
	classAssert(definition.new == nil, "VG-CLASS-002", "Class definitions must use Constructor instead of new", 2)

	baseClass = baseClass or definition.Extends
	classAssert(
		baseClass == nil or Class.isClass(baseClass),
		"VG-CLASS-001",
		"Class.Extends must be a Vanguard class or nil",
		2
	)
	classAssert(
		definition.Constructor == nil or type(definition.Constructor) == "function",
		"VG-CLASS-001",
		"Class.Constructor must be a function or nil",
		2
	)

	validateMemberGroup(definition.Public, "Public")
	validateMemberGroup(definition.Private, "Private")
	validateMemberGroup(definition.Static, "Static")
	validateMemberConflicts(definition)
	classAssert(
		definition.Private == nil
			or definition.Private.Constructor == nil
			or type(definition.Private.Constructor) == "function",
		"VG-CLASS-001",
		"Class.Private.Constructor must be a function or nil",
		2
	)

	if baseClass ~= nil then
		for key in definition.Public or {} do
			classAssert(
				not hasStaticMember(baseClass, key),
				"VG-CLASS-002",
				`Public member "{key}" conflicts with an inherited static member`,
				2
			)
		end
		for key in definition.Static or {} do
			classAssert(
				not hasPublicMember(baseClass, key),
				"VG-CLASS-002",
				`Static member "{key}" conflicts with an inherited public member`,
				2
			)
		end
	end

	local class = {}
	STATIC_KEYS[class] = {}
	PRIVATE_DEFINITIONS[class] = definition.Private or {}

	for key, value in definition do
		if not RESERVED_KEYS[key] then
			class[key] = value
		end
	end

	for key, value in definition.Public or {} do
		if type(value) == "function" then
			class[key] = function(self, ...)
				local statesByClass = PRIVATE_STATES[self]
				classAssert(
					statesByClass ~= nil,
					"VG-CLASS-001",
					`Public method "{key}" must be called on a {definition.Name} instance`,
					2
				)
				return value(self, statesByClass[class], ...)
			end
		else
			class[key] = value
		end
	end

	for key, value in definition.Static or {} do
		STATIC_KEYS[class][key] = true
		class[key] = value
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
	class.__index = function(_, key)
		return findInstanceMember(class, key)
	end
	class.__vanguardClass = true
	class.IsA = instanceIsA
	class.Extend = extend
	class.SetStatic = setStatic
	class.new = function(...)
		return construct(class, ...)
	end

	return setmetatable(class, {
		__index = baseClass,
		__newindex = function(_, key, value)
			STATIC_KEYS[class][key] = nil
			rawset(class, key, value)
		end,
		__call = function(_, ...)
			return class.new(...)
		end,
		__tostring = function()
			return class.Name
		end,
	})
end

function Class.extend(baseClass: Class, definition: Definition)
	classAssert(Class.isClass(baseClass), "VG-CLASS-001", "Class.extend base must be a Vanguard class", 2)
	return Class.create(definition, baseClass)
end

function Class.setStatic(class: Class, key: string, value: any): Class
	return setStatic(class, key, value)
end

return Class
