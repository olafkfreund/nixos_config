---
status: draft
issue: 2501
intent: intent/2026-10-27-2501-agent-clis-nix-only.md
---

# Spec: Agent CLIs are versioned only by Nix, with Omarchy account routing kept

## What research found

**The hang (reproduced on p620, 2026-10-27).** `codex exec "<prompt>"`
blocks forever on `Reading additional input from stdin...` when stdin is an
open pipe that no one writes to or closes. A daemon that starts it with an
inherited stdin is exactly that. It happens identically through the mise
wrapper and when calling the Nix binary directly (`timeout 30` → 124 both
ways), and returns `pong` at once with `</dev/null`. This is upstream
behaviour (`codex exec --help`: "If stdin is piped and a prompt is also
provided, stdin is appended"), reported as openai/codex#20919, still open.
It is the same trap as #2453.

**The wrapper is innocent.** `strace` of a typed `codex` shows one PID
throughout: `mise` → `exec omarchy-agent-account-exec` → `exec
/etc/profiles/.../bin/codex`. Nothing forks, so a stuck "mise shim with no
child" is the codex binary under the wrapper's original argv. Removing the
wrappers from PATH would not have fixed it. They stay.

**Where the versions come from.**

| CLI | Today | Second copy |
|---|---|---|
| `claude` | `pkgs.claude-code-native` 2.1.311 (Home Manager); nightly bump by `package-autoupdate.yml` | nixpkgs `claude-code` 2.1.308 in `system-path`, because p620 sets `programs.nixarchy.defaultAgent = "claude"` and nixarchy's `modules/apps.nix` maps that to `pkgs.claude-code` (lowPrio) |
| `codex` | nixpkgs `codex` 0.163.0 through `home/development/codex-cli/module.nix:11`; upstream is 0.164.0 | none today, but nixarchy's `defaultAgent = "codex"` and microvm template both name `pkgs.codex` |
| `agy` | `antigravity-nix` input, `scripts/update-antigravity.sh` in the autoupdate workflow | none; out of scope beyond confirming this |

## Design

### 1. Codex from upstream release binaries

New `pkgs/codex-bin/default.nix`, the same shape as `pkgs/opencode-bin`:
`stdenvNoCC`, `fetchurl` of
`https://github.com/openai/codex/releases/download/rust-v${version}/codex-<arch>-unknown-linux-musl.tar.gz`
for x86_64 and aarch64, installing the statically linked binary as
`$out/bin/codex`. musl static means no `autoPatchelfHook`.
`meta.mainProgram = "codex"`.

New `scripts/update-codex-bin.sh` (modelled on
`update-claude-code-native.sh`: read-only by default, `--write latest`
rewrites version and both hashes, resolving latest via `gh release view` with
pre-releases excluded). Add a `codex` row to
`.github/workflows/package-autoupdate.yml` (`verify: .#codex-bin`), plus
`.claude/commands/update-codex.md`, matching `update-claude-code.md`.

### 2. One version of each, through the overlay

In `overlays/custom-packages.nix`:

```nix
codex-bin = final.callPackage ../pkgs/codex-bin { };
codex = final.codex-bin;
claude-code = final.claude-code-native;
```

Every consumer that names `pkgs.codex` or `pkgs.claude-code`, including
nixarchy's `defaultAgent` mapping and its microvm agent template, then gets
our pinned binary. The second `claude` in `system-path` becomes the same
store path as Home Manager's, and the duplicate goes away without touching
nixarchy. Both are leaves (nothing in nixpkgs builds against them), so this
doesn't trigger the overlay cache-poisoning trap. `claude-code` is unfree
and never cached anyway. `codex-bin` is a download, not a compile.

`home/development/codex-cli/module.nix:11` keeps `pkgs.codex`, which now
resolves to `codex-bin`. Its comment is updated. The flake `packages` output
(`flake.nix:546–556`) gains `codex-bin` so `nix build .#codex-bin` and the
workflow's `verify` work. The old npm `claude-code` entry there
(`./home/development/claude-code`) is left alone, outside this scope.

### 3. The hang cannot recur: stdin guard in the codex package

`codex-bin` installs the real binary at `$out/libexec/codex` and puts a small
`writeShellScript` wrapper at `$out/bin/codex`:

- If the first non-option argument is `exec` (or `e`), a prompt argument
  other than `-` is present, stdin is **not** a terminal, **and**
  `CODEX_EXEC_STDIN` is unset, run the binary with `</dev/null`.
- Otherwise `exec` the binary with stdin untouched.

This turns the hang into upstream's tty behaviour ("prompt only") for every
caller: daemons, systemd units, agents, Omarchy's account wrapper (which
execs `codex` and so reaches this). Intentional piping still works two ways:
`cat f | codex exec -` (stdin is the prompt, never touched), or
`CODEX_EXEC_STDIN=1 cat f | codex exec "summarise"`. The wrapper is
documented in the package with a `shortcut:` comment naming #20919 and
saying to delete it when upstream fixes that issue.

