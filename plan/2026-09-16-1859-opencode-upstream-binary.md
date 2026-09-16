---
status: approved
issue: 1859
spec: spec/2026-09-16-1859-opencode-upstream-binary.md
---

# Plan: a working opencode, from upstream's own binary

Branch `fix/1859-opencode-upstream-binary` (worktree `../nixos-1859`, off
`origin/main`). Hosts are p620 and razer. p510 installs no opencode.

## Approved decisions

**D1.** opencode is upstream's official `opencode-linux-x64.tar.gz` **1.18.31**,
hash `sha256-6TEr517YA7dBX8Kuq9ofT+k4kSo5Zzdi3Aw4wOEeveQ=`, packaged as
`pkgs/opencode-bin/`. `pkgs.opencode` (nixpkgs 1.18.30) is unusable:
nixpkgs#563241, a bun 1.4.2 build bug, kills every prompt with
`TypeError: undefined is not an object (evaluating 'a.name')` in
`SystemPrompt.environment`.

**D2. Temporary by construction.** The derivation's header names
nixpkgs#563241 and the exit condition: delete this package when
`nix eval --raw nixpkgs#opencode.version` is >= 1.18.31.

**D3. Wiring:** `flake.nix` gains
`opencode-bin = pkgs.callPackage ./pkgs/opencode-bin { };`, and
`home/default.nix` uses
`inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-bin`, so the
`inputs` argument dropped in #1851 returns.

**D4. No wrapper, no overlay, no DB juggling:** the binary needs no
`LD_LIBRARY_PATH`, the user's config already sets `autoupdate: false`, and an
overlay on `pkgs.opencode` would cost cache hits elsewhere. Sessions stay in
`opencode.db`, which 1.18.30 already created under #1851.

**D5. Rejected:** patching the nixpkgs build, waiting for nixpkgs, pinning an
older nixpkgs, vendoring 1.18.30 instead of 1.18.31.

## Steps

1. **`pkgs/opencode-bin/default.nix`** (new): `stdenvNoCC.mkDerivation` with
   `fetchurl` (D1), `dontPatchELF`, `installPhase` installing the single
   `opencode` file to `$out/bin/opencode`, `meta.mainProgram`,
   `platforms = [ "x86_64-linux" ]`, MIT, plus the header comment from D2.
   → verify: `nix build .#opencode-bin` succeeds and
   `result/bin/opencode --version` prints `1.18.31`.
2. **`flake.nix`:** add the `opencode-bin` package entry (D3).
   → verify: `nix eval .#packages.x86_64-linux.opencode-bin.name`.
3. **`home/default.nix`:** use the new package; restore the `inputs`
   argument; comment the #1851 → #1859 history.
   → verify: the p620 home-packages evaluation lists an `opencode-1.18.31`
   store path and no `opencode-1.18.30`.
4. **Commit** 1–3 as
   `fix(opencode): run upstream 1.18.31 binary, nixpkgs 1.18.30 is broken (#1859)`.
   → verify: pre-commit hooks pass.
5. **Build:** branch current with `origin/main` (merge if not), then
   `just check-syntax`, `just test-host p620`, `just test-host razer`, and a
   p510 evaluation.
   → verify: all succeed.
6. **Deploy:** read the bus and post first, then `just quick-deploy p620` and
   `just deploy-via-p620 razer` with `AGENT_BUS_ANNOUNCED=1`.
   → verify: no failed units, `home-manager-olafkfreund` active on both.
7. **Run the tests below.** T3 is the one that matters: a real prompt must
   work.
8. **Push, open a PR** linking the three artifacts with `Closes #1859`, merge
   when CI is green. Comment on nixpkgs#563241 only if we have something new
   to add; otherwise leave it.

## Tests

| # | Command | Expected |
| --- | --- | --- |
| T1 | Step 5 builds and the p510 eval | Pass |
| T2 | Both hosts: `opencode --version`; `readlink -f $(command -v opencode)` | `1.18.31`; a store path from `opencode-bin` |
| T3 | Both hosts, in a scratch directory: `opencode run "reply with the word ok"` | A model answer, or a plain provider error. **No** "Unexpected server error" and **no** `evaluating 'a.name'` in the newest log |
| T4 | After T3 on p620: `ls ~/.cache/opencode/packages/@dietrichgebert/` | `ponytail@latest` present; no `ERR_MODULE_NOT_FOUND` in the log |
| T5 | `grep -rn "pkgs.opencode" .` outside `intent/ spec/ plan/` | No hits |
| T6 | `nix eval --raw nixpkgs#opencode.version` | Still `1.18.30` today; when it is >= 1.18.31, delete `pkgs/opencode-bin` |

## Rollback

- **Before merge:** close the PR and redeploy both hosts from `main`.
- **After merge:** `git revert` the step-4 commit and redeploy. That returns
  `pkgs.opencode` 1.18.30, which starts but cannot run a prompt, so it is a
  last resort.
- **Session state:** the #1851 backups
  (`~/.local/share/opencode.bak-0.5.13-2026-09-16`) are still on both hosts.
- **Immediate:** `sudo nixos-rebuild switch --rollback`.
