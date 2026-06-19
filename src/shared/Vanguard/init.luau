local RunService = game:GetService("RunService")

export type LogLevel = "trace" | "debug" | "info" | "warn" | "error" | "silent" | number

export type Promise = {
	andThen: (Promise, ((...any) -> any)?, ((...any) -> any)?) -> Promise,
	catch: (Promise, (...any) -> any) -> Promise,
	finally: (Promise, () -> any) -> Promise,
	await: (Promise) -> (boolean, ...any),
}

export type Logger = {
	SetLevel: (Logger, LogLevel?) -> (),
	GetLevel: (Logger) -> number,
	IsEnabled: (Logger, LogLevel?) -> boolean,
	ForScope: (Logger, scope: string) -> Logger,
	Trace: (Logger, ...any) -> (),
	Debug: (Logger, ...any) -> (),
	Info: (Logger, ...any) -> (),
	Warn: (Logger, ...any) -> (),
	Error: (Logger, ...any) -> (),
	trace: (Logger, ...any) -> (),
	debug: (Logger, ...any) -> (),
	info: (Logger, ...any) -> (),
	warn: (Logger, ...any) -> (),
	error: (Logger, ...any) -> (),
}

export type Signal = {
	Connect: (Signal, callback: (...any) -> ()) -> RBXScriptConnection,
	Once: (Signal, callback: (...any) -> ()) -> RBXScriptConnection,
	Fire: (Signal, ...any) -> (),
	Wait: (Signal) -> ...any,
	Destroy: (Signal) -> (),
}

export type CleanerTask = RBXScriptConnection | Instance | (() -> ()) | {
	Destroy: ((any) -> ())?,
	Cleanup: ((any) -> ())?,
	Disconnect: ((any) -> ())?,
}