The `CODEX_CODER=1 … codex -p implement` wrapper in
`home/development/codex-cli.nix:28` is not `exec`, so it is unaffected.

### 4. Omarchy account routing: unchanged

`/etc/mise/conf.d/omarchy-agent-accounts.toml`, the mise `[wrappers]` and
`omarchy-agent-account-exec` stay as nixarchy ships them. The exec resolves
`type -P codex` / `claude` after removing the wrapper dir, which finds our
Home Manager binaries, now the only versions. `omarchy agent account use`
keeps working with no change on our side.

## Alternatives rejected

- **Turn off the mise wrappers** (`environment.etc…enable = mkForce false`).
  It doesn't fix the hang (proven above) and loses per-account routing,
  which the intent says to keep.
- **Fix only the caller.** The daemon that hung wasn't identified (no repo
  caller runs `codex exec`; OMA runs agents in a terminal with a tty), so
  only a guard at the binary covers callers we can't see.
- **A timeout or first-byte probe on stdin.** It's racy against a slow
  writer, and reading the probe byte means re-injecting it. The tty test is
  deterministic.
- **Set `defaultAgent = null` to drop the second `claude`.** That removes the
  Omarchy Ask menu's default agent, which is integration the intent keeps.
- **Build codex from source.** The user chose release binaries.
- **Account routing for `agy`.** The user chose to skip it.

## Risks

- **Changed semantics for `prompt` + pipe.** A script that relies on
  `cat x | codex exec "do this"` silently loses the piped text unless it sets
  `CODEX_EXEC_STDIN=1`. Mitigation: no such caller exists in the repo
  (grepped). The guard prints one stderr line, `codex: stdin ignored (not a
  tty); set CODEX_EXEC_STDIN=1 to append it`, only when a piped stdin is
  replaced, so the change is visible.
- **The release tarball's binary may need sidecars.** The 0.164.0 release
  also ships `bwrap-*` and `codex-code-mode-host-*`. The nixpkgs build should
  be checked for whether it wraps `bubblewrap` onto PATH. If it does,
  `codex-bin` does the same with `pkgs.bubblewrap`. The plan includes a
  sandboxed `codex exec` smoke test, not just `--version`.
- **Overlaying `claude-code`** changes what nixarchy's microvm agent
  template installs, to our native binary. That's intended, but noted.
- **Hosts:** p620 and razer get the change. p510 also has the overlay
  (`claude-code-managed`); it builds only with your approval, and its
  closure changes by the same swap.

## Verification

- `nix build .#codex-bin` and `./result/bin/codex --version` → the pinned
  upstream version (≥ 0.164.0).
- Hang regression, run under `systemd-run --user`:
  `sleep 600 | codex exec --skip-git-repo-check 'reply pong'` returns
  `pong` within 60 s (before the change: hangs, `timeout` → 124).
  `printf hi | CODEX_EXEC_STDIN=1 codex exec … 'repeat the stdin block'`
  still sees `hi`. Done once through the mise wrapper and once direct.
- `nix eval` p620 and razer `environment.systemPackages` / `system-path`:
  every `claude` and `codex` resolves to the `claude-code-native` /
  `codex-bin` store paths. `type -a claude codex` after deploy shows one
  store path per tool.
- `omarchy agent account use codex <other>` then a typed `codex login
  status` reports that account (account routing intact).
- `just test-host p620`, `just test-host razer` (the latter via p620);
  `just validate`.
- `./scripts/update-codex-bin.sh --write latest` on a scratch copy rewrites
  version and hashes, and `nix build .#codex-bin` succeeds.
