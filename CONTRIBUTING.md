# Contributing to Vanguard

Thanks for helping improve Vanguard. Contributions are welcome across the runtime, utilities, tests, documentation, and tooling.

The complete contribution guide is published at [Vanguard Documentation](https://twrblxdevs.github.io/vanguard-docs/contributing/). This file covers the rules every pull request must follow.

## Before you start

- Search existing issues and pull requests before opening duplicate work.
- Open an issue or discussion before changing a public API, Network Protocol 1, authentication behavior, or another compatibility-sensitive contract.
- Keep each pull request focused on one coherent change.
- Never publish exploit details, credentials, tokens, private user data, or production secrets in an issue or pull request.

## Local checks

Install the tools from `rokit.toml`, install the project packages, and run the checks that match your change.

```sh
rokit install
wally install
lune run tests/utilities.luau
rojo build default.project.json --output Vanguard.rbxm
```

Lune is required for the utility test suite and is not currently managed by this repository's `rokit.toml`.

## Branches and commits

Use a short branch name with a category prefix, such as `feat/class-visibility`, `fix/remote-property-set`, or `docs/network-protocol`.

Vanguard follows [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>)!: <description>
```

Common types are `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, and `revert`. Useful scopes include `server`, `client`, `network`, `classes`, `utilities`, `docs`, and `tooling`.

```text
feat(classes): add protected member support
fix(network): reject expired authentication challenges
docs(protocol): clarify request envelope validation
```

Use `!` and a `BREAKING CHANGE:` footer when callers must update their code. Keep the subject imperative, lowercase, concise, and without a trailing period.

## Pull request checklist

- [ ] The change is focused and follows the existing Luau style.
- [ ] Public APIs include useful types and documentation.
- [ ] Server authority and network validation remain intact.
- [ ] Tests cover new behavior and important failure paths.
- [ ] `lune run tests/utilities.luau` passes when utilities are affected.
- [ ] `rojo build default.project.json --output Vanguard.rbxm` passes.
- [ ] User-facing changes update the docs and changelog.
- [ ] Breaking changes are clearly identified and include migration guidance.

By contributing, you agree that your contribution may be distributed under Vanguard's MIT License.
