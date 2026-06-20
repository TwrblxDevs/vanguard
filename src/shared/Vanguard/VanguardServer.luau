local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local rootModule = script.Parent
local Cache = require(rootModule.Util.Cache)
local Class = require(rootModule.Util.Class)
local Component = require(rootModule.Util.Component)
local VanguardError = require(rootModule.Util.Error)
local Logger = require(rootModule.Util.Logger)
local Math = require(rootModule.Util.Math)
local NetworkGuard = require(rootModule.Util.NetworkGuard)
local Promise = require(rootModule.Util.Promise)
local RateLimiter = require(rootModule.Util.RateLimiter)
local RemoteProperty = require(rootModule.Util.RemoteProperty)
local RemoteSignal = require(rootModule.Util.RemoteSignal)
local Switch = require(rootModule.Util.Switch)

VanguardError.assert(RunService:IsServer(), "VG-CORE-002", "VanguardServer can only be required from the server", 2)

local function assert(condition, message)
	return VanguardError.assert(condition, "VG-CORE-001", message, 3)
end

local function networkAssert(condition, message)
	return VanguardError.assert(condition, "VG-NET-003", message, 3)
end

local REMOTES_FOLDER_NAME = "_VanguardRemotes"
local NETWORK_PROTOCOL_ATTRIBUTE = "VanguardProtocol"
local NETWORK_VERSION_ATTRIBUTE = "VanguardVersion"
local NETWORK_PROTOCOL_VERSION = 1

local NETWORK_RULE_KEYS = {
	Authenticate = true,
	RateLimit = true,
	Validate = true,
	Verify = true,
}

local NETWORK_OPTION_KEYS = {
	Authenticate = true,
	Default = true,
	LogRejected = true,
	OnRejected = true,
	Verify = true,
}

local SIGNAL_MARKER_KIND = "VanguardSignal"
local UNRELIABLE_SIGNAL_MARKER_KIND = "VanguardUnreliableSignal"
local PROPERTY_MARKER_KIND = "VanguardProperty"

local SIGNAL_MARKER = {
	__vanguardMarker = SIGNAL_MARKER_KIND,
}

local UNRELIABLE_SIGNAL_MARKER = {
	__vanguardMarker = UNRELIABLE_SIGNAL_MARKER_KIND,
}

local defaultOptions = {
	CheckForUpdates = true,
	FreezeServices = true,
	LogLevel = "info",
	StartComponents = true,
	UpdateCheckUrl = "https://raw.githubusercontent.com/UpliftGames/wally-index/main/twrblxdevs/vanguard",
}

local VanguardServer = {}

VanguardServer.Name = "Vanguard"
VanguardServer.Version = "0.1.14"
VanguardServer.NetworkProtocol = NETWORK_PROTOCOL_VERSION
VanguardServer.Util = rootModule.Util
VanguardServer.Error = VanguardError
VanguardServer.Math = Math
VanguardServer.Switch = Switch

local services = {}
local components = {}
local classes = {}
local started = false
local startedComplete = false
local selectedOptions = table.clone(defaultOptions)
local onStartedComplete = Instance.new("BindableEvent")
local networkStats = {
	Accepted = 0,
	Rejected = 0,
	ByCode = {},
	ByRemote = {},
}
local rejectionLogCache = Cache.new({
	DefaultTTL = 5,
	MaxSize = 1000,
})

local rootLogger = Logger.new("Vanguard", selectedOptions.LogLevel)

VanguardServer.Services = services
VanguardServer.Components = components
VanguardServer.Classes = classes
VanguardServer.Logger = rootLogger

local function normalizeMethodArg(first, second)
	if first == VanguardServer then
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

local function getNetworkOptions()
	local options = selectedOptions.Network
	networkAssert(options == nil or type(options) == "table", "StartOptions.Network must be a table or nil")
	return options or {}
end

local function validateNetworkRule(rule, label)
	networkAssert(type(rule) == "table", `{label} must be a table`)
	for key in rule do
		networkAssert(NETWORK_RULE_KEYS[key] == true, `{label} contains unknown field "{tostring(key)}"`)
	end
