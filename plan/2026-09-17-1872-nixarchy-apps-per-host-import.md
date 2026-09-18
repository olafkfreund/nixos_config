---
status: approved
issue: 1872
spec: spec/2026-09-17-1872-nixarchy-apps-per-host-import.md
---

# Plan: read the nixarchy selection from the file apply writes

Each host imports `hosts/<host>/nixarchy-apps.nix`, the file `nixarchy-apply`
writes for it; the flake-root copy is deleted. p510 moves with the others and
loses `dictation` deliberately. `t3-code` stays uninstalled. The guard is a
comment, not a CI check. The nixarchy input bump is a separate commit.

## Steps

1. razer `~/.config/nixarchy/apps.nix`: repair the two malformed `# @` markers
   to `#@`, and return `t3-code` to its commented template line
   → verify by `grep -c "# @ "` returning 0 and the active set being `dictation`
   alone.
2. `hosts/{p620,razer,p510}/nixarchy/{apps,services,advanced}.nix`: copy from
   each host's `~/.config/nixarchy/` → verify by per-host active selection
   matching the intent's table.
3. `hosts/{p620,razer,p510}/nixarchy-apps.nix`: write apply's stub verbatim
   → verify each is 252 bytes and imports the three modules.
4. `hosts/{p620,razer,p510}/nixos/nixarchy.nix`: import `../nixarchy-apps.nix`
   in place of `../../../nixarchy-apps.nix`, and replace the comment above
   `imports` with one describing the per-host layout and naming #1872
   → verify by grep that no `../../../nixarchy-apps.nix` remains.
5. Delete the root `nixarchy-apps.nix` → verify by `git status`.
6. Build-test → see Tests.

## Deviations from the spec

- Step 1 **comments out** `t3-code` in its template form rather than deleting
  the line, as intent Decisions §4 worded it. Same outcome — uninstalled — but
  the Omarchy menu can still toggle it, which a deleted line would prevent.

## Tests

```bash
# per-host selection reaches the build
nix eval --raw .#nixosConfigurations.<host>.config.programs.nixarchy.apps \
  --apply 'a: builtins.concatStringsSep "," (builtins.filter (n: (a.${n}.enable or false)) (builtins.attrNames a))'
# expected: p620 "brave,dictation"   razer "dictation"   p510 ""

just test-host p620          # expected: builds
just test-host razer         # expected: builds
# p510: evaluation only, never built or deployed here
```

## Rollback

`git revert` the implementation commit. The root `nixarchy-apps.nix` returns and
the three hosts point back at it; the per-host files become inert rather than
harmful. razer's `~/.config/nixarchy/apps.nix` is not in git — its pre-edit copy
is kept beside it as `apps.nix.bak.<epoch>` on razer.
