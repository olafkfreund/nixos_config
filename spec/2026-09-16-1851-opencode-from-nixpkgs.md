---
status: draft
issue: 1851
intent: intent/2026-09-16-1851-opencode-from-nixpkgs.md
---

# Spec: opencode comes from nixpkgs, not a vendored derivation

Approved decision: opencode is listed in `home.packages` as `pkgs.opencode`.

## Design

Three edits, all removing code:

- **`home/default.nix:72`:**
  `inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode` →
  `pkgs.opencode`, with a comment naming #1851 so nobody re-vendors it.
- **`flake.nix:507`:** delete
  `opencode = pkgs.callPackage ./home/development/opencode { };`.
- **`home/development/opencode/`:** delete the directory (the derivation and
  its README, if any). Nothing else references it (grep: only the two sites
  above).

### The vendored wrapper is not needed

The old derivation wrapped the binary twice over, and neither is required:

| Vendored behaviour | With `pkgs.opencode` |
| --- | --- |
| `--prefix LD_LIBRARY_PATH` with `stdenv.cc.cc.lib` and `glibc` | nixpkgs already ships a wrapper (`bin/opencode` is a bash wrapper that fixes PATH, e.g. ripgrep) and builds against the right libc |
| `--run 'if [ $# -eq 0 ]; then set -- .; fi'` (default to the current directory) | Checked below. 1.18.30 takes the current directory itself, so the shim would only mask the real CLI |

### Evidence collected before writing this (2026-09-16)

Run against `pkgs.opencode` 1.18.30 with isolated `XDG_CONFIG_HOME`,
`XDG_DATA_HOME` and `XDG_CACHE_HOME`, so the real state was untouched:

- **The startup crash is gone.** The isolated log has no
  `ERR_MODULE_NOT_FOUND` and no `ResolveMessage`; config loads, a session is
  created.
- **Scoped plugins work.** It fetched
  `cache/opencode/packages/@dietrichgebert/ponytail@latest/node_modules/@dietrichgebert/ponytail`.
  This is the bug 0.5.13 could not survive.
- **The remaining error in that test is not ours.** `TypeError: undefined is
  not an object (evaluating 'a.name')` appears identically with the plugin
  removed from the config, so it is the missing provider credentials in an
  isolated `XDG_DATA_HOME` (auth lives in the real `~/.local/share/opencode`).
- **No config migration needed:** 1.18.30 read the existing
  `~/.config/opencode/opencode.json` (plugins, MCP servers) unchanged.

### State on the hosts

`~/.config/opencode` and `~/.local/share/opencode` are the user's, not
managed by Nix, and stay as they are. 1.18.30 keeps sessions in
`~/.local/share/opencode`; it may migrate their format on first run, which is
one-way. The plan therefore backs that directory up before the first real
run, and names the restore path.

Hosts: p620 and razer, deployed. p510 takes the change at its next deploy and
runs no opencode workflow.

## Alternatives rejected

- **Bump the vendored derivation to 1.18.30:** keeps a private copy of a
  package nixpkgs maintains, and it would need a new URL and unpack (upstream
  moved from `.zip` to `.tar.gz`) plus a fresh hash at every release.
- **nixarchy's app list (`nixarchy-apps.nix`, `opencode.enable = true`):**
  same package, but that file is a copy of `~/.config/nixarchy/apps.nix` that
  `nixarchy-apply` rewrites, so the line would have to exist in two places.
  Rejected in the intent's decision.
- **`programs.nixarchy.localAi` with opencode as an agent:** installs the same
  package but is disabled here and brings the whole local-model stack.
- **Pinning opencode with an overlay:** an overlay on a widely-used package
  costs binary-cache hits elsewhere; there is no reason to pin.

## Risks

| Risk | Where | Mitigation |
| --- | --- | --- |
| 1.18.30 migrates `~/.local/share/opencode` one way, and a rollback then finds an unreadable state | p620, razer | Back the directory up before the first real run; the plan names the restore command |
| A setting in `~/.config/opencode/opencode.json` is no longer valid after 13 minor versions | p620, razer | Verified: 1.18.30 loads the existing config, plugins and MCP entries with no complaint |
| Another agent's OpenCode session is running during the deploy | p620, razer | The package path changes only for new launches; running processes keep their store path. Announced on the bus first |
| A tool expects the vendored flake package attribute | anywhere | grep shows only `home/default.nix:72` referenced it; the flake attribute is ours alone |
| opencode's own auto-update tries to replace the Nix binary | p620, razer | `autoupdate=false` is already in `~/.config/opencode/opencode.json`; the plan re-checks after deploy |

## Verification

1. **Build:** `just check-syntax`, `just test-host p620`, `just test-host
   razer`; p510 evaluated only.
2. **Gone:** `grep -rn "development/opencode" .` returns nothing, and
   `nix eval .#packages.x86_64-linux.opencode` fails with "attribute missing".
3. **After deploy, on both hosts:** `opencode --version` → `1.18.30`, and the
   binary resolves to a store path containing `opencode-1.18.30`.
4. **The reported bug is fixed on p620:** `opencode run "reply ok"` in
   `~/.config/nixos` no longer prints the "Unexpected error" banner, and the
   newest log under `~/.local/share/opencode/log/` contains no
   `ERR_MODULE_NOT_FOUND`. A provider or credit error is acceptable: the fix
   is about startup, not about the model answering.
5. **Plugin loads with the real config:** after that run,
   `~/.cache/opencode/packages/@dietrichgebert/ponytail@latest` exists.
6. **No regressions:** `autoupdate` is still `false`; the MCP entries in
   `~/.config/opencode/opencode.json` are unchanged.