end

local function validateNetworkOptions()
	local options = getNetworkOptions()
	for key in options do
		networkAssert(NETWORK_OPTION_KEYS[key] == true, `StartOptions.Network contains unknown field "{tostring(key)}"`)
	end

	if options.Default ~= nil then
		validateNetworkRule(options.Default, "StartOptions.Network.Default")
	end

	networkAssert(
		options.Authenticate == nil or type(options.Authenticate) == "function",
		"StartOptions.Network.Authenticate must be a function or nil"
	)
	networkAssert(options.Verify == nil or type(options.Verify) == "function", "StartOptions.Network.Verify must be a function or nil")
	networkAssert(
		options.OnRejected == nil or type(options.OnRejected) == "function",
		"StartOptions.Network.OnRejected must be a function or nil"
	)
	networkAssert(
		options.LogRejected == nil or type(options.LogRejected) == "boolean",
		"StartOptions.Network.LogRejected must be a boolean or nil"
	)
end

local function validateServiceNetwork(service)
	local serviceNetwork = service.Network
	if serviceNetwork == nil then
		return
	end

	for remoteName, rule in serviceNetwork do
		networkAssert(type(remoteName) == "string", `Service "{service.Name}" Network keys must be strings`)
		if remoteName ~= "Default" then
			networkAssert(
				remoteName ~= "Server" and service.Client[remoteName] ~= nil,
				`Service "{service.Name}" Network rule "{remoteName}" does not match a Client remote`
			)
		end

		validateNetworkRule(rule, `Service "{service.Name}" Network.{remoteName}`)
	end
end

local function getRemoteStats(context)
	local key = `{context.ServiceName}.{context.RemoteName}`
	local remoteStats = networkStats.ByRemote[key]
	if remoteStats == nil then
		remoteStats = {
			Accepted = 0,
			Rejected = 0,
		}
		networkStats.ByRemote[key] = remoteStats
	end

	return remoteStats
end

local function recordNetworkAccepted(context)
	networkStats.Accepted += 1
	local remoteStats = getRemoteStats(context)
	remoteStats.Accepted += 1
end

local function formatNetworkRejection(rejection)
	local message = `[VanguardNetwork/{rejection.Code}] {rejection.Message}`
	if rejection.RetryAfter ~= nil then
		message ..= ` (retry in {string.format("%.2f", rejection.RetryAfter)}s)`
	end

	local errorCode = VanguardError.getNetworkErrorCode(rejection.Code)
	return `{message}\nDocs: {VanguardError.getDocsUrl(errorCode)}`
end

local function handleNetworkRejection(context, rejection)
	networkStats.Rejected += 1
	local remoteStats = getRemoteStats(context)
	remoteStats.Rejected += 1
	networkStats.ByCode[rejection.Code] = (networkStats.ByCode[rejection.Code] or 0) + 1

	local options = getNetworkOptions()
	if type(options.OnRejected) == "function" then
		local callbackOk, callbackError = pcall(options.OnRejected, context, rejection)
		if not callbackOk then
			rootLogger:Error(`Network OnRejected callback failed: {callbackError}`)
		end
	end

	if options.LogRejected ~= false then
		local logKey = `{context.Player.UserId}:{context.ServiceName}:{context.RemoteName}:{rejection.Code}`
		if not rejectionLogCache:Has(logKey) then
			rejectionLogCache:Set(logKey, true)
			local detail = if rejection.Detail == nil then "" else ` ({rejection.Detail})`
			rootLogger:Warn(
				`Rejected {context.RemoteType} {context.ServiceName}.{context.RemoteName} from {context.Player.Name} ({rejection.Code}): {rejection.Message}{detail}`
			)
		end
	end

	return formatNetworkRejection(rejection)
end

local function compileRateLimit(rule)
	local rateLimit = rule.RateLimit
	if rateLimit == nil or rateLimit == false then
		return
	end

	if type(rateLimit) == "table" and type(rateLimit.Check) == "function" then
		return
	end

	networkAssert(type(rateLimit) == "table", "Network RateLimit must be RateLimiter options, a limiter, false, or nil")
	local options = table.clone(rateLimit)
	if options.WeakKeys == nil then
		options.WeakKeys = true
	end

	rule.RateLimit = RateLimiter.new(options)
