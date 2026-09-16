---
status: approved
issue: 1859
intent: intent/2026-09-16-1859-opencode-upstream-binary.md
---

# Spec: a working opencode, from upstream's own binary

## Design

### `pkgs/opencode-bin/default.nix` (new)

A small `stdenvNoCC.mkDerivation` around upstream's release tarball, in the
style of `pkgs/claude-code-native`:

- `src = fetchurl` of
  `https://github.com/sst/opencode/releases/download/v1.18.31/opencode-linux-x64.tar.gz`,
  hash `sha256-6TEr517YA7dBX8Kuq9ofT+k4kSo5Zzdi3Aw4wOEeveQ=` (computed with
  `nix hash file --sri`).
- `installPhase`: `install -Dm755 opencode $out/bin/opencode`. The tarball
  holds a single `opencode` file.
- The binary is a bun single-file executable and is **not** patchelf'd
  (`dontPatchELF`), the same as the old vendored derivation and as upstream's
  own distribution. It was run directly from a temp directory on p620 and
  worked, so no interpreter or library patching is needed.
- `passthru.updateScript` is deliberately omitted: this package is meant to
  be deleted, not maintained.
- The file's header comment carries the reason (nixpkgs#563241) and the exit
  condition: delete it when `pkgs.opencode` is >= 1.18.31, i.e. when
  `nix eval nixpkgs#opencode.version` passes that mark.
- `meta.mainProgram = "opencode"`, `platforms = [ "x86_64-linux" ]`, MIT.

### Wiring

- `flake.nix`: add `opencode-bin = pkgs.callPackage ./pkgs/opencode-bin { };`
  in the same `packages` block the old entry was removed from.
- `home/default.nix`: use
  `inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-bin`
  in place of `pkgs.opencode`, which means the `inputs` argument removed in
  #1851 comes back. The comment explains both hops (#1851 → #1859) so the
  history is readable in one place.

### What is not done

- No wrapper: nothing sets `OPENCODE_DISABLE_AUTOUPDATE` (the user's config
  already has `autoupdate: false`), and no `LD_LIBRARY_PATH` prefix, which
  the old 0.5.13 derivation needed but this binary does not.
- No `OPENCODE_DB` handling. nixpkgs' wrapper forces the legacy
  `opencode-stable.db` when only that exists; upstream's binary uses
  `opencode.db`. p620 already has both files (1.18.30 created the canonical
  one under #1851), so sessions stay where 1.18.30 put them.
- No overlay over `pkgs.opencode`: an overlay on a package others depend on
  costs binary-cache hits elsewhere, and nothing else here uses opencode.

## Alternatives rejected

- **Patch the nixpkgs build** (disable bundle splitting, or apply opencode
  PR 48397 as the maintainers did): keeps a source build we do not control
  and breaks whenever nixpkgs changes its build phases.
- **Wait for nixpkgs 1.18.31:** no update PR is open, and opencode is
  unusable meanwhile.
- **Pin `pkgs.opencode` to an older nixpkgs:** 0.5.13-era builds carry the
  scoped-plugin bug from #1851, and a second nixpkgs for one package is a
  large cost.
- **Keep 1.18.30 upstream instead of 1.18.31:** both work in testing, but
  1.18.31 is the version the nixpkgs thread names as the fix, so it is the
  better default.

## Risks

| Risk | Where | Mitigation |
| --- | --- | --- |
| The binary needs libraries the store cannot provide | p620, razer | Already disproved: upstream's binary ran from a temp directory on p620 and reached the provider. envfs and the bun single-file layout make this the normal case |
| Someone re-adds `pkgs.opencode` later and silently reintroduces the bug | anywhere | The header comment names nixpkgs#563241 and the exact condition for removal |
| Session state differs between nixpkgs' wrapper (`opencode-stable.db`) and upstream (`opencode.db`) | p620, razer | p620 has both; 1.18.30 already wrote the canonical DB under #1851. razer's opencode state is 12 KB, effectively empty. Backups from #1851 still exist on both hosts |
| 1.18.31 changes behaviour versus 1.18.30 | p620, razer | One patch release apart; the verification runs a real prompt on both hosts |
| The pinned URL disappears | build time | It is a GitHub release asset with a content hash; a missing asset fails the build loudly rather than silently |

## Verification

1. **Build:** `just check-syntax`, `nix build .#opencode-bin`, `just
   test-host p620`, `just test-host razer`; p510 evaluated only.
2. **Version:** `opencode --version` → `1.18.31` on both hosts, resolving to
   a store path containing `opencode-bin` or `opencode-1.18.31`.
3. **The reported failure is gone** (p620 and razer): `opencode run "reply
   with the word ok"` prints a model answer, or a plain provider error, and
   the newest log has **no** `evaluating 'a.name'` and no "Unexpected server
   error".
4. **Plugin still loads:** `~/.cache/opencode/packages/@dietrichgebert/ponytail@latest`
   exists after that run, and the log shows no `ERR_MODULE_NOT_FOUND`.
5. **No stale references:** `grep -rn "pkgs.opencode" .` outside artifacts
   returns nothing.
6. **Exit condition is testable:** `nix eval --raw nixpkgs#opencode.version`
   still reports 1.18.30 today; when it reports >= 1.18.31 this package can
   be deleted.
