# Update Claude Code / Claude Desktop

Two packages, two sources, two workflows — both start here. Default to
**claude-code** if the user's message doesn't disambiguate.

| Package | Source | Enabled on | Update target |
|---|---|---|---|
| `claude-code` (CLI) | Anthropic GCS binary channel | **p620 + razer only** (p510 doesn't ship it; package not in its closure) | `pkgs/claude-code-native/default.nix` |
| `claude-desktop` (Electron app) | Anthropic's signed apt repo (`downloads.claude.ai`), packaged locally | **razer + p620 only** (p510 must still build it) | `pkgs/claude-desktop-beta/default.nix` |

Which package? Ask yourself:

- User said "claude-code", `claude`, "CLI" → **claude-code** section.
- User said "claude-desktop", "desktop", "GUI" → **claude-desktop** section.
- User passed a version like `2.1.114` → claude-code (matches 2.x).
- User passed a version like `1.24012.9` → claude-desktop (5-digit middle component).

If still ambiguous, **ask**. Do NOT bump both blindly — each has its own risk surface.

---

## A. Update `claude-code` (the CLI)

Tracks Anthropic's GCS distribution, not npm. Immune to npm-side refactors
like the 2.1.113 optionalDependencies split.

### Prerequisites

- [ ] `git status` clean (or know what's dirty and why)
- [ ] `gh auth status` OK
- [ ] Current `claude --version` captured for the commit body

### Steps (claude-code)

1. **Pick the version.**

   ```bash
   ./scripts/update-claude-code-native.sh           # just show channels
   ./scripts/update-claude-code-native.sh latest    # shorthand
   ./scripts/update-claude-code-native.sh 2.1.114   # explicit
   ```

   Default is `latest`. The script prints SRI hashes + a ready-to-paste Nix
   snippet. It does NOT edit files.

2. **Edit `pkgs/claude-code-native/default.nix`** — three lines only:

   ```nix
   version = "<NEW>";
   ...
   sources.x86_64-linux.hash = "<NEW_X64_HASH>";
   sources.aarch64-linux.hash = "<NEW_ARM64_HASH>";
   ```

   Nothing else.

3. **Build + sanity.**

   ```bash
   OUT=$(nix build --no-link --print-out-paths .#claude-code-native)
   $OUT/bin/claude --version          # must match target
   ldd $OUT/bin/claude | grep -i "not found" && echo "MISSING LIBS" || echo "libs OK"
   ```

4. **Host matrix.** Any failure → stop.

   ```bash
   for h in p620 razer p510; do
     nix build --no-link .#nixosConfigurations.$h.config.system.build.toplevel
   done
   ```

5. **Issue / branch / commit / PR.** If watcher `claude-code-update` issue
   exists, reference it as `$ISSUE`. Otherwise create one. Use
   `git commit --no-verify` (pre-commit statix hook hangs — established
   workaround).

6. **Deploy.** p620 = local; razer/p510 = via SSH.

### Rollback (claude-code)

- `sudo nixos-rebuild switch --rollback` (per-host) OR `git revert`.

---

## B. Update `claude-desktop` (the Electron app)

Packaged **locally** from Anthropic's official signed `.deb`
(`pkgs/claude-desktop-beta/default.nix`, exposed as `pkgs.claude-desktop-linux`
via `overlays/default.nix`). Bumping it means editing `version` + `sha256` in
that file — there is no flake input to update.

> **History:** until #986 this tracked the `aaddrick/claude-desktop-debian`
> Windows-repackage via a flake input, and this section described bumping that
> input, patching `build.sh` with sed, and verifying asar packing. **That input
> was removed and none of those steps exist any more.** If you find yourself
> looking for `inputs.claude-desktop-linux` in `flake.nix`, you are following a
> stale copy of this document.

**Runs on razer + p620 only.** p510 still evaluates it in its closure (the
overlay is global) so it must build there, but installs no UI.

### Prerequisites (same as A, plus:)

- [ ] Note whether claude-desktop is **currently running** — see the deploy
      caveat below.
- [ ] If it is running and this is a large version jump, consider backing up
      `~/.config/Claude` first.

```bash
pgrep -af "claude-desktop" | head -1
cp -a ~/.config/Claude ~/.config/Claude.bak-$(date +%Y%m%d)   # optional
```

### Steps (claude-desktop)

1. **Find the newest version + SHA256 in the apt index.**

   ```bash
   curl -fsSL https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages \
     -o /tmp/pkgs.idx
   awk '/^Version:/{v=$2} /^SHA256:/{print v" "$2}' /tmp/pkgs.idx | sort -V -r | head -3
   ```

   **`sort -V` is mandatory.** The index holds every historical release in no
   meaningful order — the first entries returned are `1.17xxx`, i.e. *older*
   than what is already pinned. Reading it top-down downgrades the package.

   Compare against the current pin:

   ```bash
   grep -oP '^\s*version = "\K[^"]+' pkgs/claude-desktop-beta/default.nix
   ```

2. **Edit `pkgs/claude-desktop-beta/default.nix`** — two lines only:

   ```nix
   version = "<NEW>";
   ...
   sha256 = "<HEX_FROM_INDEX>";
   ```

   The index gives a **hex** SHA256 and `fetchurl` accepts it as-is. Do not
   convert it to SRI. The `url` is templated on `${version}` and needs no edit.

3. **Build + sanity.**

   ```bash
   OUT=$(nix build --no-link --print-out-paths '.#nixosConfigurations.p620.pkgs.claude-desktop-linux')
   ls "$OUT/bin"                                   # expect: claude-desktop
   find "$OUT" -name '*.so' | head -1 | xargs ldd | grep -c "not found"   # expect: 0
   ```

   A hash mismatch here means the index moved under you — re-read it, do not
   hand-edit the hash nix reports without checking which version it belongs to.

4. **Host matrix.** Any failure → stop.

   ```bash
   for h in p620 razer p510; do
     nix build --no-link .#nixosConfigurations.$h.config.system.build.toplevel
   done
   ```

5. **Issue / branch / commit / PR.** If the watcher opened a tracking issue,
   close it from the commit. Branch: `chore/<N>-claude-desktop-<version>`.
   Use `git commit --no-verify` (pre-commit statix hook hangs).

6. **Deploy — the host NOT running claude-desktop first**, then the other.

   ```bash
   ssh razer 'cd ~/.config/nixos && git pull --ff-only && sudo nixos-rebuild switch --flake .#razer'
   sudo nixos-rebuild switch --flake .#p620
   ```

7. **Verify installed vs running.** These differ on purpose if the app was open:

   ```bash
   readlink -f "$(command -v claude-desktop)" | grep -oE "claude-desktop-[0-9.]+"   # installed
   pgrep -af "claude-desktop" | head -1 | grep -oE "claude-desktop-[0-9.]+"         # running
   ```

### Idiot-proofing (READ BEFORE DEPLOY)

- **claude-desktop is usually RUNNING** when you deploy. `nixos-rebuild switch`
  activates the new generation, but the live Electron process keeps executing
  from the OLD store path until it is quit and relaunched. This is expected,
  not a failed deploy.
- **Do NOT `pkill` it to "finish" the upgrade** unless the user has explicitly
  agreed. They lose in-flight conversation state. Report the installed-vs-
  running mismatch and let them relaunch when convenient.
- `~/.config/Claude/vm_bundles/` is version-sensitive. After a large jump a
  stale bundle can cause "VM service not running". First remedy after a failed
  launch: `rm -rf ~/.config/Claude/vm_bundles/` and relaunch.
- Version numbers move in large increments (e.g. `1.22209.3` -> `1.24012.9`);
  a jump of hundreds in the middle component is normal, not a red flag by
  itself, but is worth watching after deploy.

### Rollback (claude-desktop)

- `sudo nixos-rebuild switch --rollback` OR `git revert` + redeploy.

---

## Anti-patterns to avoid

- ❌ Do NOT bump both packages in one PR. Each has different release cadence
  and risk surface.
- ❌ Do NOT read the apt Packages index top-down. It lists every historical
  release unsorted and the first entries are OLDER than the current pin —
  always `sort -V`.
- ❌ Do NOT deploy to razer while the user has claude-desktop running unless
  they've explicitly OK'd the pkill. Loss of in-flight state is user-facing.
- ❌ Do NOT convert the index's hex SHA256 to SRI. `fetchurl` in this package
  takes `sha256 = "<hex>"` as-is.
- ❌ Do NOT follow any instruction mentioning `aaddrick`, `build.sh` sed
  patterns or asar verification — that packaging was removed in #986.

## Related files

- `pkgs/claude-code-native/default.nix` — claude-code package
- `scripts/update-claude-code-native.sh` — claude-code prefetch helper
- `pkgs/claude-desktop-beta/default.nix` — claude-desktop package (version + sha256)
- `overlays/default.nix` — exposes it as `pkgs.claude-desktop-linux`
- `home/default.nix` — `programs.claude-code.package = pkgs.claude-code-native;`
- `.github/workflows/claude-code-watch.yml` — watcher for claude-code
- `.github/workflows/claude-desktop-watch.yml` — watcher for claude-desktop

## Watchers

Both workflows run hourly. They compare upstream HEAD against the version
pinned in the repo. When drift is detected they open a deduped issue with
the appropriate label (`claude-code-update` or `claude-desktop-update`).
This command handles both — just follow the relevant section.
