# Vanguard

Vanguard is a dependency-free Roblox application framework packaged for Wally. It keeps the best parts of Knit: server services, client controllers, lifecycle hooks, and declarative remotes, then adds framework-grade pieces like network validation and authentication, tagged components, registered classes, caching, rate limiting, scoped logging, centralized config, and cleaner bootstrapping.

## Documentation

The complete documentation lives at [twrblxdevs.github.io/vanguard-docs](https://twrblxdevs.github.io/vanguard-docs/).

- [Getting Started](https://twrblxdevs.github.io/vanguard-docs/getting-started/)
- [Lifecycle](https://twrblxdevs.github.io/vanguard-docs/lifecycle/)
- [Services](https://twrblxdevs.github.io/vanguard-docs/services/), [Controllers](https://twrblxdevs.github.io/vanguard-docs/controllers/), [Components](https://twrblxdevs.github.io/vanguard-docs/components/), and [Classes](https://twrblxdevs.github.io/vanguard-docs/classes/)
- [Networking](https://twrblxdevs.github.io/vanguard-docs/networking/) and [Network Security](https://twrblxdevs.github.io/vanguard-docs/network-security/)
- [Errors](https://twrblxdevs.github.io/vanguard-docs/errors/) and the complete [Utilities index](https://twrblxdevs.github.io/vanguard-docs/utilities/)
- [API Reference](https://twrblxdevs.github.io/vanguard-docs/api-reference/), [Type System](https://twrblxdevs.github.io/vanguard-docs/type-system/), and [Troubleshooting](https://twrblxdevs.github.io/vanguard-docs/troubleshooting/)
- [Roadmap](https://twrblxdevs.github.io/vanguard-docs/roadmap/) for upcoming platform, tooling, and community work
- [Contributing](https://twrblxdevs.github.io/vanguard-docs/contributing/) for setup, commit conventions, testing, and pull request expectations

## Install

Add Vanguard to a game's `wally.toml`:

```toml
[dependencies]
Vanguard = "twrblxdevs/vanguard@0.1.14"
```

Install packages:

```bash
wally install
```

Map Wally packages into your Rojo project:

```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Packages": {
        "$path": "Packages"
      }
    }
  }
}
```

Require Vanguard:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)
```

For best Studio autocomplete, prefer the direct package path above. `WaitForChild` returns a generic `Instance`, which can make Luau show `*error-type*` unless you add extra type casts.

If you need `WaitForChild`, keep the static type from the direct path:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vanguard = require(Packages:WaitForChild("Vanguard") :: ModuleScript) :: typeof(require(ReplicatedStorage.Packages.Vanguard))
```

## Types

Vanguard exports Luau types from the main module:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)

type Vanguard = Vanguard.Vanguard
type StartOptions = Vanguard.StartOptions
type Service = Vanguard.Service
type Controller = Vanguard.Controller
type Component = Vanguard.Component
type Class = Vanguard.Class
type Cache = Vanguard.Cache
type VanguardError = Vanguard.VanguardError
type MathUtil = Vanguard.MathUtil
type RateLimiter = Vanguard.RateLimiter
type NetworkRule = Vanguard.NetworkRule
type NetworkContext = Vanguard.NetworkContext
type NetworkRejection = Vanguard.NetworkRejection
type Logger = Vanguard.Logger
type Promise = Vanguard.Promise
type RemoteSignal = Vanguard.RemoteSignal
type RemoteProperty = Vanguard.RemoteProperty
type Switch = Vanguard.Switch
```

For service/controller-specific shapes, intersect your own fields with Vanguard's base types:

```lua
type InventoryService = Vanguard.Service & {
	Client: {
		InventoryChanged: Vanguard.RemoteSignal,
		GetItems: (self: any, player: Player) -> { string },
	},

	GetItems: (self: any, player: Player) -> { string },
}
```

Utility modules export types too:

```lua
local Promise = require(Vanguard.Util.Promise)
local Cleaner = require(Vanguard.Util.Cleaner)

type Promise = Promise.Promise
type Cleaner = Cleaner.Cleaner
```

## Layout

This repository is package-only now:

```text
src
  shared
    Vanguard
      init.luau
      VanguardServer.luau
      VanguardClient.luau
      Util
```

`default.project.json` intentionally points directly at `src/shared/Vanguard` so Wally publishes a single module package.

## Bootstrapping

Server:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)

Vanguard.Bootstrap({
	Services = script.Parent.Services,
	Components = script.Parent.Components,
	Classes = script.Parent.Classes,
	Options = {
		LogLevel = "info",
	},
}):catch(warn)
```

Client:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)

Vanguard.Bootstrap({
	Controllers = script.Parent.Controllers,
	Components = script.Parent.Components,
	Classes = script.Parent.Classes,
	Options = {
		LogLevel = "info",
	},
}):catch(warn)
```

You can also load and start manually with `AddServicesDeep`, `AddControllersDeep`, `AddComponentsDeep`, and `Start`. Public Vanguard methods support both dot and colon syntax, so `Vanguard.GetService("InventoryService")` and `Vanguard:GetService("InventoryService")` both work.

Services and controllers receive a scoped `Logger` automatically. Vanguard does not inject the full framework table into services, controllers, or client service proxies, so `GetService` and `GetServices` stay focused on your registered services.

## Startup Logs

Vanguard logs startup by default at `info` level:

```text
[Vanguard] [INFO] Starting server v0.1.14 (3 services, 2 components)
[Vanguard] [INFO] Server startup complete in 12ms
[Vanguard] [INFO] Starting client v0.1.14 (4 controllers, 1 component)
[Vanguard] [INFO] Client startup complete in 8ms
```

Use `debug` for individual services/controllers/components:

```lua
Vanguard.Start({
	LogLevel = "debug",
})
```

Use `warn` or `silent` to reduce framework output.

## Update Checks

On the server, Vanguard checks the Wally index after startup and warns if a newer published version exists:

```text
[VANGUARD OUTDATED]
============================================================
Your installed Vanguard version is out of date.
Installed: 0.1.13
Latest:    0.1.14
...
============================================================
```

The check is non-blocking and only logs at `debug` level if HTTP is unavailable, disabled in Studio, or the registry cannot be reached. Wally index files contain one JSON entry per published version, and Vanguard picks the highest version from that list. Make sure `HttpService` is enabled in the game if you want version warnings.

Disable the check:

```lua
Vanguard.Start({
	CheckForUpdates = false,
})
```

Use a custom package index URL:

```lua
Vanguard.Start({
	UpdateCheckUrl = "https://raw.githubusercontent.com/UpliftGames/wally-index/main/twrblxdevs/vanguard",
})
```

## Services

Services run on the server. Anything in the `Client` table becomes available to clients. Service modules can either call `Vanguard.CreateService(...)` or return a plain service table; `AddServices` and `AddServicesDeep` register returned tables automatically.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)

local InventoryService = Vanguard.CreateService({
	Name = "InventoryService",
	Priority = 0,

	Client = {
		InventoryChanged = Vanguard.CreateSignal(),
	},
})

function InventoryService.Client:GetItems(player)
	return self.Server:GetItems(player)
end

function InventoryService:GetItems(player)
	return {}
end

function InventoryService:VanguardStart()
	self.Logger:Info("Ready")
end

return InventoryService
```

Lifecycle hooks:

```lua
function Service:VanguardInit()
	-- Runs after all services are registered.
end

function Service:VanguardStart()
	-- Runs after every VanguardInit finishes.
end
```

`KnitInit` and `KnitStart` are supported for migration.

Services can set `Priority` to control startup order. Higher numbers initialize first and have their start hooks scheduled first; services with the same priority keep the default alphabetical ordering. `VanguardInit` waits for each priority batch before moving to the next lower priority.

`self.Server` inside `Client` methods is provided only while that remote method is running, so your printed service table will not contain a circular `Client.Server` reference.

## Controllers

Controllers run on the client. Controller modules can either call `Vanguard.CreateController(...)` or return a plain controller table; `AddControllers` and `AddControllersDeep` register returned tables automatically.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)

local InventoryController = Vanguard.CreateController({
	Name = "InventoryController",
})

function InventoryController:VanguardStart()
	local InventoryService = Vanguard.GetService("InventoryService")

	InventoryService:GetItems():andThen(function(items)
		self.Items = items
	end):catch(function(err)
		self.Logger:Warn(err)
	end)
end

return InventoryController
```

Client service methods return promises by default. Use yielding calls instead with:

```lua
Vanguard.Start({
	ServicePromises = false,
})
```

## Components

Components attach behavior to instances tagged with CollectionService. They work on server and client.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)

return Vanguard.CreateComponent({
	Name = "TaggedButton",
	Tag = "VanguardButton",

	Construct = function(self)
		if not self.Instance:IsA("GuiButton") then
			return
		end

		self.Cleaner:Connect(self.Instance.Activated, function()
			self.Logger:Info(`Activated {self.Instance:GetFullName()}`)
		end)
	end,
})
```

Component instance objects receive `Instance`, `Cleaner`, `Component`, `Vanguard`, and `Logger`.

## Classes

Vanguard classes have constructors, inheritance, callable class tables, and runtime `IsA` checks. `CreateClass` registers the class in the current server or client runtime.

```lua
local Entity = Vanguard.CreateClass({
	Name = "Entity",

	Constructor = function(self, id)
		self.Id = id
	end,
})

function Entity:GetId()
	return self.Id
end

local PlayerEntity = Vanguard.CreateClass({
	Name = "PlayerEntity",
	Extends = Entity,

	Constructor = function(self, _id, player)
		self.Player = player
	end,
})

local entity = PlayerEntity("player-1", game.Players.SomePlayer)
print(entity:GetId(), entity:IsA(Entity), entity:IsA("PlayerEntity"))
print(Vanguard.GetClass("PlayerEntity") == PlayerEntity)
```

Base constructors run before child constructors with the same arguments. Use `Vanguard.RegisterClass(Vanguard.Util.Class.create(...))` for externally-created classes. Class modules can return either a class or a plain class definition and be loaded with `AddClasses`, `AddClassesDeep`, or the `Classes` bootstrap field. Classes may be registered and unregistered after startup because they do not participate in lifecycle ordering.

Classes can also separate public instance members, per-instance private state, and class-only static members:

```lua
local Wallet
Wallet = Vanguard.CreateClass({
	Name = "Wallet",

	Private = {
		Balance = 0,
		Constructor = function(_self, private, openingBalance)
			private.Balance = openingBalance
		end,
	},

	Public = {
		GetBalance = function(_self, private)
			return private.Balance
		end,
	},

	Static = {
		Currency = "Credits",
		Open = function(openingBalance)
			return Wallet(openingBalance)
		end,
	},
})

local wallet = Wallet.Open(100)
print(wallet:GetBalance()) -- 100
print(wallet.Balance) -- nil
print(Wallet.Currency) -- Credits
print(wallet.Currency) -- nil
```

Grouped public functions receive their owning class's private state as the second argument. Private defaults are cloned per instance, private methods are callable only through that injected state, and inherited public methods retain access to the base class's private state. Legacy top-level methods continue to use the original `(self, ...)` signature.

## Documented Errors

Framework-owned failures now include a stable code and a direct documentation link:

```text
[Vanguard VG-NET-001] Vanguard network protocol mismatch (client 1, server 2)
Docs: https://twrblxdevs.github.io/vanguard-docs/errors/#vg-net-001
```

Use `Vanguard.Error` or `Vanguard.Util.Error` to create the same structured errors in game code:

```lua
local message = Vanguard.Error.format("VG-CORE-001", "Inventory configuration is invalid")
warn(message)
```

Network rejection names such as `INVALID_PAYLOAD` and `UNAUTHENTICATED` remain stable and now link to their corresponding error entry.

## Remotes

`Vanguard.CreateSignal()` creates a reliable two-way remote event.

Server methods: `:Fire(player, ...)`, `:FireAll(...)`, `:FireExcept(player, ...)`, `:FireWhere(predicate, ...)`, `:Connect(function(player, ...) end)`.

Client methods: `:Fire(...)`, `:Connect(function(...) end)`.

`Vanguard.CreateUnreliableSignal()` uses `UnreliableRemoteEvent` when available and falls back to `RemoteEvent`.

`Vanguard.CreateProperty(initialValue)` creates a server-owned replicated value.

Server methods: `:Set(value)`, `:SetFor(player, value)`, `:ClearFor(player)`, `:Get(player)`, `:Observe(callback)`.

Client methods: `:Get()`, `:Observe(callback)`.

Remote property methods support both colon and dot calls, so `Property:Set(true)` and `Property.Set(true)` both work.

## Network Security

Every client-to-server remote function, signal, and property read passes through Vanguard's network guard. Rules can rate-limit requests, validate payload shape, authenticate the player, and verify whether that player may perform the requested action.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vanguard = require(ReplicatedStorage.Packages.Vanguard)
local Validator = require(Vanguard.Util.Validator)

local PurchaseService = Vanguard.CreateService({
	Name = "PurchaseService",

	Client = {
		Purchase = function(self, player, itemId, amount)
			return self.Server:Purchase(player, itemId, amount)
		end,
		PurchaseRequested = Vanguard.CreateSignal(),
	},

	Network = {
		Default = {
			RateLimit = {
				Limit = 30,
				Window = 1,
			},
		},

		Purchase = {
			Validate = Validator.tuple(
				Validator.string({ MinLength = 1, MaxLength = 64 }),
				Validator.integer({ Min = 1, Max = 10 })
			),
			Authenticate = function(player, context)
				return ProfileManager:IsLoaded(player), "Profile is not ready"
			end,
			Verify = function(player, context, itemId, amount)
				return Catalog:CanPurchase(player, itemId, amount), "Purchase is not permitted"
			end,
			RateLimit = {
				Limit = 5,
				Window = 2,
			},
		},
	},
})
```

Rules use the remote's `Client` key, so the same configuration works for functions, signals, and properties. A remote rule inherits `Network.Default`. Set an inherited field to `false`, such as `RateLimit = false`, to disable that field for one remote.

The server evaluates inbound requests in this order:

1. `RateLimit` limits each player independently.
2. `Validate(...)` checks only client-supplied arguments.
3. `Authenticate(player, context)` verifies server-owned session or identity state.
4. `Verify(player, context, ...)` authorizes the specific action and resources.

Configure authentication across every service at startup:

```lua
Vanguard.Start({
	Network = {
		Authenticate = function(player, context)
			return not BanService:IsBanned(player), "Access denied"
		end,
		OnRejected = function(context, rejection)
			SecurityMetrics:Record(context.Player, context.RemoteName, rejection.Code)
		end,
		LogRejected = true,
	},
})
```

Global authentication and verification cannot be bypassed by a service rule. Rejected remote functions and property reads return errors such as `[VanguardNetwork/INVALID_PAYLOAD]`; rejected signals are dropped before service listeners run. Rejection logs are throttled per player, remote, and code.

Vanguard also stamps the remote container with its network protocol and server package version. Clients reject incompatible protocols before building service proxies and warn on package-version mismatches.

Protocol `1` defines the `_VanguardRemotes` folder, service folders, `RemoteFunction` method transport, reliable or unreliable signal transport, remote-property `_Get` and `_Changed` children, server-supplied Player identity, guard ordering, and client compatibility handshake. Package `0.1.14` retains protocol `1` because it changes diagnostics and local helpers without changing those wire contracts.

```lua
local info = Vanguard.GetNetworkInfo()

-- Server only:
local stats = Vanguard.GetNetworkStats()
print(stats.Accepted, stats.Rejected, stats.ByCode.RATE_LIMITED)
Vanguard.ResetNetworkStats()
```

Validation is not authentication. Keep ownership, permissions, inventory, currency, and session state on the server and check them in `Authenticate` or `Verify`.

### Validators

`Vanguard.Util.Validator` includes `any`, `type`, `robloxType`, `string`, `number`, `integer`, `boolean`, `literal`, `optional`, `oneOf`, `array`, `map`, `shape`, `instance`, `custom`, and `tuple` validators. Shapes reject unknown keys by default, arrays reject non-sequential keys, and numbers reject NaN and infinity by default.

## Utilities

```lua
local Cache = require(Vanguard.Util.Cache)
local Class = require(Vanguard.Util.Class)
local Cleaner = require(Vanguard.Util.Cleaner)
local Component = require(Vanguard.Util.Component)
local Error = require(Vanguard.Util.Error)
local Logger = require(Vanguard.Util.Logger)
local Math = require(Vanguard.Util.Math)
local NetworkGuard = require(Vanguard.Util.NetworkGuard)
local Promise = require(Vanguard.Util.Promise)
local RateLimiter = require(Vanguard.Util.RateLimiter)
local Signal = require(Vanguard.Util.Signal)
local Switch = require(Vanguard.Util.Switch)
local Validator = require(Vanguard.Util.Validator)
```

`Vanguard.CreateLogger("Scope")` creates a scoped logger using the current `LogLevel`.

### Cache

Caches support optional TTL expiry, LRU capacity limits, nil values, lazy population, and injectable clocks for testing.

```lua
local profileCache = Vanguard.CreateCache({
	DefaultTTL = 60,
	MaxSize = 100,
})

local profile, wasCached = profileCache:GetOrSet(player.UserId, function(userId)
	return loadProfile(userId)
end)

local cachedValue, found = profileCache:Get(player.UserId)
profileCache:Remove(player.UserId)
```

`Get`, `Peek`, and `Remove` return `value, found`, so a cached nil value remains distinguishable from a miss. `GetOrSet` returns `value, wasCached`. `Peek` does not refresh LRU recency.

### Rate Limiter

The per-key rolling-window limiter is useful at remote and gameplay boundaries. The second return value is the retry delay in seconds.

```lua
local actionLimiter = Vanguard.CreateRateLimiter({
	Limit = 10,
	Window = 1,
	WeakKeys = true,
})

local allowed, retryAfter = actionLimiter:Check(player)
if not allowed then
	return nil, `Try again in {retryAfter} seconds`
end
```

### Math

`Vanguard.Math` and `Vanguard.Util.Math` provide common gameplay-number helpers:

```lua
local damagePercent = Vanguard.Math.inverseLerp(0, maxHealth, currentHealth)
local screenX = Vanguard.Math.map(worldX, -100, 100, 0, 1920, true)
local stepped = Vanguard.Math.moveTowards(currentSpeed, targetSpeed, acceleration * deltaTime)
local slot = Vanguard.Math.snap(rawSlot, 5)
```

The module also includes `round`, `lerp`, `approximatelyEqual`, `wrap`, `pingPong`, `smoothstep`, `smootherstep`, and `average`.

### Switch

`Vanguard.Switch` provides explicit JavaScript-style case dispatch without fall-through:

```lua
local nextState = Vanguard.Switch.new(state)
	:Case("Paused", "Playing")
	:Cases({ "Playing", "Resuming" }, function(current, suffix)
		return current .. suffix
	end)
	:Default("Idle")
	:Run("State")
```

Use `Switch.match(value, cases, defaultResult, ...)` for concise table-based dispatch. Cases use Luau equality and execute in declaration order.

## Upcoming Features

Vanguard's next development phases are tracked in the [public roadmap](https://twrblxdevs.github.io/vanguard-docs/roadmap/). Vanguard `0.1.15` is planned around the **Plugin Developer API**. Following priorities include:

- a verified **Roblox Toolbox release** for non-Wally installation;
- **additional utility modules** selected around common production needs;
- **expanded documentation** with recipes, examples, and architecture references;
- **Studio tooling** for generation, validation, diagnostics, and protocol inspection;
- a clearer **community contribution** process with RFCs and scoped starter issues.

Roadmap items are directional until assigned to a release. Compatibility and security work take priority over delivery dates.

## Build

Build the package module:

```bash
rojo build default.project.json -o "Vanguard.rbxm"
```
