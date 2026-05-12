# Update Gemini CLI

One-shot bump of `home/development/gemini-cli/default.nix` to the latest
upstream `google-gemini/gemini-cli` release, followed by a verification
**build + host matrix** (no `switch`, no deploy). Stops short of
activating the new generation so you can review and deploy on your own
schedule with `nhs <host>` (or `just quick-deploy <host>`).

## When to use

- You want the latest gemini-cli but the npm release is ahead of the
  in-tree pin.
- You launched `gemini` and noticed it's behind upstream's release notes.
- Nixpkgs is on an older minor and you'd rather not wait for it to
  catch up (the in-tree derivation is intentionally ahead-of-nixpkgs).

## Prerequisites

- [ ] Working tree clean enough to commit (`git status` — at minimum, no
      uncommitted edits to `home/development/gemini-cli/default.nix`).
- [ ] `gh auth status` OK (PR step uses `gh`).
- [ ] On a host that can build x86_64-linux closures (any of p620, razer,
      p510).

## Steps

1. **Check current vs npm latest.**

   ```bash
   echo "current pin:"
   grep '^\s*version = ' home/development/gemini-cli/default.nix
   echo "npm latest:"
   curl -s https://registry.npmjs.org/@google/gemini-cli/latest | jq -r .version
   ```

   If equal → tell the user, stop. Not an error.

2. **Branch.**

   ```bash
   git checkout -b chore/gemini-cli-<NEW_VERSION>
   ```

3. **Fetch new source hash.**

   ```bash
   nix shell nixpkgs#nix-prefetch-github -c \
     nix-prefetch-github google-gemini gemini-cli --rev v<NEW_VERSION> --json
   ```

   Note the returned `hash` and `rev` — you'll paste both.

4. **Edit `home/development/gemini-cli/default.nix` — three lines:**

   ```nix
   version = "<NEW_VERSION>";
   ...
   hash = "<NEW_SRC_HASH>";
   ...
   npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";   # placeholder
   ```

   The npmDepsHash placeholder forces step 5 to surface the real hash.

5. **Build once to harvest the npmDepsHash.**

   ```bash
   nix-build -E 'with import <nixpkgs> {}; callPackage ./home/development/gemini-cli {}' --no-out-link 2>&1 \
     | grep "got:" | head -1
   ```

   Copy the `sha256-...` after `got:` and replace the placeholder.

6. **Real build + version sanity.**

   ```bash
   OUT=$(nix-build -E 'with import <nixpkgs> {}; callPackage ./home/development/gemini-cli {}' --no-out-link 2>&1 | tail -1)
   "$OUT/bin/gemini" --version            # must equal <NEW_VERSION>
   file "$OUT/bin/gemini"                 # symlink to gemini.js, fine
   ```

   If `--version` reports something other than the target → upstream
   stamped a different version into the build; investigate before
   continuing.

7. **Host matrix — all three must build.**

   ```bash
   for h in p620 razer p510; do
     printf "%-8s " "$h"
     nix build --no-link --print-out-paths .#nixosConfigurations.$h.config.system.build.toplevel 2>&1 | tail -1
   done
   ```

   Any failure → stop. The most common cause is the bundle layout
   shifting between releases; check the build log for paths under
   `share/gemini-cli/` that no longer exist.

8. **Commit, push, PR.**

   ```bash
   NEW_VERSION=<...>
   git add home/development/gemini-cli/default.nix
   git commit -m "chore(gemini-cli): bump to v${NEW_VERSION}"
   git push -u origin chore/gemini-cli-${NEW_VERSION}
   gh pr create --title "chore(gemini-cli): bump to v${NEW_VERSION}" --fill
   ```

9. **Tell the user how to deploy.** Do NOT run `nhs` or
   `nixos-rebuild switch` from this command — deployment is an explicit
   user decision.

   ```text
   Bumped gemini-cli to v<NEW_VERSION>. PR: <URL>.
   To deploy after merge:
       nhs <host>          # current host or a remote host
   ```

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `--version` reports old number | upstream tag drift OR our patch corrupted the version write | inspect `packages/cli/package.json` of the source; align our pin with what's actually tagged |
| `hash mismatch` even with the prefetched hash | upstream re-tagged the same version, or `fetchFromGitHub` is being applied with `--no-deep-clone` | rerun step 3 to refresh the hash |
| `npm build` fails on TS errors like `TS2578 Unused '@ts-expect-error'` | upstream fixed the underlying error our patch was suppressing | remove the obsolete `substituteInPlace … @ts-expect-error` line from `postPatch` |
| `noBrokenSymlinks: dangling symlink … docs/CONTRIBUTING.md → /build/...` | upstream's bundle script symlinks docs into the source tree | extend installPhase to `rm -f $out/share/gemini-cli/docs/CONTRIBUTING.md` |
| `git: not found` early in build phase | `generate-git-commit-info.js` writes to a new path we haven't pre-stubbed | add the new path to `preConfigure`'s file-creation loop |
| Bundle script renamed | upstream switched `bundle` → some other npm script | update `npmBuildScript = "bundle";` to match upstream's `package.json` scripts |

## Anti-patterns to avoid

- ❌ Do NOT chain a `switch` into this command. The whole reason for
  build-not-switch is to give the user a checkpoint between "bumped
  source" and "running it on production".
- ❌ Do NOT skip the host matrix step. gemini-cli is in the system
  closure on all three hosts via `home/development/`; a successful
  per-package build doesn't guarantee the system rebuilds clean.
- ❌ Do NOT auto-bump nixpkgs `pkgs.gemini-cli` instead of our custom
  derivation. We're intentionally ahead-of-nixpkgs; the custom
  derivation under `home/development/gemini-cli/` is the source of
  truth. (When nixpkgs catches up, that's a separate decision to retire
  the custom derivation — not the job of this command.)
- ❌ Do NOT carry forward obsolete `postPatch` substitutions just
  because the previous version had them. Each line in `postPatch` is
  there for a specific upstream issue; if the issue is fixed, the
  patch becomes either a no-op (wasted CPU) or an error
  (`substituteInPlace --replace-fail` failing).

## Related files

- `home/development/gemini-cli/default.nix` — the derivation this
  command bumps. Single source of truth.
- `pkgs/default.nix` — exposes the package to the rest of the repo.
- `modules/ai/gemini-cli.nix` — Home Manager / NixOS module that wires
  the binary into a user environment.
- `modules/ai/providers/gemini.nix` — provider plumbing for the
  unified AI client (not version-coupled; safe to ignore from this
  command).

## Why this exists

`pkgs.gemini-cli` from nixpkgs lags upstream by 1–2 minor releases
because nixpkgs maintainers cycle on a different cadence (and the
bundle / build-script reshuffles upstream does each minor release tend
to break their automated updater). The in-tree derivation under
`home/development/gemini-cli/` is intentionally a thin fork of the
nixpkgs packaging pattern, pinned ahead of nixpkgs's lag. This command
keeps that lead intact without forcing the user to remember the
`nix-prefetch-github` + hash-harvest dance.