end

local function createInboundGuard(service, remoteName, remoteType)
	local options = getNetworkOptions()
	local serviceNetwork = service.Network
	networkAssert(serviceNetwork == nil or type(serviceNetwork) == "table", `Service "{service.Name}" Network must be a table or nil`)
	serviceNetwork = serviceNetwork or {}

	local rule = NetworkGuard.mergeRules(options.Default, serviceNetwork.Default, serviceNetwork[remoteName])
	compileRateLimit(rule)

	local guard = NetworkGuard.new({
		Rule = rule,
		Authenticate = options.Authenticate,
		Verify = options.Verify,
	})

	return function(player, ...)
		local context = {
			Player = player,
			Service = service,
			ServiceName = service.Name,
			RemoteName = remoteName,
			RemoteType = remoteType,
			Arguments = pack(...),
		}
		local allowed, rejection = guard:Check(context, ...)
		if allowed then
			recordNetworkAccepted(context)
			return true
		end

		return false, handleNetworkRejection(context, rejection)
	end
end

local function getServicePriority(service)
	local priority = service.Priority
	if type(priority) == "number" then
		return priority
	end

	return 0
end

local function getSortedServices()
	local sortedServices = {}

	for _, service in services do
		table.insert(sortedServices, service)
	end

	table.sort(sortedServices, function(left, right)
		local leftPriority = getServicePriority(left)
		local rightPriority = getServicePriority(right)

		if leftPriority ~= rightPriority then
			return leftPriority > rightPriority
		end

		return left.Name < right.Name
	end)

	return sortedServices
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

local function parseVersion(version)
	local parts = {}

	for part in string.gmatch(tostring(version), "[^%.%-]+") do
		table.insert(parts, tonumber(part) or 0)

		if #parts == 3 then
			break
		end
	end

	while #parts < 3 do
		table.insert(parts, 0)
	end

	return parts
end

local function isVersionNewer(latestVersion, currentVersion)
	local latest = parseVersion(latestVersion)
	local current = parseVersion(currentVersion)

	for index = 1, 3 do
		if latest[index] > current[index] then
			return true
		elseif latest[index] < current[index] then
			return false
		end
	end

	return false
end

local function getPackageVersion(indexEntry)
	if type(indexEntry) ~= "table" then
		return nil
	end

	local packageInfo = indexEntry.package
	local version = if type(packageInfo) == "table" then packageInfo.version else nil

	if type(version) == "string" then
		return version
	end

	return nil
end

local function getLatestVersionFromIndex(response)
	local decodedOk, indexEntry = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if decodedOk then
		local version = getPackageVersion(indexEntry)
		if version ~= nil then
			return version
		end
	end

	local latestVersion = nil

	for line in string.gmatch(response, "[^\r\n]+") do
		if string.match(line, "%S") == nil then
			continue
		end

		local lineOk, lineEntry = pcall(function()
			return HttpService:JSONDecode(line)
		end)

		if not lineOk then
			continue
		end

		local version = getPackageVersion(lineEntry)
		if version ~= nil and (latestVersion == nil or isVersionNewer(version, latestVersion)) then
			latestVersion = version
		end
	end

	return latestVersion
end

local function warnOutdatedVersion(latestVersion)
	warn(
		`\n[VANGUARD OUTDATED]\n============================================================\nYour installed Vanguard version is out of date.\nInstalled: {VanguardServer.Version}\nLatest:    {latestVersion}\n\nUpdate your game wally.toml to:\nVanguard = "twrblxdevs/vanguard@{latestVersion}"\n\nThen run:\nwally install\n============================================================`
	)
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

local function createRemoteEvent(name, unreliable)
	local remote

	if unreliable then
		local ok, result = pcall(Instance.new, "UnreliableRemoteEvent")
		if ok then
			remote = result
		end
	end

	if remote == nil then
		remote = Instance.new("RemoteEvent")
	end

	remote.Name = name
	return remote
