# Update Antigravity

One-shot bump of **every locally-packaged Google Antigravity component** to
the latest version, followed by a verification **build** (no `switch`, no
deploy). Stops short of activating so you can review and deploy on your own
schedule with `nhs <host>`.

Packaged components (all live under `pkgs/`):

| Key | Package | Binary / module | Source |
|---|---|---|---|
| `cli` | `pkgs/antigravity-cli/default.nix` | `agy` | GCS tarball |
| `ide` | `pkgs/antigravity-ide/package.nix` | `antigravity-ide` (the IDE app) | edgedl CDN |
| `hub` | `pkgs/antigravity-hub/default.nix` | `antigravity-hub` (desktop launcher) | GCS tarball |
| `sdk` | `pkgs/google-antigravity-py/default.nix` | `google.antigravity` (Python) | PyPI wheel |

Single source of truth for versions+hashes is the community tracker
`Hy4ri/antigravity-flake` (`version.json`), which mirrors the official
auto-updater manifests and carries cli/ide/hub/sdk in one file. The repo has
referenced this tracker since the 2.1.1 IDE bump (#962).

## When to use

- You want the latest Antigravity CLI / IDE / SDK but haven't bumped in a while.
- A watcher or release note says Antigravity moved.
- Clean-baseline check at the start of a session.

## Prerequisites

- [ ] Working tree clean enough to commit (no unrelated edits to the three
      `pkgs/antigravity-*` / `pkgs/google-antigravity-py` files).
- [ ] On an x86_64-linux host that can build closures (p620 or razer —
      **not p510**, which doesn't ship Antigravity).
- [ ] `gh auth status` OK (only needed for the PR step).

## Steps

1. **Check first — early-exit if already current.**

   ```bash
   ./scripts/update-antigravity.sh --check
   ```

   Prints a `CURRENT / LATEST / STATUS` table for cli, ide, sdk. Exit 0 →
   everything current; stop, tell the user, do nothing else. Exit 1 → one or
   more updates available; continue.

2. **Apply the bumps.**

   ```bash
   ./scripts/update-antigravity.sh
   ```

   Rewrites `version` + `url` + `hash` in place for each out-of-date
   component (cli/ide/hub use the tracker's nix32 hash converted to SRI; sdk
   uses the tracker's PyPI url + SRI directly). Idempotent — safe to re-run.
   Does NOT build, commit, or deploy.

3. **Show the diff.**

   ```bash
   git --no-pager diff -- pkgs/antigravity-cli pkgs/antigravity-ide \
     pkgs/antigravity-hub pkgs/google-antigravity-py
   ```

   Sanity check: only `version`, `url`, and `hash` should change. Anything
   else moved → stop and investigate.

4. **Build-verify (no switch). Skip p510.**

   ```bash
   HOST=$(hostname)   # use p620 or razer
   # the changed packages, fast:
   nix build --no-link --print-out-paths \
     ".#nixosConfigurations.${HOST}.pkgs.customPkgs.antigravity-cli" \
     ".#nixosConfigurations.${HOST}.pkgs.customPkgs.antigravity-ide" \
     ".#nixosConfigurations.${HOST}.pkgs.customPkgs.antigravity-hub" \
     ".#nixosConfigurations.${HOST}.pkgs.customPkgs.google-antigravity-py"
   # full closure composes:
   nix build --no-link .#nixosConfigurations.${HOST}.config.system.build.toplevel
   ```

   All must succeed. A `hash mismatch` means the tracker hash was stale —
   re-run step 2 (or prefetch the URL yourself) and rebuild.

5. **Sanity-check the binaries.**

   ```bash
   CLI=$(nix build --no-link --print-out-paths ".#nixosConfigurations.$(hostname).pkgs.customPkgs.antigravity-cli")
   "$CLI/bin/agy" --version
   PY=$(nix build --no-link --print-out-paths ".#nixosConfigurations.$(hostname).pkgs.customPkgs.google-antigravity-py")
   "$PY/bin/python3" -c "import google.antigravity; print('SDK import OK')"
   ```

6. **Commit (branch + PR — issue-driven workflow).**

   ```bash
   git checkout -b chore/antigravity-bump
   git add pkgs/antigravity-cli pkgs/antigravity-ide pkgs/antigravity-hub \
     pkgs/google-antigravity-py
   git commit --no-verify -m "chore(antigravity): bump packages to latest"
   git push -u origin chore/antigravity-bump
   gh pr create --fill
   ```

   Use `git commit --no-verify` — the pre-commit statix hook hangs (established
   workaround).

7. **Tell the user how to deploy.** Do NOT `switch` from this command.

   ```text
   Antigravity bumped. To deploy (p620 + razer only):
       nhs p620        # local
       nhs razer       # remote
   ```

   razer note: `nh --target-host` can fail reading sudo over non-TTY even
   though razer has passwordless sudo. If so, activate the already-copied
   closure directly on razer:

   ```bash
   ssh razer 'sudo nix-env -p /nix/var/nix/profiles/system --set <toplevel> \
     && sudo <toplevel>/bin/switch-to-configuration switch'
   ```

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `--check` exits 0 | All current. | Tell user, stop. Not an error. |
| tracker fetch fails | Network / repo moved. | Check `curl -fsSL https://raw.githubusercontent.com/Hy4ri/antigravity-flake/main/version.json \| jq`. |
| `nix build` `hash mismatch` | Tracker hash stale vs the served file. | Re-run step 2; if it persists, `nix store prefetch-file <url>` and paste the SRI manually. |
| `rewrite failed (... subs=0)` | A package file's `version`/`url`/`hash` layout changed. | Inspect the file; the script expects one `version = "...";` and a `url`→`hash` fetchurl block. |
| IDE build fails on `autoPatchelfHook` | New IDE release added a runtime dep. | Add the missing lib to `runtimeLibs` in `pkgs/antigravity-ide/package.nix`. |

## Anti-patterns to avoid

- ❌ Do NOT chain a `switch`/deploy into this command — bump + build only.
- ❌ Do NOT skip the `--check` early-exit.
- ❌ Do NOT build/deploy p510 — it doesn't ship Antigravity.
- ❌ Do NOT hand-edit the package files when the script can do it —
   keep the blast radius to `pkgs/antigravity-*` + `pkgs/google-antigravity-py`.

## Related files

- `scripts/update-antigravity.sh` — the worker this command drives.
- `pkgs/antigravity-cli/default.nix` — `agy` CLI derivation.
- `pkgs/antigravity-ide/package.nix` — Electron IDE derivation.
- `pkgs/antigravity-hub/default.nix` — Electron Hub (desktop launcher) derivation.
- `pkgs/google-antigravity-py/default.nix` — Python SDK wheel.
- `pkgs/default.nix` — exposes all four as `customPkgs.*`.
- `Users/olafkfreund/profile.nix` — home-manager consumer (p620 + razer).

## Why this exists

Antigravity ships outside nixpkgs via Google CDNs with unguessable build-id
suffixes; the `Hy4ri/antigravity-flake` tracker is the practical way to learn
the current version+hash for every component. This command + script bump all
of them in one shot, matching the `/update-warp` and `/update-waveterm`
pattern.
