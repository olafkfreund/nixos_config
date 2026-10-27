---
status: draft
issue: 2501
author: olafkfreund
---

# Intent: Agent CLIs are versioned only by Nix, with Omarchy account routing kept

## Problem

Codex, Claude Code and Antigravity (`agy`) should get their versions from
this flake and nothing else. Today the picture is muddled:

- A typed `codex`, `claude` or `grok` first hits a mise `[wrappers]` symlink
  (`~/.local/share/mise/command-wrappers/bin/*` → `mise`). nixarchy-edge
  installs these on purpose, via `/etc/mise/conf.d/omarchy-agent-accounts.toml`
  (nixarchy #1386), so that `omarchy agent account use` reaches a CLI typed in
  a terminal. The wrapper runs `omarchy-agent-account-exec`, which starts the
  Nix binary. That works, but it looks like mise owns the tools, and a
  process listing shows `mise` where you expect `codex`.
- `codex` comes from nixpkgs (0.163.0) and lags upstream (0.164.0 since
  2026-10-23). The only way to get a newer one is to wait for nixpkgs.
- Two Claude Codes are installed: our `claude-code-native` 2.1.311 (Home
  Manager) and nixpkgs `claude-code` 2.1.308 in `system-path`. The second
  doesn't follow our updates, so any caller that resolves it gets an older
  version.
- Another session saw a daemon hang on a `codex` process that was the mise
  wrapper and had no child process. This was not reproduced: the wrapper,
  run detached with no tty, printed `codex-cli 0.163.0` and exited 0. The
  cause is unknown, so nothing yet prevents it happening again.

## Proposed outcome

- Every `codex`, `claude` and `agy` on PATH, wrapped or not, ends at a
  binary this flake pins, and there is exactly one version of each.
- Each is updated by a repo command (as with `/update-claude-code` and
  `/update-antigravity`), not by waiting on nixpkgs and never through mise.
- `omarchy agent account use` still switches the account a typed `claude`
  or `codex` runs as. The Omarchy launcher and keybinding keep working.
- A daemon or service that starts these CLIs can't stall in the mise
  wrapper, and a check fails if it would.

## Affected users and systems

- Hosts: p620 and razer (both have the agent CLIs and Omarchy). p510 has
  claude-code too, but it changes only with approval.
- Files: `pkgs/claude-code-native`, `home/development/codex-cli/module.nix`,
  the `antigravity-nix` input, nixarchy's `claude-code` app/preinstall
  selection, and whichever unit runs the daemon from the report.
- People: the user, and the agents and daemons (e.g. the OMA voice layer)
  that run `claude`/`codex -p`/`exec`.

## Constraints

- Keep Omarchy's per-account routing. Turning off the wrappers file is
  acceptable only if account selection is preserved some other way.
- Don't fork or patch nixarchy for this. Work through its options, or open
  an issue upstream.
- Overlays on deep packages poison the cache. Codex is a leaf, so a local
  package is fine; an overlay that other derivations depend on is not.
- Subscription login only (#1831). Nothing here may introduce an API key.
- p510: no build or deploy without asking.

## Open questions

1. Which daemon hung? The report didn't name it. The only long-running
   agent caller found on p620 is the OMA voice daemon, which runs claude by
   its store path and doesn't go through the wrapper. If you know which one
   it was (a user unit, a factory, herdr), say so. Otherwise the spec will
   try to reproduce the hang first and pick a fix based on what it finds.
2. Codex source: package upstream release binaries ourselves, the same way
   as `claude-code-native` (fast, prebuilt), or build from source in a local
   package (slower, no binary blob)?
3. Should `agy` also get account routing, or is it fine left outside it,
   since Omarchy has no account concept for it?
