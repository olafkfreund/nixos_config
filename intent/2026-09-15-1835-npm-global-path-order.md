---
status: approved
issue: 1835
author: olafkfreund
---

# Intent: tools installed by language package managers never shadow Nix packages

## Problem

Several directories that `npm`, `cargo install` and `go install` write to are
**prepended** to PATH, so anything installed there beats the Nix-managed
version of the same command:

- `~/.npm-global/bin`: `home/development/npm-prefix.nix:39`
  (`home.sessionPath`, which prepends) and `home/shell/bash.nix:213`
- `~/.cargo/bin`: `home/shell/bash.nix:213`
- `~/go/bin`: `home/shell/bash.nix:212`

This isn't theoretical. On razer on 2026-09-15:

- An npm `@anthropic-ai/claude-code` hid the Nix-managed Claude Code.
  `~/.claude.json` had `installMethod: "global"`, so Claude's auto-updater
  kept that npm copy current.
- An npm `tree-sitter-cli` hid the Nix `tree-sitter`.
- `~/.cargo/bin` holds `btm` and `fd`, and `~/go/bin` holds `staticcheck`
  and an unrelated binary called `gemini`. Any of them wins over a Nix
  package with the same name.

The npm copies were removed by hand, but nothing in the repo stops this
happening again. Every `npm i -g`, `cargo install` or `go install` can
silently replace a Nix-managed tool, and flake updates stop reaching it.
nixarchy#707 (the mise launchers) is the same class of problem, from a
different source.

## Proposed outcome

- On p620 and razer, in bash, zsh and non-interactive `ssh host cmd` shells,
  a command installed by Nix always resolves to the Nix copy, even when an
  npm, cargo or go install of the same name exists.
- Tools that exist **only** in those directories (npm `jshint`,
  `neovim-node-host`, `cargo-sqlx`, `tokio-console`, go `golangci-lint`…)
  still resolve and work.
- Duplicates of Nix commands in `~/.npm-global/bin`, `~/.cargo/bin` and
  `~/go/bin` are removed from both hosts.
- `~/.local/bin` keeps its current place. Home Manager puts the managed
  `claude` launcher there on purpose.

## Affected users and systems

- The `olafkfreund` shells on p620 and razer. p510 gets the same PATH order
  at its next deploy, and has no hand-installed npm, cargo or go tools that
  are known to matter.
- `home/development/npm-prefix.nix`, `home/shell/bash.nix`, and wherever zsh
  gets these directories (checked in the spec).
- Anything that relies on a cargo, go or npm copy *overriding* a Nix
  package on purpose. None are known yet; the spec lists every such name
  collision on both hosts.

## Constraints

- Don't change where npm, cargo or go install things (`NPM_CONFIG_PREFIX`,
  `~/.npmrc`, `CARGO_HOME`, `GOPATH`). Only the PATH order changes.
- Don't remove the directories from PATH. Tools that exist only there must
  keep working.
- The order must be the same in login, interactive and non-interactive
  shells. The `bashrcExtra` comment says it exists so that `ssh host cmd`
  gets PATH, and that must keep working.
- Home Manager is a flake module: no `home-manager switch`.
- p510 is not built or deployed without asking.

## Decisions (user, 2026-09-15)

1. **Nix is the master.** No npm, cargo or go copy may override a Nix
   package, not even a newer one. A tool that should be newer gets packaged
   or pinned in Nix instead.
2. **Delete the duplicates.** The implementation also removes, on p620 and
   razer, every npm, cargo or go install whose command a Nix package also
   provides. Tools that exist only in those directories stay.

## Open questions

None.