end

local function createPropertyFolder(name)
	local folder = Instance.new("Folder")
	folder.Name = name

	local getRemote = Instance.new("RemoteFunction")
	getRemote.Name = "_Get"
	getRemote.Parent = folder

	local changedRemote = Instance.new("RemoteEvent")
	changedRemote.Name = "_Changed"
	changedRemote.Parent = folder

	return folder
end

local function isPropertyMarker(value)
	return type(value) == "table" and value.__vanguardMarker == PROPERTY_MARKER_KIND
end

local function isSignalMarker(value)
	return value == SIGNAL_MARKER or (type(value) == "table" and value.__vanguardMarker == SIGNAL_MARKER_KIND)
end

local function isUnreliableSignalMarker(value)
	return value == UNRELIABLE_SIGNAL_MARKER
		or (type(value) == "table" and value.__vanguardMarker == UNRELIABLE_SIGNAL_MARKER_KIND)
end

local function decorateObject(object)
	if object.Logger == nil then
		object.Logger = VanguardServer.CreateLogger(object.Name)
	end
end

local function createClientCallContext(service)
	return setmetatable({}, {
		__index = function(_, key)
			if key == "Server" then
				return service
			end

			return service.Client[key]
		end,

		__newindex = function(_, key, value)
			if key == "Server" then
				VanguardError.raise("VG-CORE-001", "Service.Client.Server is read-only", nil, 2)
			end

			service.Client[key] = value
		end,
	})
end

local function checkForUpdates()
	if not selectedOptions.CheckForUpdates then
		rootLogger:Debug("Wally update check disabled")
		return
	end

	task.spawn(function()
		local ok, response = pcall(function()
			return HttpService:GetAsync(selectedOptions.UpdateCheckUrl)
		end)

		if not ok then
			rootLogger:Debug(`Wally update check failed: {response}`)
			return
		end

		local latestVersion = getLatestVersionFromIndex(response)

		if type(latestVersion) ~= "string" then
			rootLogger:Debug("Wally update check failed: registry response has no package version")
			return
		end

		if isVersionNewer(latestVersion, VanguardServer.Version) then
			warnOutdatedVersion(latestVersion)
		else
			rootLogger:Debug(`Vanguard is up to date ({VanguardServer.Version})`)
		end
	end)
end

local function buildServiceRemotes(service, remotesFolder)
	validateServiceNetwork(service)

	local serviceFolder = Instance.new("Folder")
	serviceFolder.Name = service.Name

	local hasRemoteContent = false

	for key, value in service.Client do
		if key == "Server" then
			continue
		end

		assert(type(key) == "string", `Remote key for service "{service.Name}" must be a string`)
		hasRemoteContent = true

		if type(value) == "function" then
			local inboundGuard = createInboundGuard(service, key, "Function")
			local remoteFunction = Instance.new("RemoteFunction")
			remoteFunction.Name = key
			remoteFunction.OnServerInvoke = function(player, ...)
				local allowed, rejectionMessage = inboundGuard(player, ...)
				if not allowed then
					error(rejectionMessage, 0)
				end

				local results = pack(pcall(value, createClientCallContext(service), player, ...))

				if not results[1] then
					error(results[2], 0)
				end

				return table.unpack(results, 2, results.n)
			end
			remoteFunction.Parent = serviceFolder
		elseif isSignalMarker(value) or isUnreliableSignalMarker(value) then
			local inboundGuard = createInboundGuard(service, key, "Signal")
			local remoteEvent = createRemoteEvent(key, isUnreliableSignalMarker(value))
			remoteEvent.Parent = serviceFolder
			service.Client[key] = RemoteSignal.Server.new(remoteEvent, inboundGuard)
		elseif isPropertyMarker(value) then
			local inboundGuard = createInboundGuard(service, key, "Property")
			local propertyFolder = createPropertyFolder(key)
			propertyFolder.Parent = serviceFolder
			service.Client[key] = RemoteProperty.Server.new(propertyFolder, value.InitialValue, inboundGuard)
		else
			VanguardError.raise(
				"VG-NET-003",
				`Unsupported remote value "{key}" on service "{service.Name}"`,
				nil,
				0
			)
		end
	end

	if hasRemoteContent then
		serviceFolder.Parent = remotesFolder
	else
		serviceFolder:Destroy()
	end
