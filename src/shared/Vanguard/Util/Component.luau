local CollectionService = game:GetService("CollectionService")

local Cleaner = require(script.Parent.Cleaner)

type CleanerType = Cleaner.Cleaner

export type Definition = {
	Name: string?,
	Tag: string,
	Ancestor: Instance?,
	Ancestors: { Instance }?,
	Vanguard: any?,
	Logger: any?,
	Construct: ((any) -> ())?,
	Start: ((any) -> ())?,
	Stop: ((any) -> ())?,
	OnError: ((any, Instance?, string, any) -> ())?,
	[string]: any,
}

export type Component = {
	Name: string,
	Tag: string,
	Vanguard: any?,
	Logger: any?,
	Start: (Component) -> Component,
	Stop: (Component) -> (),
	Destroy: (Component) -> (),
	IsStarted: (Component) -> boolean,
	Get: (Component, instance: Instance) -> any?,
	GetAll: (Component) -> { any },
}

export type InstanceObject = {
	Instance: Instance,
	Cleaner: CleanerType,
	Component: Component,
	Vanguard: any?,
	Logger: any?,
	[string]: any,
}

local Component = {}
Component.__index = Component

local RESERVED_KEYS = {
	Name = true,
	Tag = true,
	Ancestor = true,
	Ancestors = true,
	Vanguard = true,
	Logger = true,
}

local function asArray(value)
	if value == nil then
		return nil
	end

	if typeof(value) == "Instance" then
		return { value }
	end

	assert(type(value) == "table", "Component Ancestor/Ancestors must be an Instance or array of Instances")
	return value
end

local function matchesAncestor(instance, ancestors)
	if ancestors == nil then
		return true
	end

	for _, ancestor in ancestors do
		if instance == ancestor or instance:IsDescendantOf(ancestor) then
			return true
		end
	end

	return false
end

local function safeCall(component, instanceObject, methodName)
	local method = instanceObject[methodName]
	if type(method) ~= "function" then
		return true
	end

	local ok, err = pcall(method, instanceObject)
	if not ok then
		component:_handleError(instanceObject.Instance, methodName, err)
	end

	return ok
end

function Component.new(definition, context)
	assert(type(definition) == "table", "Component definition must be a table")
	assert(type(definition.Tag) == "string" and #definition.Tag > 0, "Component.Tag must be a non-empty string")

	local name = definition.Name or definition.Tag
	assert(type(name) == "string" and #name > 0, "Component.Name must be a non-empty string when provided")

	local ancestors = asArray(definition.Ancestors or definition.Ancestor)

	return setmetatable({
		Name = name,
		Tag = definition.Tag,
		Vanguard = context,
		Logger = definition.Logger,
		_definition = definition,
		_ancestors = ancestors,
		_instances = {},
		_cleaner = Cleaner.new(),
		_started = false,
		_isVanguardComponent = true,
	}, Component)
end

function Component:IsStarted()
	return self._started
end

function Component:_handleError(instance, methodName, err)
	local errorHandler = self._definition.OnError
	if type(errorHandler) == "function" then
		errorHandler(self, instance, methodName, err)
		return
	end

	local instanceName = if instance ~= nil then instance:GetFullName() else "<unknown>"
	local message = `Component "{self.Name}" failed in {methodName} for {instanceName}: {err}`

	if self.Logger ~= nil and type(self.Logger.Warn) == "function" then
		self.Logger:Warn(message)
	else
		warn(`[Vanguard] {message}`)
	end
end

function Component:_makeInstanceObject(instance)
	local instanceObject = {}

	for key, value in self._definition do
		if not RESERVED_KEYS[key] then
			instanceObject[key] = value
		end
	end

	instanceObject.Instance = instance
	instanceObject.Cleaner = Cleaner.new()
	instanceObject.Component = self
	instanceObject.Vanguard = self.Vanguard
	instanceObject.Logger = self.Logger

	if instanceObject.Logger == nil and self.Vanguard ~= nil and type(self.Vanguard.CreateLogger) == "function" then
		instanceObject.Logger = self.Vanguard.CreateLogger(`Component.{self.Name}`)
	end

	return instanceObject
end

function Component:_attach(instance)
	if self._instances[instance] ~= nil or not matchesAncestor(instance, self._ancestors) then
		return
	end

	local instanceObject = self:_makeInstanceObject(instance)
	self._instances[instance] = instanceObject

	if not safeCall(self, instanceObject, "Construct") then
		self._instances[instance] = nil
		instanceObject.Cleaner:Cleanup()
		return
	end

	task.spawn(function()
		if self._instances[instance] == instanceObject then
			safeCall(self, instanceObject, "Start")
		end
	end)
end

function Component:_detach(instance)
	local instanceObject = self._instances[instance]
	if instanceObject == nil then
		return
	end

	self._instances[instance] = nil
	safeCall(self, instanceObject, "Stop")
	instanceObject.Cleaner:Cleanup()
end

function Component:Start()
	if self._started then
		return self
	end

	self._started = true

	for _, instance in CollectionService:GetTagged(self.Tag) do
		self:_attach(instance)
	end

	self._cleaner:Connect(CollectionService:GetInstanceAddedSignal(self.Tag), function(instance)
		self:_attach(instance)
	end)

	self._cleaner:Connect(CollectionService:GetInstanceRemovedSignal(self.Tag), function(instance)
		self:_detach(instance)
	end)

	return self
end

function Component:Stop()
	if not self._started then
		return
	end

	self._started = false
	self._cleaner:Cleanup()
	self._cleaner = Cleaner.new()

	local instances = {}
	for instance in self._instances do
		table.insert(instances, instance)
	end

	for _, instance in instances do
		self:_detach(instance)
	end
end

Component.Destroy = Component.Stop

function Component:Get(instance)
	return self._instances[instance]
end

function Component:GetAll()
	local objects = {}

	for _, instanceObject in self._instances do
		table.insert(objects, instanceObject)
	end

	return objects
end

return Component
