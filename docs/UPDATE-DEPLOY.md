# NixOS Update & Deploy — `just update-commit-deploy` / `nhs`

One command that does the full, idiot-proof update-and-deploy flow: bump the
flake lock, commit it, push it, build, switch. Works for the local machine
and for remote hosts over SSH.

## TL;DR

```bash
nhs                 # update+deploy current host, nixpkgs scope
nhs razer           # deploy razer (remote via SSH/nh)
nhs p510 all        # update all inputs, deploy p510
nhs razer home-manager  # bump one specific input
```

Or the explicit form:

```bash
just update-commit-deploy HOST [SCOPE]
```

Both invoke the same script: `scripts/update-commit-deploy.sh`.

## What it does (in order)

1. **Pre-flight**
   - Must be on branch `main`
   - Working tree must be clean — only `flake.lock` may be dirty
   - If HOST is remote: check SSH reachability. Abort early if not.
2. **Update** — `nix flake update <SCOPE>` (default `all`; **recommended**
   so you always pull the latest from every input — a stale checkout that
   only updates one input is the easiest way to ship a regression no-one
   else will hit).
3. **Splice nixpkgs** — overwrites `nixpkgs` and `nixpkgs-unstable` in the
   lock with the GitHub-API ground truth (bypasses every nix cache).
4. **Freshness check** — cheap `nix eval --raw` to compute what the target's
   closure should be, compared against its current `/run/current-system`.
   If lock didn't change AND host already on latest → exit "nothing to do".
5. **Show delta** — nixpkgs rev + list of all bumped flake inputs with dates
6. **Build** the target host closure. Abort if build fails (no commit).
7. **Open a PR for the lock — DO NOT merge yet.** Lock change goes to a
   feature branch + opens a PR via `gh pr create`. The merge is deferred
   to step 11 below so a broken upstream can never land on `main`.
8. **Snapshot** target's current generation symlink (used by rollback).
9. **Switch** via `nh os switch`:
   - local: `nh os switch --hostname HOST .`
   - remote: `nh os switch --hostname HOST --target-host HOST .`
     (builds on the local machine and ships the closure over SSH)
10. **Health check** — runs `scripts/health-checks/$HOST.sh` on the target
    (locally or piped over SSH). The check waits 15s for services to
    settle, then asserts host-specific health invariants (e.g. for GDM
    hosts: no `GdmLocalDisplayFactory: maximum number of display failures
    reached` in the journal — the signature of the 2026-06-08 silent
    compositor crash that motivated this whole layer).
    Skipped if `nh os switch` fell back to `nh os boot` (the new gen isn't
    running yet — verify manually after reboot).
11. **Finalize OR rollback** —
    - **Healthy:** squash-merge the open PR, pull `main`, done.
    - **Unhealthy:** SSH (or local) to run the snapshotted generation's
      `switch-to-configuration switch`, close the PR + delete its branch,
      discard the local dirty `flake.lock`, return to clean `main`, exit 1.
      Next deploy starts from a fresh upstream pull.

## Health checks

Per-host smoke tests in `scripts/health-checks/<host>.sh`. Each script:

- Runs on the target (locally or piped over SSH as `bash -s`)
- Exits 0 if the host is healthy, non-zero if not
- Prints a one-line reason on its first line

Current checks:

| Host | What it asserts |
|---|---|
| `p620` | `display-manager` active, no GDM exhaustion, `nix-serve` active (other hosts depend on it as a binary cache) |
| `razer` | `display-manager` active, no GDM exhaustion (the documented Optimus PRIME-sync failure mode) |
| `p510` | `is-system-running` ∈ {running, degraded}, `sshd` + `plex` active, `podman-backstage` active if enabled |

**To add a host:** copy one of the existing scripts to
`scripts/health-checks/<newhost>.sh`, `chmod +x`, edit to taste. If no
health-check script exists for a host, the deploy step prints a warning
and finalizes the merge anyway — but you lose the rollback safety net.

## State machine

| Lock changed | Host stale | Outcome |
|---|---|---|
| no  | no  | exit "nothing to do" |
| no  | yes | skip commit, still deploy (catch stale host up) |
| yes | yes | commit + push + deploy (main path) |

## Arguments

| Position | Name | Default | Values |
|---|---|---|---|
| 1 | `HOST` | `$(hostname)` | any name in `flake.nix` `nixosConfigurations.*` |
| 2 | `SCOPE` | `all` | `all`, `nixpkgs`, or any specific input name |

### Common scopes

