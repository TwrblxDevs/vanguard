local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

assert(RunService:IsClient(), "VanguardClient can only be required from the client")

local rootModule = script.Parent
local Cache = require(rootModule.Util.Cache)
local Class = require(rootModule.Util.Class)
local Component = require(rootModule.Util.Component)
local Logger = require(rootModule.Util.Logger)
local Promise = require(rootModule.Util.Promise)
local RateLimiter = require(rootModule.Util.RateLimiter)
local RemoteProperty = require(rootModule.Util.RemoteProperty)
local RemoteSignal = require(rootModule.Util.RemoteSignal)

local REMOTES_FOLDER_NAME = "_VanguardRemotes"
local NETWORK_PROTOCOL_ATTRIBUTE = "VanguardProtocol"
local NETWORK_VERSION_ATTRIBUTE = "VanguardVersion"
local NETWORK_PROTOCOL_VERSION = 1

local defaultOptions = {
	FreezeControllers = true,
	LogLevel = "info",
	RemoteTimeout = 15,
	ServicePromises = true,
	StartComponents = true,
}

local VanguardClient = {}

VanguardClient.Name = "Vanguard"
VanguardClient.Version = "0.1.13"
VanguardClient.NetworkProtocol = NETWORK_PROTOCOL_VERSION
VanguardClient.Player = Players.LocalPlayer
VanguardClient.Util = rootModule.Util

local controllers = {}
local components = {}
local classes = {}
local services = {}
local remotesFolder = nil
local networkInfo = {
	Protocol = nil,
	ServerVersion = nil,
}
local selectedOptions = table.clone(defaultOptions)
local started = false
local startedComplete = false
local onStartedComplete = Instance.new("BindableEvent")

local rootLogger = Logger.new("Vanguard", selectedOptions.LogLevel)

VanguardClient.Controllers = controllers
VanguardClient.Components = components
VanguardClient.Classes = classes
VanguardClient.Logger = rootLogger

local function normalizeMethodArg(first, second)
	if first == VanguardClient then
		return second
	end

	return first
end

local function pack(...)
	return {
		n = select("#", ...),
		...,
	}
end

local function mergeOptions(base, options)
	local merged = table.clone(base)

	if options ~= nil then
		assert(type(options) == "table", `Start options must be a table or nil; got {type(options)}`)
		for key, value in options do
			merged[key] = value
		end
	end

	return merged
end

local function configure(options)
	selectedOptions = mergeOptions(selectedOptions, options)
	rootLogger:SetLevel(selectedOptions.LogLevel)
	return selectedOptions
end

local function getLifecycleMethod(object, names)
	for _, methodName in names do
		local method = object[methodName]
		if type(method) == "function" then
			return method
		end
	end

	return nil
end

local function getSortedObjects(source)
	local objects = {}

	for _, object in source do
		table.insert(objects, object)
	end

	table.sort(objects, function(left, right)
		return left.Name < right.Name
	end)

	return objects
end