end

local function buildRemotes()
	validateNetworkOptions()

	local existing = rootModule:FindFirstChild(REMOTES_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local remotesFolder = Instance.new("Folder")
	remotesFolder.Name = REMOTES_FOLDER_NAME
	remotesFolder:SetAttribute(NETWORK_PROTOCOL_ATTRIBUTE, NETWORK_PROTOCOL_VERSION)
	remotesFolder:SetAttribute(NETWORK_VERSION_ATTRIBUTE, VanguardServer.Version)

	for _, service in getSortedServices() do
		buildServiceRemotes(service, remotesFolder)
	end

	return remotesFolder
end

local function runLifecycle(object, method)
	return Promise.new(function(resolve)
		if debug ~= nil and debug.setmemorycategory ~= nil then
			debug.setmemorycategory(object.Name)
		end

		local succeeded, lifecycleError = pcall(method, object)
		if not succeeded then
			VanguardError.raise(
				"VG-LIFE-001",
				`{object.Name} failed during VanguardInit`,
				lifecycleError,
				0
			)
		end
		resolve()
	end)
end

local function runServiceInitByPriority(orderedServices)
	local batches = {}
	local currentBatch = nil
	local currentPriority = nil

	for _, service in orderedServices do
		local initMethod = getLifecycleMethod(service, { "VanguardInit", "KnitInit" })
		if type(initMethod) ~= "function" then
			continue
		end

		local priority = getServicePriority(service)
		if currentBatch == nil or priority ~= currentPriority then
			currentBatch = {}
			currentPriority = priority
			table.insert(batches, currentBatch)
		end

		table.insert(currentBatch, {
			Method = initMethod,
			Service = service,
		})
	end

	local promise = Promise.resolve()

	for _, batch in batches do
		promise = promise:andThen(function()
			local initPromises = {}

			for _, entry in batch do
				rootLogger:Debug(`Initializing service {entry.Service.Name}`)
				table.insert(initPromises, runLifecycle(entry.Service, entry.Method))
			end

			return Promise.all(initPromises)
		end)
	end

	return promise
end

local function requireModules(parent, deep, registerDefinition)
	assert(typeof(parent) == "Instance", "Expected an Instance to load modules from")

	local loaded = {}

	for _, module in collectModules(parent, deep) do
		local loadedOk, value = pcall(function()
			return require(module)
		end)

		if not loadedOk then
			rootLogger:Error(VanguardError.format("VG-MODULE-001", `Failed to load module {module:GetFullName()}`, value))
			continue
		end

		if registerDefinition ~= nil then
			local registeredOk, registeredValue = pcall(registerDefinition, value)
			if not registeredOk then
				rootLogger:Error(
					VanguardError.format("VG-MODULE-001", `Failed to register module {module:GetFullName()}`, registeredValue)
				)
				continue
			end

			value = registeredValue
		end

		table.insert(loaded, value)
	end

	return loaded
end

local function registerComponentDefinition(value)
	if type(value) == "table" and value._isVanguardComponent then
		return value
	end

	if type(value) == "table" and value.Tag ~= nil then
		return VanguardServer.CreateComponent(value)
	end

	return value
end

local function registerClassDefinition(value)
	if Class.isClass(value) then
		return VanguardServer.RegisterClass(value)
	end

	if type(value) == "table" and type(value.Name) == "string" then
		return VanguardServer.CreateClass(value)
	end

	return value
end

local function registerServiceDefinition(value)
	if type(value) ~= "table" or type(value.Name) ~= "string" then
		return value
	end

	local registeredService = services[value.Name]
	if registeredService == value then
		return value
	end

	if registeredService ~= nil then
		VanguardError.raise("VG-REG-001", `Service "{value.Name}" already exists`, nil, 2)
	end

	return VanguardServer.CreateService(value)
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

function VanguardServer.Configure(options, methodOptions)
	assert(not started, "Vanguard.Configure() must be called before Vanguard.Start()")
	options = normalizeMethodArg(options, methodOptions)
	return configure(options)
end

function VanguardServer.GetConfig()
	return table.clone(selectedOptions)
end

function VanguardServer.GetNetworkInfo()
	return {
		Protocol = NETWORK_PROTOCOL_VERSION,
		ServerVersion = VanguardServer.Version,
	}
end

function VanguardServer.GetNetworkStats()
	local byCode = table.clone(networkStats.ByCode)
	local byRemote = {}
	for remoteName, remoteStats in networkStats.ByRemote do
		byRemote[remoteName] = table.clone(remoteStats)
	end

	return {
		Accepted = networkStats.Accepted,
		Rejected = networkStats.Rejected,
		ByCode = byCode,
		ByRemote = byRemote,
	}
end

function VanguardServer.ResetNetworkStats()
	networkStats.Accepted = 0
	networkStats.Rejected = 0
	table.clear(networkStats.ByCode)
	table.clear(networkStats.ByRemote)
end

function VanguardServer.CheckForUpdates()
	checkForUpdates()
end

function VanguardServer.CreateLogger(scope, methodScope)
	scope = normalizeMethodArg(scope, methodScope)
	return Logger.new(scope or "Vanguard", selectedOptions.LogLevel)
end

function VanguardServer.CreateCache(options, methodOptions)
	options = normalizeMethodArg(options, methodOptions)
	return Cache.new(options)
end

function VanguardServer.CreateRateLimiter(options, methodOptions)
	options = normalizeMethodArg(options, methodOptions)
	return RateLimiter.new(options)
end

function VanguardServer.CreateClass(classDef, methodClassDef)
	classDef = normalizeMethodArg(classDef, methodClassDef)

	if Class.isClass(classDef) then
		return VanguardServer.RegisterClass(classDef)
	end

	VanguardError.assert(
		type(classDef) == "table",
		"VG-CLASS-001",
		`Class definition must be a table; got {type(classDef)}`,
		2
	)

	if type(classDef.Extends) == "string" then
		local resolvedDefinition = table.clone(classDef)
		resolvedDefinition.Extends = VanguardServer.GetClass(classDef.Extends)
		classDef = resolvedDefinition
	end

	return VanguardServer.RegisterClass(Class.create(classDef))
end

function VanguardServer.RegisterClass(class, methodClass)
	class = normalizeMethodArg(class, methodClass)

	VanguardError.assert(
		Class.isClass(class),
		"VG-CLASS-001",
		"RegisterClass expects a class created by Vanguard.Util.Class",
		2
	)

	local registeredClass = classes[class.Name]
	if registeredClass == class then
		return class
	end

	VanguardError.assert(registeredClass == nil, "VG-REG-001", `Class "{class.Name}" already exists`, 2)
	classes[class.Name] = class
	return class
end

function VanguardServer.AddClasses(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)
	return requireModules(parent, false, registerClassDefinition)
end

function VanguardServer.AddClassesDeep(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)
	return requireModules(parent, true, registerClassDefinition)
end

VanguardServer.LoadClasses = VanguardServer.AddClasses
VanguardServer.LoadClassesDeep = VanguardServer.AddClassesDeep

function VanguardServer.GetClass(className, methodClassName)
	className = normalizeMethodArg(className, methodClassName)
	if Class.isClass(className) then
		className = className.Name
	end

	assert(type(className) == "string", `Class name must be a string; got {type(className)}`)
	return VanguardError.assert(classes[className], "VG-REG-002", `Could not find class "{className}"`, 2)
end

function VanguardServer.HasClass(className, methodClassName)
	className = normalizeMethodArg(className, methodClassName)
	if Class.isClass(className) then
		className = className.Name
	end

	return type(className) == "string" and classes[className] ~= nil
end

function VanguardServer.GetClasses()
	return table.clone(classes)
end

function VanguardServer.UnregisterClass(className, methodClassName)
	className = normalizeMethodArg(className, methodClassName)
	if Class.isClass(className) then
		className = className.Name
	end

	assert(type(className) == "string", `Class name must be a string; got {type(className)}`)
	local class = classes[className]
	classes[className] = nil
	return class
end

function VanguardServer.CreateService(serviceDef, methodServiceDef)
	serviceDef = normalizeMethodArg(serviceDef, methodServiceDef)

	assert(type(serviceDef) == "table", `Service must be a table; got {type(serviceDef)}`)
	assert(type(serviceDef.Name) == "string", `Service.Name must be a string; got {type(serviceDef.Name)}`)
	assert(#serviceDef.Name > 0, "Service.Name must be a non-empty string")
	assert(
		serviceDef.Priority == nil or type(serviceDef.Priority) == "number",
		`Service.Priority must be a number if provided; got {type(serviceDef.Priority)}`
	)
	assert(serviceDef.Network == nil or type(serviceDef.Network) == "table", "Service.Network must be a table or nil")
	VanguardError.assert(services[serviceDef.Name] == nil, "VG-REG-001", `Service "{serviceDef.Name}" already exists`, 2)
	VanguardError.assert(not started, "VG-LIFE-001", "Services cannot be created after Vanguard.Start()", 2)

	local service = serviceDef

	if type(service.Client) ~= "table" then
		service.Client = {}
	end

	if service.Client.Server == service then
		service.Client.Server = nil
	end

	decorateObject(service)
	services[service.Name] = service

	return service
end

function VanguardServer.AddServices(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)

	assert(not started, "Services cannot be added after Vanguard.Start()")
	return requireModules(parent, false, registerServiceDefinition)
end

function VanguardServer.AddServicesDeep(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)

	assert(not started, "Services cannot be added after Vanguard.Start()")
	return requireModules(parent, true, registerServiceDefinition)
end

VanguardServer.LoadServices = VanguardServer.AddServices
VanguardServer.LoadServicesDeep = VanguardServer.AddServicesDeep

function VanguardServer.GetService(serviceName, methodServiceName)
	serviceName = normalizeMethodArg(serviceName, methodServiceName)
	if type(serviceName) == "table" and type(serviceName.Name) == "string" then
		serviceName = serviceName.Name
	end

	assert(started, "Cannot call GetService until Vanguard.Start() has been called")
	assert(type(serviceName) == "string", `Service name must be a string; got {type(serviceName)}`)

	local service = services[serviceName]
	if service ~= nil then
		return service
	end

	local registeredNames = getObjectNames(getSortedObjects(services))
	if registeredNames == "" then
		VanguardError.raise("VG-REG-002", `Could not find service "{serviceName}" (no services registered)`, nil, 2)
	end

	VanguardError.raise(
		"VG-REG-002",
		`Could not find service "{serviceName}" (registered services: {registeredNames})`,
		nil,
		2
	)
end

function VanguardServer.GetServices()
	assert(started, "Cannot call GetServices until Vanguard.Start() has been called")
	return services
end

function VanguardServer.CreateComponent(componentDef, methodComponentDef)
	componentDef = normalizeMethodArg(componentDef, methodComponentDef)

	local component = if type(componentDef) == "table" and componentDef._isVanguardComponent
		then componentDef
		else Component.new(componentDef, VanguardServer)

	VanguardError.assert(components[component.Name] == nil, "VG-REG-001", `Component "{component.Name}" already exists`, 2)

	component.Vanguard = VanguardServer
	if component.Logger == nil then
		component.Logger = VanguardServer.CreateLogger(`Component.{component.Name}`)
	end

	components[component.Name] = component

	if started and selectedOptions.StartComponents then
		component:Start()
	end

	return component
end

function VanguardServer.AddComponents(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)
	return requireModules(parent, false, registerComponentDefinition)
end

function VanguardServer.AddComponentsDeep(parent, methodParent)
	parent = normalizeMethodArg(parent, methodParent)
	return requireModules(parent, true, registerComponentDefinition)
end

VanguardServer.LoadComponents = VanguardServer.AddComponents
VanguardServer.LoadComponentsDeep = VanguardServer.AddComponentsDeep

function VanguardServer.GetComponent(componentName, methodComponentName)
	componentName = normalizeMethodArg(componentName, methodComponentName)
	if type(componentName) == "table" and type(componentName.Name) == "string" then
		componentName = componentName.Name
	end

	assert(type(componentName) == "string", `Component name must be a string; got {type(componentName)}`)
	return VanguardError.assert(components[componentName], "VG-REG-002", `Could not find component "{componentName}"`, 2)
end

function VanguardServer.GetComponents()
	return components
end

function VanguardServer.CreateSignal()
	return SIGNAL_MARKER
end

function VanguardServer.CreateUnreliableSignal()
	return UNRELIABLE_SIGNAL_MARKER
end

function VanguardServer.CreateProperty(initialValue, methodInitialValue)
	initialValue = normalizeMethodArg(initialValue, methodInitialValue)

	return {
		__vanguardMarker = PROPERTY_MARKER_KIND,
		InitialValue = initialValue,
	}
end

function VanguardServer.Start(options, methodOptions)
	options = normalizeMethodArg(options, methodOptions)

	if started then
		return Promise.reject(VanguardError.format("VG-LIFE-001", "Vanguard already started"))
	end

	configure(options)
	started = true

	local remotesFolder = buildRemotes()
	local startTime = os.clock()

	if selectedOptions.FreezeServices and table.freeze ~= nil then
		table.freeze(services)
	end

	local orderedServices = getSortedServices()
	local orderedComponents = getSortedObjects(components)

	rootLogger:Info(
		`Starting server v{VanguardServer.Version} ({formatCount(#orderedServices, "service")}, {formatCount(
			#orderedComponents,
			"component"
		)})`
	)

	if #orderedServices > 0 then
		rootLogger:Debug(`Services: {getObjectNames(orderedServices)}`)
	end

	if #orderedComponents > 0 then
		rootLogger:Debug(`Components: {getObjectNames(orderedComponents)}`)
	end

	return runServiceInitByPriority(orderedServices):andThen(function()
		rootLogger:Debug("Service initialization complete")

		for _, service in orderedServices do
			local startMethod = getLifecycleMethod(service, { "VanguardStart", "KnitStart" })
			if type(startMethod) == "function" then
				rootLogger:Debug(`Starting service {service.Name}`)
				task.spawn(function()
					if debug ~= nil and debug.setmemorycategory ~= nil then
						debug.setmemorycategory(service.Name)
					end

					local succeeded, startError = pcall(startMethod, service)
					if not succeeded then
						rootLogger:Error(
							VanguardError.format("VG-LIFE-001", `{service.Name} failed during VanguardStart`, startError)
						)
					end
				end)
			end
		end

		remotesFolder.Parent = rootModule
		startComponents()

		startedComplete = true
		onStartedComplete:Fire()

		rootLogger:Info(`Server startup complete in {math.floor((os.clock() - startTime) * 1000)}ms`)
		checkForUpdates()

		task.defer(function()
			onStartedComplete:Destroy()
		end)
	end)
end

function VanguardServer.OnStart()
	if startedComplete then
		return Promise.resolve()
	end

	return Promise.fromEvent(onStartedComplete.Event)
end

function VanguardServer.IsStarted()
	return startedComplete
end

function VanguardServer.Bootstrap(configOrServicesParent, options, methodOptions)
	if configOrServicesParent == VanguardServer then
		configOrServicesParent = options
		options = methodOptions
	end

	if typeof(configOrServicesParent) == "Instance" then
		VanguardServer.AddServicesDeep(configOrServicesParent)
	elseif type(configOrServicesParent) == "table" then
		if configOrServicesParent.Classes ~= nil then
			VanguardServer.AddClassesDeep(configOrServicesParent.Classes)
		end

		if configOrServicesParent.Services ~= nil then
			VanguardServer.AddServicesDeep(configOrServicesParent.Services)
		end

		if configOrServicesParent.Components ~= nil then
			VanguardServer.AddComponentsDeep(configOrServicesParent.Components)
		end

		options = configOrServicesParent.Options or options
	end

	return VanguardServer.Start(options)
end

return VanguardServer
