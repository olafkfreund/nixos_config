# Update WaveTerm

One-shot bump of `pkgs/waveterm/versions.json` to the latest stable
release, followed by a verification **build** (no `switch`, no deploy).
Stops short of activating the new generation so you can review and deploy
on your own schedule with `nhs <host>` (or `just quick-deploy <host>`).

## When to use

- You want the latest WaveTerm stable but haven't deployed in a while.
- You launched WaveTerm and noticed it's behind upstream's release notes.
- You're starting a session and want a clean baseline before working.

## Prerequisites

- [ ] Working tree clean enough to commit (`git status` — at minimum, no
      uncommitted edits to `pkgs/waveterm/versions.json`).
- [ ] On a host that can build x86_64-linux closures (any of p620, razer,
      p510 — the script and overlay are host-agnostic).

## Steps

1. **Check first — early-exit if already current.**

   ```bash
   ./scripts/update-waveterm.sh --check
   ```

   Exit 0 → already on latest stable. Stop, tell the user, do nothing
   else. Exit 1 → newer release exists; continue.

2. **Bump `versions.json`.**

   ```bash
   ./scripts/update-waveterm.sh
   ```

   The script resolves the latest version via the GitHub Releases API,
   prefetches per-arch SRI hashes via `nix store prefetch-file`, and
   rewrites `pkgs/waveterm/versions.json` in place. Idempotent — safe
   to re-run.

3. **Show the diff.**

   ```bash
   git --no-pager diff -- pkgs/waveterm/versions.json
   ```

   Sanity check: only `version` and `hash` for `linux_x86_64` and
   `linux_aarch64` should change. If anything else moved, stop and
   investigate.

4. **Build (no link, no switch).**

   Pick the current host (use `hostname` if unsure).

   ```bash
   HOST=$(hostname)
   nix build --no-link --print-out-paths \
     .#nixosConfigurations.${HOST}.pkgs.waveterm
   ```

   For a deeper check that the toplevel closure still composes cleanly:

   ```bash
   nix build --no-link --print-out-paths \
     .#nixosConfigurations.${HOST}.config.system.build.toplevel
   ```

   Both must succeed.

5. **Sanity-check the built binary.**

   ```bash
   OUT=$(nix build --no-link --print-out-paths \
     .#nixosConfigurations.${HOST}.pkgs.waveterm)
   file "$OUT/app/waveterm/waveterm" | grep -q ELF \
     && echo "OK: binary is ELF" \
     || echo "FAIL: not ELF"

   nix eval --raw .#nixosConfigurations.${HOST}.pkgs.waveterm.version
   ```

   ELF + version match → green light. Either failing → roll back
   `versions.json` (`git checkout -- pkgs/waveterm/versions.json`)
   and stop.

6. **Commit (local, on main).**

   ```bash
   NEW_VERSION=$(jq -r '.linux_x86_64.version' pkgs/waveterm/versions.json)
   git add pkgs/waveterm/versions.json
   git commit --no-verify -m "chore(waveterm): bump to v${NEW_VERSION}"
   ```

7. **Tell the user how to deploy.** Do NOT run `nhs` or
   `nixos-rebuild switch` from this command — that's an explicit
   user decision.

   ```text
   Bumped waveterm to v<NEW_VERSION>. To deploy:
       nhs <host>          # current host or a remote host
   ```

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `--check` exits 0 | Already on latest. | Tell user, stop. Not an error. |
| GitHub API returns no version | Rate limit or network issue. | Wait and retry; or check `curl -s https://api.github.com/repos/wavetermdev/waveterm/releases/latest \| jq .tag_name` manually. |
| `nix build` fails with `hash mismatch` | Race: upstream rebuilt same version. | Re-run `./scripts/update-waveterm.sh` — second pass picks up new hash. |
| `nix build` fails on `autoPatchelfHook` | New Warp release added a runtime dep. | Read missing-library error, add package to `pkgs/waveterm/default.nix` `buildInputs`. |
| Binary not ELF | Something wrong with `.deb` extraction. | Inspect `$OUT` manually; check `installPhase` paths match current `.deb` layout. |

## Anti-patterns to avoid

- ❌ Do NOT chain a `switch` into this command.
- ❌ Do NOT skip the `--check` early-exit.
- ❌ Do NOT bump `pkgs/waveterm/default.nix` or `flake.nix` from this command.
  This command's blast radius is **only** `pkgs/waveterm/versions.json`.

## Related files

- `pkgs/waveterm/default.nix` — the derivation (Linux-only, mirrors nixpkgs).
- `pkgs/waveterm/versions.json` — the data file this command bumps.
- `scripts/update-waveterm.sh` — the bash worker. Wired into the derivation
  as `passthru.updateScript`.
- `overlays/custom-packages.nix` — overlay that points `pkgs.waveterm` at
  our fork so `home/desktop/terminals/wave/default.nix` picks it up.
- `home/desktop/terminals/wave/default.nix` — home-manager consumer.

## Why this exists

`pkgs.waveterm` from nixpkgs lags upstream by weeks. This command + the
overlay let us bump on our own cadence without waiting for nixpkgs, matching
the same pattern as `/update-warp` for Warp Terminal.