local function getObjectNames(objects)
	local names = table.create(#objects)

	for index, object in objects do
		names[index] = object.Name
	end

	return table.concat(names, ", ")
end

local function formatCount(count, singular)
	local suffix = if count == 1 then "" else "s"
	return `{count} {singular}{suffix}`
end

local function collectModules(parent, deep)
	local instances = if deep then parent:GetDescendants() else parent:GetChildren()
	local modules = {}

	for _, instance in instances do
		if instance:IsA("ModuleScript") then
			table.insert(modules, instance)
		end
	end

	table.sort(modules, function(left, right)
		return left:GetFullName() < right:GetFullName()
	end)

	return modules
end

local function requireModules(parent, deep, registerDefinition)
	assert(typeof(parent) == "Instance", "Expected an Instance to load modules from")

	local loaded = {}

	for _, module in collectModules(parent, deep) do
		local loadedOk, value = pcall(function()
			return require(module)
		end)

		if not loadedOk then
			rootLogger:Error(`Failed to load module {module:GetFullName()}: {value}`)
			continue
		end

		if registerDefinition ~= nil then
			local registeredOk, registeredValue = pcall(registerDefinition, value)
			if not registeredOk then
				rootLogger:Error(`Failed to register module {module:GetFullName()}: {registeredValue}`)
				continue
			end

			value = registeredValue
		end

		table.insert(loaded, value)
	end

	return loaded
end

local function getRemotesFolder()
	if remotesFolder ~= nil then
		return remotesFolder
	end

	remotesFolder = rootModule:WaitForChild(REMOTES_FOLDER_NAME, selectedOptions.RemoteTimeout)
	assert(remotesFolder ~= nil, `Timed out waiting for {REMOTES_FOLDER_NAME}. Did the server call Vanguard.Start()?`)

	local protocol = remotesFolder:GetAttribute(NETWORK_PROTOCOL_ATTRIBUTE)
	local serverVersion = remotesFolder:GetAttribute(NETWORK_VERSION_ATTRIBUTE)
	networkInfo.Protocol = protocol
	networkInfo.ServerVersion = serverVersion

	assert(
		protocol == NETWORK_PROTOCOL_VERSION,
		`Vanguard network protocol mismatch (client {NETWORK_PROTOCOL_VERSION}, server {tostring(protocol)})`
	)

	if type(serverVersion) == "string" and serverVersion ~= VanguardClient.Version then
		rootLogger:Warn(`Vanguard version mismatch (client {VanguardClient.Version}, server {serverVersion})`)
	end

	return remotesFolder
end

local function isRemoteEvent(instance)
	return instance:IsA("RemoteEvent") or instance.ClassName == "UnreliableRemoteEvent"
end

local function invokeRemote(remoteFunction, args, startIndex)
	return remoteFunction:InvokeServer(table.unpack(args, startIndex, args.n))
end

local function createRemoteMethod(service, remoteFunction)
	return function(...)
		local args = pack(...)
		local startIndex = if args.n > 0 and args[1] == service then 2 else 1

		if selectedOptions.ServicePromises then
			return Promise.new(function(resolve, reject)
				local results = pack(pcall(function()
					return invokeRemote(remoteFunction, args, startIndex)
				end))

				if results[1] then
					resolve(table.unpack(results, 2, results.n))
				else
					reject(results[2])
				end
			end)
		end

		return invokeRemote(remoteFunction, args, startIndex)
	end
end

local function isPropertyFolder(instance)
	return instance:IsA("Folder")
		and instance:FindFirstChild("_Get") ~= nil
		and instance:FindFirstChild("_Changed") ~= nil
end

local function buildService(serviceName)
	local folder = getRemotesFolder()
	local serviceFolder = folder:WaitForChild(serviceName, selectedOptions.RemoteTimeout)
	assert(serviceFolder ~= nil, `Could not find remote service "{serviceName}"`)

	local service = {
		Name = serviceName,
	}

	for _, child in serviceFolder:GetChildren() do
		if child:IsA("RemoteFunction") then
			service[child.Name] = createRemoteMethod(service, child)
		elseif isRemoteEvent(child) then
			service[child.Name] = RemoteSignal.Client.new(child)
		elseif isPropertyFolder(child) then
			service[child.Name] = RemoteProperty.Client.new(child)
		end
	end

	services[serviceName] = service
	return service
end

local function runLifecycle(object, method)
	return Promise.new(function(resolve)
		if debug ~= nil and debug.setmemorycategory ~= nil then
			debug.setmemorycategory(object.Name)
		end

		method(object)
		resolve()
	end)
end

local function decorateObject(object)
	if object.Logger == nil then
		object.Logger = VanguardClient.CreateLogger(object.Name)
	end
end

local function registerComponentDefinition(value)
	if type(value) == "table" and value._isVanguardComponent then
		return value
	end

	if type(value) == "table" and value.Tag ~= nil then
		return VanguardClient.CreateComponent(value)
	end

	return value
end

local function registerClassDefinition(value)
	if Class.isClass(value) then
		return VanguardClient.RegisterClass(value)
	end

	if type(value) == "table" and type(value.Name) == "string" then
		return VanguardClient.CreateClass(value)
	end

	return value
end

local function registerControllerDefinition(value)
	if type(value) ~= "table" or type(value.Name) ~= "string" then
		return value
	end

	local registeredController = controllers[value.Name]
	if registeredController == value then
		return value
	end

	if registeredController ~= nil then
		error(`Controller "{value.Name}" already exists`, 2)
	end

	return VanguardClient.CreateController(value)
end

local function startComponents()
	local orderedComponents = getSortedObjects(components)

	if not selectedOptions.StartComponents then
		rootLogger:Debug(`Component startup skipped ({#orderedComponents} registered)`)
		return
	end

	for _, component in orderedComponents do
		rootLogger:Debug(`Starting component {component.Name}`)
		component:Start()
	end

	if #orderedComponents > 0 then
		rootLogger:Info(`Started {formatCount(#orderedComponents, "component")}`)
	end
end

function VanguardClient.Configure(options, methodOptions)
	assert(not started, "Vanguard.Configure() must be called before Vanguard.Start()")
	options = normalizeMethodArg(options, methodOptions)
	return configure(options)
end

function VanguardClient.GetConfig()
	return table.clone(selectedOptions)
end

function VanguardClient.GetNetworkInfo()
	return table.clone(networkInfo)
end

function VanguardClient.CreateLogger(scope, methodScope)
	scope = normalizeMethodArg(scope, methodScope)
	return Logger.new(scope or "Vanguard", selectedOptions.LogLevel)
end

function VanguardClient.CreateCache(options, methodOptions)
	options = normalizeMethodArg(options, methodOptions)
	return Cache.new(options)
end

function VanguardClient.CreateRateLimiter(options, methodOptions)
	options = normalizeMethodArg(options, methodOptions)
	return RateLimiter.new(options)
end

function VanguardClient.CreateClass(classDef, methodClassDef)
	classDef = normalizeMethodArg(classDef, methodClassDef)

	if Class.isClass(classDef) then
		return VanguardClient.RegisterClass(classDef)
	end

	assert(type(classDef) == "table", `Class definition must be a table; got {type(classDef)}`)

	if type(classDef.Extends) == "string" then
		local resolvedDefinition = table.clone(classDef)
		resolvedDefinition.Extends = VanguardClient.GetClass(classDef.Extends)
		classDef = resolvedDefinition
	end

	return VanguardClient.RegisterClass(Class.create(classDef))
end

function VanguardClient.RegisterClass(class, methodClass)
	class = normalizeMethodArg(class, methodClass)

	assert(Class.isClass(class), "RegisterClass expects a class created by Vanguard.Util.Class")

	local registeredClass = classes[class.Name]
	if registeredClass == class then
		return class
	end

	assert(registeredClass == nil, `Class "{class.Name}" already exists`)
	classes[class.Name] = class
	return class
end

function VanguardClient.AddClasses(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)
	return requireModules(parent, false, registerClassDefinition)
end

function VanguardClient.AddClassesDeep(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)
	return requireModules(parent, true, registerClassDefinition)
end

VanguardClient.LoadClasses = VanguardClient.AddClasses
VanguardClient.LoadClassesDeep = VanguardClient.AddClassesDeep

function VanguardClient.GetClass(className, methodClassName)
	className = normalizeMethodArg(className, methodClassName)
	if Class.isClass(className) then
		className = className.Name
	end

	assert(type(className) == "string", `Class name must be a string; got {type(className)}`)
	return assert(classes[className], `Could not find class "{className}"`)
end

function VanguardClient.HasClass(className, methodClassName)
	className = normalizeMethodArg(className, methodClassName)
	if Class.isClass(className) then
		className = className.Name
	end

	return type(className) == "string" and classes[className] ~= nil
end

function VanguardClient.GetClasses()
	return table.clone(classes)
end

function VanguardClient.UnregisterClass(className, methodClassName)
	className = normalizeMethodArg(className, methodClassName)
	if Class.isClass(className) then
		className = className.Name
	end

	assert(type(className) == "string", `Class name must be a string; got {type(className)}`)
	local class = classes[className]
	classes[className] = nil
	return class
end

function VanguardClient.CreateController(controllerDef, methodControllerDef)
	controllerDef = normalizeMethodArg(controllerDef, methodControllerDef)

	assert(type(controllerDef) == "table", `Controller must be a table; got {type(controllerDef)}`)
	assert(type(controllerDef.Name) == "string", `Controller.Name must be a string; got {type(controllerDef.Name)}`)
	assert(#controllerDef.Name > 0, "Controller.Name must be a non-empty string")
	assert(controllers[controllerDef.Name] == nil, `Controller "{controllerDef.Name}" already exists`)
	assert(not started, "Controllers cannot be created after Vanguard.Start()")

	local controller = controllerDef
	decorateObject(controller)
	controllers[controller.Name] = controller

	return controller
end

function VanguardClient.AddControllers(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)

	assert(not started, "Controllers cannot be added after Vanguard.Start()")
	return requireModules(parent, false, registerControllerDefinition)
end

function VanguardClient.AddControllersDeep(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)

	assert(not started, "Controllers cannot be added after Vanguard.Start()")
	return requireModules(parent, true, registerControllerDefinition)
end

VanguardClient.LoadControllers = VanguardClient.AddControllers
VanguardClient.LoadControllersDeep = VanguardClient.AddControllersDeep

function VanguardClient.GetService(serviceName, methodServiceName)
	serviceName = normalizeMethodArg(serviceName, methodServiceName)
	if type(serviceName) == "table" and type(serviceName.Name) == "string" then
		serviceName = serviceName.Name
	end

	local service = services[serviceName]
	if service ~= nil then
		return service
	end

	assert(started, "Cannot call GetService until Vanguard.Start() has been called")
	assert(type(serviceName) == "string", `Service name must be a string; got {type(serviceName)}`)

	return buildService(serviceName)
end

function VanguardClient.GetController(controllerName, methodControllerName)
	controllerName = normalizeMethodArg(controllerName, methodControllerName)
	if type(controllerName) == "table" and type(controllerName.Name) == "string" then
		controllerName = controllerName.Name
	end

	local controller = controllers[controllerName]
	if controller ~= nil then
		return controller
	end

	assert(started, "Cannot call GetController until Vanguard.Start() has been called")
	assert(type(controllerName) == "string", `Controller name must be a string; got {type(controllerName)}`)

	local registeredNames = getObjectNames(getSortedObjects(controllers))
	if registeredNames == "" then
		error(`Could not find controller "{controllerName}" (no controllers registered)`, 2)
	end

	error(`Could not find controller "{controllerName}" (registered controllers: {registeredNames})`, 2)
end

function VanguardClient.GetControllers()
	assert(started, "Cannot call GetControllers until Vanguard.Start() has been called")
	return controllers
end

function VanguardClient.CreateComponent(componentDef, methodComponentDef)
	componentDef = normalizeMethodArg(componentDef, methodComponentDef)

	local component = if type(componentDef) == "table" and componentDef._isVanguardComponent
		then componentDef
		else Component.new(componentDef, VanguardClient)

	assert(components[component.Name] == nil, `Component "{component.Name}" already exists`)

	component.Vanguard = VanguardClient
	if component.Logger == nil then
		component.Logger = VanguardClient.CreateLogger(`Component.{component.Name}`)
	end

	components[component.Name] = component

	if started and selectedOptions.StartComponents then
		component:Start()
	end

	return component
end

function VanguardClient.AddComponents(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)
	return requireModules(parent, false, registerComponentDefinition)
end

function VanguardClient.AddComponentsDeep(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)
	return requireModules(parent, true, registerComponentDefinition)
end

VanguardClient.LoadComponents = VanguardClient.AddComponents
VanguardClient.LoadComponentsDeep = VanguardClient.AddComponentsDeep

function VanguardClient.GetComponent(componentName, methodComponentName)
	componentName = normalizeMethodArg(componentName, methodComponentName)
	if type(componentName) == "table" and type(componentName.Name) == "string" then
		componentName = componentName.Name
	end

	assert(type(componentName) == "string", `Component name must be a string; got {type(componentName)}`)
	return assert(components[componentName], `Could not find component "{componentName}"`)
end

function VanguardClient.GetComponents()
	return components
end

function VanguardClient.Start(options, methodOptions)
	options = normalizeMethodArg(options, methodOptions)

	if started then
		return Promise.reject("Vanguard already started")
	end

	configure(options)
	started = true
	local startTime = os.clock()

	if selectedOptions.FreezeControllers and table.freeze ~= nil then
		table.freeze(controllers)
	end

	local orderedControllers = getSortedObjects(controllers)
	local orderedComponents = getSortedObjects(components)

	rootLogger:Info(
		`Starting client v{VanguardClient.Version} ({formatCount(#orderedControllers, "controller")}, {formatCount(#orderedComponents, "component")})`
	)

	if #orderedControllers > 0 then
		rootLogger:Debug(`Controllers: {getObjectNames(orderedControllers)}`)
	end

	if #orderedComponents > 0 then
		rootLogger:Debug(`Components: {getObjectNames(orderedComponents)}`)
	end

	return Promise.new(function(resolve)
		local initPromises = {}

		for _, controller in orderedControllers do
			local initMethod = getLifecycleMethod(controller, { "VanguardInit", "KnitInit" })
			if type(initMethod) == "function" then
				rootLogger:Debug(`Initializing controller {controller.Name}`)
				table.insert(initPromises, runLifecycle(controller, initMethod))
			end
		end

		resolve(Promise.all(initPromises))
	end):andThen(function()
		rootLogger:Debug("Controller initialization complete")

		for _, controller in orderedControllers do
			local startMethod = getLifecycleMethod(controller, { "VanguardStart", "KnitStart" })
			if type(startMethod) == "function" then
				rootLogger:Debug(`Starting controller {controller.Name}`)
				task.spawn(function()
					if debug ~= nil and debug.setmemorycategory ~= nil then
						debug.setmemorycategory(controller.Name)
					end

					startMethod(controller)
				end)
			end
		end

		startComponents()

		startedComplete = true
		onStartedComplete:Fire()

		rootLogger:Info(`Client startup complete in {math.floor((os.clock() - startTime) * 1000)}ms`)

		task.defer(function()
			onStartedComplete:Destroy()
		end)
	end)
end

function VanguardClient.OnStart()
	if startedComplete then
		return Promise.resolve()
	end

	return Promise.fromEvent(onStartedComplete.Event)
end

function VanguardClient.IsStarted()
	return startedComplete
end

function VanguardClient.Bootstrap(configOrControllersParent, options, methodOptions)
	if configOrControllersParent == VanguardClient then
		configOrControllersParent = options
		options = methodOptions
	end

	if typeof(configOrControllersParent) == "Instance" then
		VanguardClient.AddControllersDeep(configOrControllersParent)
	elseif type(configOrControllersParent) == "table" then
		if configOrControllersParent.Classes ~= nil then
			VanguardClient.AddClassesDeep(configOrControllersParent.Classes)
		end

		if configOrControllersParent.Controllers ~= nil then
			VanguardClient.AddControllersDeep(configOrControllersParent.Controllers)
		end

		if configOrControllersParent.Components ~= nil then
			VanguardClient.AddComponentsDeep(configOrControllersParent.Components)
		end

		options = configOrControllersParent.Options or options
	end

	return VanguardClient.Start(options)
end

return VanguardClient
