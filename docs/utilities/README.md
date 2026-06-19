# Utilities

Vanguard ships a dependency-free utility layer under `Vanguard.Util`. Utilities can be used inside or outside services, controllers, and components.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)

local Promise = require(Vanguard.Util.Promise)
```

## Utility Index

| Utility | Primary use | Guide |
| --- | --- | --- |
| `Cache` | TTL storage, LRU capacity, lazy values | [Cache](cache/README.md) |
| `Class` | Constructors and inheritance | [Classes](../classes/README.md) |
| `Cleaner` | Deterministic resource cleanup | [Cleaner](cleaner/README.md) |
| `Component` | Tagged Instance behavior | [Components](../components/README.md) |
| `Logger` | Scoped level-based output | [Logger](logger/README.md) |
| `NetworkGuard` | Standalone request guard pipeline | [NetworkGuard](network-guard/README.md) |
| `Promise` | Asynchronous composition | [Promise](promise/README.md) |
| `RateLimiter` | Per-key rolling-window limits | [RateLimiter](rate-limiter/README.md) |
| `RemoteProperty` | Server-owned replicated state | [Networking](../networking/README.md#remote-properties) |
| `RemoteSignal` | Bidirectional remote events | [Networking](../networking/README.md#remote-signals) |
| `Signal` | Local event dispatch | [Signal](signal/README.md) |
| `Validator` | Runtime payload and data schemas | [Validator](validator/README.md) |

## Framework Shortcuts

The main module provides shortcuts for common context-aware utilities:

```lua
local cache = Vanguard.CreateCache(options)
local limiter = Vanguard.CreateRateLimiter(options)
local logger = Vanguard.CreateLogger("Scope")
local class = Vanguard.CreateClass(definition)
local component = Vanguard.CreateComponent(definition)
```

The first three create utility objects. `CreateClass` and `CreateComponent` also register their results.

## Type Exports

Each utility exports its detailed types:

```lua
local Cache = require(Vanguard.Util.Cache)
type Cache = Cache.Cache
type CacheOptions = Cache.Options
```

The main Vanguard module exports shared versions of the most common types. See [Type System](../type-system/README.md).

## Cleanup Compatibility

Objects with `Destroy`, `Cleanup`, or `Disconnect` methods can be given to Cleaner. Cache and RateLimiter expose `Destroy` aliases that clear their contents. Signal destroys its BindableEvent. Components stop and detach their instances.

## Clock Injection

Cache and RateLimiter accept a custom `Clock` function. This is useful for deterministic tests:

```lua
local now = 0
local cache = Vanguard.CreateCache({
	Clock = function()
		return now
	end,
})
```

Production code normally uses the default monotonic `os.clock`.
