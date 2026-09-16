---
status: draft
issue: 1851
spec: spec/2026-09-16-1851-opencode-from-nixpkgs.md
---

# Plan: opencode comes from nixpkgs, not a vendored derivation

Branch `fix/1851-opencode-from-nixpkgs` (worktree `../nixos-1851`, off
`origin/main`). Hosts are p620 and razer. p510 is evaluated only.

## Approved decisions

**D1.** opencode comes from `pkgs.opencode` (1.18.30) listed in
`home.packages`, not from nixarchy's app list and not from a vendored
derivation.

**D2. Three edits, all deletions except one line:**

- `home/default.nix:72`:
  `inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode` →
  `pkgs.opencode`, with a comment naming #1851.
- `flake.nix:507`: delete the `opencode = pkgs.callPackage …` entry.
- delete `home/development/opencode/`.

**D3. The vendored wrapper is dropped deliberately.** nixpkgs already wraps
the binary (PATH for ripgrep and friends), and 1.18.30 takes the current
directory on its own, so the `LD_LIBRARY_PATH` prefix and the
"default to `.`" shim are both unnecessary.

**D4. Established before implementation** (isolated XDG dirs, real state
untouched): 1.18.30 starts with no `ERR_MODULE_NOT_FOUND`, fetches the scoped
plugin `@dietrichgebert/ponytail@latest`, and reads the existing
`~/.config/opencode/opencode.json` unchanged. The `a.name` error seen in that
test also occurs with the plugin removed, so it is the isolated run's missing
credentials, not this change.

**D5. User state is not managed by Nix.** `~/.config/opencode` and
`~/.local/share/opencode` stay as they are. The session store may migrate
one way on first run, so it is backed up first.

**D6. Rejected:** bumping the vendored derivation, nixarchy's app list,
`programs.nixarchy.localAi`, an overlay pin.

## Steps

1. **`home/default.nix`:** the one-line swap plus comment (D2).
   → verify: `nix eval .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.packages`
   contains an `opencode-1.18.30` store path.
2. **`flake.nix`:** delete the package entry; **`git rm -r
   home/development/opencode`** (D2).
   → verify: `grep -rn "development/opencode" .` finds nothing (outside
   `intent/`, `spec/`, `plan/`), and
   `nix eval .#packages.x86_64-linux.opencode` fails with "attribute missing".
3. **Commit** 1–2 as
   `fix(opencode): use pkgs.opencode 1.18.30, drop the vendored 0.5.13 derivation (#1851)`.
   → verify: pre-commit hooks pass.
4. **Build:** confirm the branch carries everything on `origin/main` (merge if
   not), then `just check-syntax`, `just test-host p620`, `just test-host
   razer`, and evaluate p510's `home.packages` (evaluation only).
   → verify: all succeed.
5. **Back up the session store on both hosts** before any 1.18.30 run:
   `cp -a ~/.local/share/opencode ~/.local/share/opencode.bak-0.5.13-$(date +%F)`
   (D5).
   → verify: the copy exists on each host.
6. **Deploy:** read the bus and post first (mention that new OpenCode launches
   jump 0.5.13 → 1.18.30), then `just quick-deploy p620` and
   `just deploy-via-p620 razer` with `AGENT_BUS_ANNOUNCED=1`.
   → verify: no failed units, `home-manager-olafkfreund` active on both.
7. **Run the tests below.**
8. **Push and open a PR** linking the intent, spec and plan, with
   `Closes #1851`; merge once CI is green.

## Tests

| # | Command | Expected |
| --- | --- | --- |
| T1 | Step 4 builds and the p510 eval | Pass |
| T2 | `grep -rn "development/opencode" .` (excluding artifacts); `nix eval .#packages.x86_64-linux.opencode` | No hits; attribute missing |
| T3 | Both hosts: `opencode --version`; `readlink -f $(command -v opencode)` | `1.18.30`; a store path containing `opencode-1.18.30` |
| T4 | p620, in `~/.config/nixos`: `opencode run "reply ok"`, then read the newest `~/.local/share/opencode/log/*.log` | No "Unexpected error" banner and no `ERR_MODULE_NOT_FOUND`. A provider/credit error is acceptable |
| T5 | `ls ~/.cache/opencode/packages/@dietrichgebert/` after T4 | `ponytail@latest` present |
| T6 | `jq -r '.autoupdate, (.mcp\|keys\|length)' ~/.config/opencode/opencode.json` | `false` and the same MCP count as before (8 at the time of writing) |

## Rollback

- **Before merge:** close the PR and redeploy both hosts from `main`.
- **After merge:** `git revert` the step-3 commit and redeploy. That brings
  back the vendored 0.5.13 — which is the broken version, so this is a last
  resort.
- **Session store:** if 1.18.30 migrated it badly,
  `rm -rf ~/.local/share/opencode && mv ~/.local/share/opencode.bak-0.5.13-<date> ~/.local/share/opencode`.
- **Immediate:** `sudo nixos-rebuild switch --rollback` on the affected host.
