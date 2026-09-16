---
status: approved
issue: 1859
author: olafkfreund
---

# Intent: a working opencode, from upstream's own binary

## Problem

`opencode` cannot be used. It starts, but every prompt fails:

```text
Error: {"name":"UnknownError","data":{"message":"Unexpected server error. …"}}
TypeError: undefined is not an object (evaluating 'a.name')
  at resolve … at SystemPrompt.environment …
```

This is not our configuration. It reproduces with a scrubbed environment, a
minimal config, no plugin, an empty working directory, isolated `XDG_*`
directories, two providers and on **both p620 and razer**. The unwrapped
`.opencode-wrapped` binary fails identically, so nixpkgs' wrapper is not
involved.

Upstream's own release binaries **work** on the same machine: 1.18.30 and
1.18.31 both reach the provider and return a normal answer or a normal API
error.

NixOS/nixpkgs#563241 has the identical stack trace: opencode compiled with
bun 1.4.2 hits a minification/bundle-splitting bug. Maintainers confirmed two
fixes (disable splitting, or apply opencode PR 48397), and the thread's
conclusion is that 1.18.31 resolves it. nixpkgs is still on 1.18.30 with no
update PR open, so waiting is not a fix.

Issue #1851 moved us to `pkgs.opencode` an hour earlier, which fixed the previous
startup crash (the vendored 0.5.13 could not parse a scoped plugin name) but
landed on this build bug.

## Proposed outcome

- `opencode run` works on p620 and razer: it reaches the model and answers, or
  returns a normal provider error.
- The `@dietrichgebert/ponytail` plugin still loads.
- opencode is 1.18.31, from upstream's official
  `opencode-linux-x64.tar.gz`, and the packaging is small enough to delete in
  one commit.
- It is obvious to the next reader why this exists and when to remove it:
  as soon as nixpkgs ships >= 1.18.31.

## Affected users and systems

- opencode on p620 and razer, including other agents' OpenCode sessions.
- A new `pkgs/opencode-bin/` derivation, `flake.nix` (package entry) and
  `home/default.nix` (the package used).
- p510 installs no opencode.

## Constraints

- Upstream's binary only: no rebuild of opencode from source, and no overlay
  on `pkgs.opencode` that would poison binary-cache hits for anything
  depending on it.
- Same command name, same user config and state paths; no behaviour change
  beyond the version.
- Temporary by construction: the derivation carries a comment naming
  nixpkgs#563241 and the condition for deleting it.
- `~/.local/share/opencode` keeps the backups taken in #1851; no further
  migration is expected between 1.18.30 and 1.18.31.
- p510 is not built or deployed.

## Open questions

None. The user chose this route over patching the nixpkgs build or waiting.
