---
status: draft
issue: 1851
author: olafkfreund
---

# Intent: opencode comes from nixpkgs, not a vendored derivation

## Problem

`opencode` does not start at all. Every run in any directory ends with:

```text
Error: Unexpected error, check log file at ~/.local/share/opencode/log/…
ERROR service=default name=ResolveMessage
  message=Cannot find module '/home/olafkfreund/.cache/opencode/node_modules'
  code=ERR_MODULE_NOT_FOUND
```

The cause is a version. opencode 0.5.13 parses a plugin spec by splitting on
`@`, so the scoped plugin name `@dietrichgebert/ponytail` in
`~/.config/opencode/opencode.json` resolves to an empty package name, and it
imports the `node_modules` directory itself. The plugin is installed
correctly; opencode's own generated `~/.cache/opencode/package.json` shows the
misparse as `"": "dietrichgebert/ponytail"`.

We run 0.5.13 because the repo carries its own opencode derivation,
`home/development/opencode/default.nix`, exposed through `flake.nix:507` and
used by `home/default.nix:72`. nixpkgs has **1.18.30**, which handles scoped
plugins. The vendored copy has been pinned since it was added and would not
survive a bump anyway: it fetches `opencode-linux-x64.zip`, and upstream now
publishes `opencode-linux-x64.tar.gz`.

nixarchy is already correct — `data/apps.nix` and `modules/local-ai.nix` both
use `pkgs.opencode` — so this is only our packaging.

## Proposed outcome

- `opencode` starts and loads the `@dietrichgebert/ponytail` plugin on p620
  and razer.
- opencode comes from `pkgs.opencode` and moves with every nixpkgs bump, with
  no version or hash of ours to maintain.
- `home/development/opencode/` and the `flake.nix` package entry are gone.
- The agent-bus and the other opencode config in `~/.config/opencode`
  (MCP servers, permissions) keep working.

## Affected users and systems

- `opencode` on p620 and razer, including the OpenCode sessions other agents
  run on these machines.
- `home/default.nix` (the package list), `flake.nix` (the package entry),
  `home/development/opencode/` (deleted).
- p510 takes the same home config at its next deploy. It runs no opencode
  workflow.

## Constraints

- No behaviour change beyond the version: the same command name, the same
  user config files, no new wrapper.
- The vendored derivation wrapped the binary with `LD_LIBRARY_PATH` and a
  "default to `.` when called with no arguments" shim. The spec checks
  whether the nixpkgs package needs either, and says so if a wrapper is still
  wanted.
- 1.18.30 is a large jump from 0.5.13. Any config or session-format migration
  opencode performs must be understood before deploying, not after.
- p510 is not built or deployed without asking.

## Decision (user, 2026-09-16)

opencode comes from `home.packages = [ … pkgs.opencode … ]` in
`home/default.nix`, not through nixarchy's app list. Both routes install the
same `pkgs.opencode`, but the app list lives in `nixarchy-apps.nix`, a copy of
`~/.config/nixarchy/apps.nix` that `nixarchy-apply` rewrites, so the same line
would have to exist in two places to survive. `programs.nixarchy.localAi` also
installs opencode, but it is disabled here and brings the whole local-model
stack with it.

## Open questions

None.
