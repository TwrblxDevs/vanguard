# Vanguard Documentation

This directory is the complete guide and reference for Vanguard. The root project README is a quick introduction; these documents cover behavior, guarantees, edge cases, and the full public API.

## Start Here

| Guide | What it covers |
| --- | --- |
| [Getting Started](getting-started/README.md) | Installation, project layout, first service, first controller, and bootstrap |
| [Configuration](configuration/README.md) | Every `StartOptions` field and server/client defaults |
| [Lifecycle](lifecycle/README.md) | Registration, init ordering, priorities, start hooks, and `OnStart` |
| [API Reference](api-reference/README.md) | Every method and public field on the main Vanguard module |
| [Type System](type-system/README.md) | Exported Luau types and autocomplete patterns |

## Framework Concepts

| Guide | What it covers |
| --- | --- |
| [Services](services/README.md) | Server-owned systems, client-facing methods, priority, and discovery |
| [Controllers](controllers/README.md) | Client-owned systems and service proxies |
| [Components](components/README.md) | CollectionService-backed behavior and per-instance cleanup |
| [Classes](classes/README.md) | Constructors, inheritance, registries, and runtime checks |
| [Networking](networking/README.md) | Remote functions, signals, properties, client proxies, and protocol checks |
| [Network Security](network-security/README.md) | Validation, authentication, verification, rate limits, and rejection handling |

## Utilities

The [utility index](utilities/README.md) explains when to use each utility.

| Utility | Guide |
| --- | --- |
| Cache | [Cache](utilities/cache/README.md) |
| Class | [Class](classes/README.md) |
| Cleaner | [Cleaner](utilities/cleaner/README.md) |
| Component | [Components](components/README.md) |
| Logger | [Logger](utilities/logger/README.md) |
| NetworkGuard | [NetworkGuard](utilities/network-guard/README.md) |
| Promise | [Promise](utilities/promise/README.md) |
| RateLimiter | [RateLimiter](utilities/rate-limiter/README.md) |
| RemoteProperty | [Networking](networking/README.md#remote-properties) |
| RemoteSignal | [Networking](networking/README.md#remote-signals) |
| Signal | [Signal](utilities/signal/README.md) |
| Validator | [Validator](utilities/validator/README.md) |

## Operations

| Guide | What it covers |
| --- | --- |
| [Troubleshooting](troubleshooting/README.md) | Startup errors, Wally paths, remote failures, and debugging checklists |
| [Migrating from Knit](migration-from-knit/README.md) | Hook aliases, API mapping, and migration differences |

## Documentation Conventions

- `Vanguard.Method(...)` and `Vanguard:Method(...)` are both supported by public methods on the main module.
- Utility objects use normal Lua method conventions. Call instance methods with `:` unless a guide explicitly says otherwise.
- Server examples belong in `ServerScriptService`; client examples belong in `StarterPlayerScripts` or another client container.
- A callback shown as returning `boolean, string?` should return `true` on success or `false, reason` on rejection.
- Ordering described as alphabetical uses the registered object's `Name`.

## Version

These docs describe Vanguard `0.1.13` and network protocol `1`.

Return to the [project README](../README.md).
