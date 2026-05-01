# Update Warp Terminal

One-shot bump of `pkgs/warp-terminal/versions.json` to the latest stable
release, followed by a verification **build** (no `switch`, no deploy).
Stops short of activating the new generation so you can review and deploy
on your own schedule with `nhs <host>` (or `just quick-deploy <host>`).

## When to use

- You want the latest Warp stable but haven't deployed in a while.
- You launched Warp and noticed it's behind upstream's release notes.
- You're starting a session and want a clean baseline before working.

## Prerequisites

- [ ] Working tree clean enough to commit (`git status` — at minimum, no
      uncommitted edits to `pkgs/warp-terminal/versions.json` or
      `flake.nix`).
- [ ] On a host that can build x86_64-linux closures (any of p620, razer,
      p510 — the script and overlay are host-agnostic).

## Steps

1. **Check first — early-exit if already current.**

   ```bash
   ./scripts/update-warp-terminal.sh --check
   ```

   Exit 0 → already on latest stable. Stop, tell the user, do nothing
   else. Exit 1 → newer release exists; continue.

2. **Bump `versions.json`.**

   ```bash
   ./scripts/update-warp-terminal.sh
   ```

   The script resolves the latest version via the `app.warp.dev/download`
   redirect chain, prefetches per-arch SRI hashes via
   `nix store prefetch-file`, and rewrites `pkgs/warp-terminal/versions.json`
   in place. Idempotent — safe to re-run.

3. **Show the diff.**

   ```bash
   git --no-pager diff -- pkgs/warp-terminal/versions.json
   ```

   Sanity check: only `version` and `hash` for `linux_x86_64` and
   `linux_aarch64` should change. If anything else moved, stop and
   investigate.

4. **Build (no link, no switch).**

   Pick the current host (use `hostname` if unsure). The build below is
   the same one CI would run; it forces a full closure check including
   the new Warp.

   ```bash
   HOST=$(hostname)
   nix build --no-link --print-out-paths \
     .#nixosConfigurations.${HOST}.pkgs.warp-terminal
   ```

   For a deeper check that the toplevel closure still composes cleanly:

   ```bash
   nix build --no-link --print-out-paths \
     .#nixosConfigurations.${HOST}.config.system.build.toplevel
   ```

   Both must succeed. The first is fast (~seconds, just the package).
   The second is slower but catches any overlay-interaction surprises.

5. **Sanity-check the built binary.**

   ```bash
   OUT=$(nix build --no-link --print-out-paths \
     .#nixosConfigurations.${HOST}.pkgs.warp-terminal)
   file "$OUT/opt/warpdotdev/warp-terminal/warp" | grep -q ELF \
     && echo "OK: binary is ELF" \
     || echo "FAIL: not ELF"

   # Verify version pin matches versions.json
   nix eval --raw .#nixosConfigurations.${HOST}.pkgs.warp-terminal.version
   ```

   ELF + version match → green light. Either failing → roll back
   `versions.json` (`git checkout -- pkgs/warp-terminal/versions.json`)
   and stop.

6. **Commit (local, on main).**

   ```bash
   NEW_VERSION=$(jq -r '.linux_x86_64.version' pkgs/warp-terminal/versions.json)
   git add pkgs/warp-terminal/versions.json
   git commit -m "chore(warp-terminal): bump to v${NEW_VERSION}"
   ```

   Use the conventional-commits format the repo follows. No `--no-verify`
   needed — the bumped file passes `json-format` and the build already
   passed.

7. **Tell the user how to deploy.** Do NOT run `nhs` or
   `nixos-rebuild switch` from this command — that's an explicit
   user decision.

   ```text
   Bumped warp-terminal to v<NEW_VERSION>. To deploy:
       nhs <host>          # current host or a remote host
   ```

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `--check` exits 0 | Already on latest. | Tell user, stop. Not an error. |
| Script can't resolve version | Warp changed their redirect endpoint. | Check `curl -I "https://app.warp.dev/download?package=pacman"` manually; if 200 not 302, upstream changed their pattern — script needs updating. |
| `nix build` fails with `hash mismatch` | Race: upstream rebuilt the same version with a different artifact (rare). | Re-run the script (`./scripts/update-warp-terminal.sh`) — second pass will repickup the new hash. |
| `nix build` fails on autoPatchelfHook | New Warp release added a runtime dep we don't list. | Read the missing-library error, add the package to `pkgs/warp-terminal/default.nix` `runtimeDependencies`. |
| Binary not ELF | Something wrong with the `.pkg.tar.zst` extraction (very rare). | Inspect `$OUT` manually; check `sourceRoot = ".";` is still correct vs. upstream's archive layout. |

## Anti-patterns to avoid

- ❌ Do NOT chain a `switch` into this command. The whole reason for
  build-not-switch is to give the user a checkpoint between "fetched
  new version" and "running it on production".
- ❌ Do NOT skip the `--check` early-exit. Running the full bump every
  time wastes time and produces empty commits.
- ❌ Do NOT bump `pkgs/warp-terminal/default.nix` or `flake.nix` from
  this command. This command's blast radius is **only**
  `pkgs/warp-terminal/versions.json`. Changes to the derivation or
  overlay are a different (deliberate) workflow.
- ❌ Do NOT auto-deploy to other hosts. Razer's user might be in a
  Warp session right now; surprise-restarting isn't friendly.

## Related files

- `pkgs/warp-terminal/default.nix` — the derivation (Linux-only fork
  of upstream nixpkgs).
- `pkgs/warp-terminal/versions.json` — the data file this command
  bumps. The only output of step 2.
- `scripts/update-warp-terminal.sh` — the bash worker. Wired into
  the derivation as `passthru.updateScript`, so `nix-update
  warp-terminal` would also invoke it.
- `flake.nix` — overlay block that points `pkgs.warp-terminal` at our
  fork. Don't touch from this command.
- `home/desktop/terminals/warp/default.nix` — home-manager
  consumer; references `pkgs.warp-terminal` (which the overlay
  resolves to ours).

## Why this exists

`pkgs.warp-terminal` from nixpkgs lags upstream by ~2 weeks because it
depends on a nixpkgs maintainer running `update.sh` against the unstable
channel. This command + the overlay let us bump on our own cadence
without waiting for nixpkgs. See the
`feat(warp-terminal): track latest stable via custom derivation`
PR (#401) for the full design rationale.