export type Cleaner = {
	Add: <T>(Cleaner, taskItem: T) -> T,
	GiveTask: <T>(Cleaner, taskItem: T) -> T,
	Connect: (Cleaner, signal: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	GivePromise: (Cleaner, promise: any) -> (),
	Cleanup: (Cleaner) -> (),
	Destroy: (Cleaner) -> (),
}

export type CacheOptions = {
	DefaultTTL: number?,
	MaxSize: number?,
	Clock: (() -> number)?,
}

export type Cache = {
	Set: (Cache, key: any, value: any, ttl: number?) -> any,
	Get: (Cache, key: any) -> (any, boolean),
	Peek: (Cache, key: any) -> (any, boolean),
	Has: (Cache, key: any) -> boolean,
	GetOrSet: (Cache, key: any, producer: (any) -> any, ttl: number?) -> (any, boolean),
	Remove: (Cache, key: any) -> (any, boolean),
	Prune: (Cache) -> number,
	Clear: (Cache) -> (),
	Count: (Cache) -> number,
	Keys: (Cache) -> { any },
	Destroy: (Cache) -> (),
}

export type Class = {
	Name: string,
	Super: Class?,
	Constructor: ((self: any, ...any) -> ())?,
	new: (...any) -> any,
	Extend: (Class, { [string]: any }) -> Class,
	IsA: (any, Class | string) -> boolean,
	[string]: any,
}

export type ClassDefinition = {
	Name: string,
	Extends: Class | string?,
	Constructor: ((self: any, ...any) -> ())?,
	[string]: any,
}

export type RateLimiterOptions = {
	Limit: number,
	Window: number,
	Clock: (() -> number)?,
	WeakKeys: boolean?,
}

export type RateLimiter = {
	Check: (RateLimiter, key: any?, cost: number?) -> (boolean, number),
	Allow: (RateLimiter, key: any?, cost: number?) -> (boolean, number),
	GetRemaining: (RateLimiter, key: any?) -> (number, number),
	Reset: (RateLimiter, key: any?) -> (),
	Prune: (RateLimiter) -> number,
	Clear: (RateLimiter) -> (),
	Destroy: (RateLimiter) -> (),
}

export type Validator = (value: any, path: string?) -> (boolean, string?)

export type NetworkContext = {
	Player: Player,
	Service: any,
	ServiceName: string,
	RemoteName: string,
	RemoteType: "Function" | "Signal" | "Property",
	Arguments: { any } & { n: number },
}

export type NetworkRejection = {
	Code: "RATE_LIMITED" | "INVALID_PAYLOAD" | "UNAUTHENTICATED" | "UNVERIFIED" | "GUARD_ERROR" | string,
	Message: string,
	Stage: string,
	RetryAfter: number?,
	Detail: any?,
}

export type NetworkRule = {
	Validate: ((...any) -> (boolean, string?)) | false?,
	Authenticate: ((player: Player, context: NetworkContext) -> (boolean, string?)) | false?,
	Verify: ((player: Player, context: NetworkContext, ...any) -> (boolean, string?)) | false?,
	RateLimit: RateLimiterOptions | RateLimiter | false?,
}

export type NetworkOptions = {
	Default: NetworkRule?,
	Authenticate: ((player: Player, context: NetworkContext) -> (boolean, string?))?,
	Verify: ((player: Player, context: NetworkContext, ...any) -> (boolean, string?))?,
	OnRejected: ((context: NetworkContext, rejection: NetworkRejection) -> ())?,
	LogRejected: boolean?,
}

export type ServiceNetworkRules = {
	Default: NetworkRule?,
	[string]: NetworkRule?,
}

export type NetworkStats = {
	Accepted: number,
	Rejected: number,
	ByCode: { [string]: number },
	ByRemote: { [string]: { Accepted: number, Rejected: number } },
}

export type NetworkInfo = {
	Protocol: number?,
	ServerVersion: string?,
}

export type RemoteSignal = {
	Connect: (RemoteSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	Once: (RemoteSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	Wait: (RemoteSignal) -> ...any,
	Fire: (RemoteSignal, ...any) -> (),
	FireFor: ((RemoteSignal, player: Player, ...any) -> ())?,
	FireAll: ((RemoteSignal, ...any) -> ())?,
	FireExcept: ((RemoteSignal, excludedPlayer: Player, ...any) -> ())?,
	FireWhere: ((RemoteSignal, predicate: (Player) -> boolean, ...any) -> ())?,
	Destroy: (RemoteSignal) -> (),
}

export type RemoteProperty = {
	Get: (RemoteProperty, ...any) -> any,
	Set: ((RemoteProperty, value: any) -> ())?,
	SetFor: ((RemoteProperty, player: Player, value: any) -> ())?,
	ClearFor: ((RemoteProperty, player: Player) -> ())?,
	Observe: (RemoteProperty, callback: (any) -> ()) -> () -> (),
	Destroy: (RemoteProperty) -> (),
}

export type StartOptions = {
	CheckForUpdates: boolean?,
	FreezeServices: boolean?,
	FreezeControllers: boolean?,
	LogLevel: LogLevel?,
	Network: NetworkOptions?,
	RemoteTimeout: number?,
	ServicePromises: boolean?,
	StartComponents: boolean?,
	UpdateCheckUrl: string?,
}

export type ServiceDefinition = {
	Name: string,
	Client: { [string]: any }?,
	Logger: Logger?,
	Network: ServiceNetworkRules?,
	Priority: number?,
	[string]: any,
}

export type Service = ServiceDefinition
export type ServiceWith<T> = ServiceDefinition & T

export type ControllerDefinition = {
	Name: string,
	Logger: Logger?,
	[string]: any,
}

export type Controller = ControllerDefinition
export type ControllerWith<T> = ControllerDefinition & T

export type ComponentDefinition = {
	Name: string?,
	Tag: string,
	Ancestor: Instance?,
	Ancestors: { Instance }?,
	Logger: Logger?,
	Construct: ((any) -> ())?,
	Start: ((any) -> ())?,
	Stop: ((any) -> ())?,
	OnError: ((any, Instance?, string, any) -> ())?,
	[string]: any,
}

export type Component = {
	Name: string,
	Tag: string,
	Logger: Logger?,
	Vanguard: any?,
	Start: (Component) -> Component,
	Stop: (Component) -> (),
	Destroy: (Component) -> (),
	IsStarted: (Component) -> boolean,
	Get: (Component, instance: Instance) -> any?,
	GetAll: (Component) -> { any },
}

export type ComponentWith<T> = Component & T

export type ComponentInstance = {
	Instance: Instance,
	Cleaner: Cleaner,
	Component: Component,
	Vanguard: any?,
	Logger: Logger?,
	[string]: any,
}

export type BootstrapConfig = {
	Services: Instance?,
	Controllers: Instance?,
	Components: Instance?,
	Classes: Instance?,
	Options: StartOptions?,
}

export type UtilContainer = Instance & {
	Cache: ModuleScript,
	Class: ModuleScript,
	Cleaner: ModuleScript,
	Component: ModuleScript,
	Logger: ModuleScript,
	NetworkGuard: ModuleScript,
	Promise: ModuleScript,
	RateLimiter: ModuleScript,
	RemoteProperty: ModuleScript,
	RemoteSignal: ModuleScript,
	Signal: ModuleScript,
	Validator: ModuleScript,
}

export type Vanguard = {
	Name: string,
	Version: string,
	NetworkProtocol: number,
	Player: Player?,
	Util: UtilContainer,
	Services: { [string]: ServiceDefinition }?,
	Controllers: { [string]: ControllerDefinition }?,
	Components: { [string]: Component },
	Classes: { [string]: Class },
	Logger: Logger,

	Configure: ((options: StartOptions?) -> StartOptions) & ((self: any, options: StartOptions?) -> StartOptions),
	GetConfig: (() -> StartOptions) & ((self: any) -> StartOptions),
	GetNetworkInfo: (() -> NetworkInfo) & ((self: any) -> NetworkInfo),
	GetNetworkStats: ((() -> NetworkStats) & ((self: any) -> NetworkStats))?,
	ResetNetworkStats: ((() -> ()) & ((self: any) -> ()))?,
	CheckForUpdates: ((() -> ()) & ((self: any) -> ()))?,
	CreateLogger: ((scope: string?) -> Logger) & ((self: any, scope: string?) -> Logger),
	CreateCache: ((options: CacheOptions?) -> Cache) & ((self: any, options: CacheOptions?) -> Cache),
	CreateRateLimiter: ((options: RateLimiterOptions) -> RateLimiter) & ((self: any, options: RateLimiterOptions) -> RateLimiter),

	CreateClass: (<T>(classDef: T) -> Class & T) & (<T>(self: any, classDef: T) -> Class & T),
	RegisterClass: (<T>(class: T) -> T) & (<T>(self: any, class: T) -> T),
	AddClasses: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	AddClassesDeep: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	LoadClasses: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	LoadClassesDeep: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	GetClass: ((className: string | Class) -> Class) & ((self: any, className: string | Class) -> Class),
	HasClass: ((className: string | Class) -> boolean) & ((self: any, className: string | Class) -> boolean),
	GetClasses: (() -> { [string]: Class }) & ((self: any) -> { [string]: Class }),
	UnregisterClass: ((className: string | Class) -> Class?) & ((self: any, className: string | Class) -> Class?),

	CreateService: (<T>(serviceDef: T) -> T) & (<T>(self: any, serviceDef: T) -> T),
	AddServices: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	AddServicesDeep: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	LoadServices: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	LoadServicesDeep: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	GetService: ((serviceName: string | { Name: string }) -> any) & ((self: any, serviceName: string | { Name: string }) -> any),
	GetServices: (() -> { [string]: ServiceDefinition }) & ((self: any) -> { [string]: ServiceDefinition }),

	CreateController: (<T>(controllerDef: T) -> T) & (<T>(self: any, controllerDef: T) -> T),
	AddControllers: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	AddControllersDeep: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	LoadControllers: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	LoadControllersDeep: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	GetController: ((controllerName: string | { Name: string }) -> any) & ((self: any, controllerName: string | { Name: string }) -> any),
	GetControllers: (() -> { [string]: ControllerDefinition }) & ((self: any) -> { [string]: ControllerDefinition }),

	CreateComponent: ((componentDef: ComponentDefinition | Component) -> Component) & ((self: any, componentDef: ComponentDefinition | Component) -> Component),
	AddComponents: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	AddComponentsDeep: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	LoadComponents: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	LoadComponentsDeep: ((parent: Instance) -> { any }) & ((self: any, parent: Instance) -> { any }),
	GetComponent: ((componentName: string | { Name: string }) -> Component) & ((self: any, componentName: string | { Name: string }) -> Component),
	GetComponents: (() -> { [string]: Component }) & ((self: any) -> { [string]: Component }),

	CreateSignal: (() -> RemoteSignal) & ((self: any) -> RemoteSignal),
	CreateUnreliableSignal: (() -> RemoteSignal) & ((self: any) -> RemoteSignal),
	CreateProperty: ((initialValue: any?) -> RemoteProperty) & ((self: any, initialValue: any?) -> RemoteProperty),

	Start: ((options: StartOptions?) -> Promise) & ((self: any, options: StartOptions?) -> Promise),
	Bootstrap: ((configOrParent: Instance | BootstrapConfig | nil, options: StartOptions?) -> Promise) & ((self: any, configOrParent: Instance | BootstrapConfig | nil, options: StartOptions?) -> Promise),
	OnStart: (() -> Promise) & ((self: any) -> Promise),
	IsStarted: (() -> boolean) & ((self: any) -> boolean),
}

if RunService:IsServer() then
	local server = require(script.VanguardServer)
	return server :: Vanguard
end

local serverModule = script:FindFirstChild("VanguardServer")
if serverModule ~= nil and RunService:IsRunning() then
	serverModule:Destroy()
end

local client = require(script.VanguardClient)
return client :: Vanguard