- `all` — update every input in the flake (default; the most common case)
- `nixpkgs` — only the root nixpkgs input (use for targeted security-driven bumps)
- `home-manager`, `claude-desktop-linux`, `sops-nix`, ... — any input name from `flake.nix`

## Idiot-proofing guarantees

- **A broken upstream can never land on `main`.** The PR is held open until
  the health check passes. Failure path closes the PR + discards the local
  lock; `main` is never touched. This is the layer added 2026-06-08 after
  a transient mesa/GNOME regression was shipped to razer through the
  previous direct-merge path.
- **Auto-rollback on failure.** If the switch returns non-zero OR the
  per-host health check fails, the target is reverted to the snapshotted
  generation via `switch-to-configuration switch` (no reboot needed).
- **Dirty-tree safety.** Refuses to run if unrelated dirty files exist —
  forces you to clean up first.
- **Build-first.** Test-build must succeed before any commit attempt. Build
  failure = lock stays dirty, nothing pushed, nothing deployed.
- **Freshness-aware.** If the lock is unchanged but the target host is
  behind, deploys anyway.
- **Always-fresh inputs.** Default `SCOPE=all` so every input gets pulled
  from upstream — never deploy from a stale checkout that only updated a
  single input.
- **Fails loud.** Every failure path prints a clear remediation hint and
  rolls back to a sane state.

## Remote host requirements

- SSH alias in `~/.ssh/config` (or fully-qualified name)
- `~/.config/nixos` on the remote is a git clone of this repo with no local edits (the script's freshness check only
  reads `/run/current-system`; the actual deploy is handled by `nh os switch --target-host`, which ships the closure
  over SSH from your local machine)
- Passwordless sudo for your user OR `nh`'s elevation strategy kicks in (we already have `NOPASSWD: ALL` on
  p620/razer/p510)
- SSH key loaded in `ssh-agent` (no password prompts)

## The `nhs` shortcut

`nhs` is a zsh function defined in `home/shell/zsh.nix`. It wraps `just update-commit-deploy` so the muscle-memory
alias works the same way from any directory:

```zsh
nhs() {
  (cd ~/.config/nixos && just update-commit-deploy "$@")
}
```

Before 2026-04-21 `nhs` was `alias nhs="nh os switch"` — a raw `nh` invocation. The new form adds lock commit +
freshness check + push safety.

## Examples

```bash
# Typical: bump nixpkgs, deploy to the current host
$ nhs
>> pre-flight: checking working tree state
>> current nixpkgs pin: b12141ef61 (2026-04-18T21:33:21Z)
>> nix flake update nixpkgs
>> no lock changes — nothing to commit or deploy.

# razer is behind — deploy without a lock bump
$ nhs razer
>> freshness check: evaluating expected closure for razer
>> lock unchanged — but razer is stale (running ...); deploying current state
>> building .#nixosConfigurations.razer.config.system.build.toplevel
...

# Pull in new home-manager + deploy to razer
$ nhs razer home-manager

# Update everything + deploy to current host
$ nhs $(hostname) all
```

## Split deploy: build now, deploy later (`nhsb` / `--no-deploy`)

If the target host is offline (e.g. razer is off-network), you can still bump
the lock and pre-build its closure on this machine, then deploy when the host
comes back. Two stages:

```bash
# Stage 1 (now, target offline): bump lock + build + commit + PR-merge.
# Skips the SSH reachability check and the final `nh os switch`.
nhsb razer                  # or: just update-commit razer

# Stage 2 (later, target online): cache-hit build + copy + activate.
nhs razer
```

Why this works: Nix is content-addressed, so the closure built in stage 1 lives
in your local `/nix/store`. In stage 2, `nh os switch` re-evaluates and finds
every derivation already built — no rebuild, only `nix copy` over SSH and
activation.

Stage 1 still commits `flake.lock` to `main` via the same PR-merge flow as the
full command, so your tree is clean afterwards and you can deploy other hosts
in between without dirty-lock drift.

If the lock is unchanged when you run `nhsb`, it exits "nothing to prebuild"
without doing wasted work — there's no point pre-building a closure for an
unreachable host when nothing changed.

## Files

- `scripts/update-commit-deploy.sh` — the script (`--no-deploy` flag for stage 1)
- `Justfile` — `update-commit-deploy` and `update-commit` recipes
- `home/shell/zsh.nix` — `nhs` and `nhsb` functions

## Related

- `just update` (`nh os update`) — plain nh update, no commit
- `just update-flake` — `nix flake update` then `just deploy`, no commit
- `just quick-deploy HOST` — smart-deploy-if-changed without touching the lock
- `just deploy` — local-only switch via nh

For everything else, see `just --list`.
