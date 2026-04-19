# Update Claude Code / Claude Desktop

Two packages, two sources, two workflows — both start here. Default to
**claude-code** if the user's message doesn't disambiguate.

| Package | Source | Enabled on | Update target |
|---|---|---|---|
| `claude-code` (CLI) | Anthropic GCS binary channel | p620, razer, p510 | `pkgs/claude-code-native/default.nix` |
| `claude-desktop` (Electron app) | `aaddrick/claude-desktop-debian` flake input | **razer + p620 only** (NOT p510 — headless server) | `flake.nix` input URL |

Which package? Ask yourself:

- User said "claude-code", `claude`, "CLI" → **claude-code** section.
- User said "claude-desktop", "desktop", "GUI" → **claude-desktop** section.
- User passed a version like `2.1.114` → claude-code (matches 2.x).
- User passed a version like `v1.3.32` → claude-desktop (matches the aaddrick tag format).

If still ambiguous, **ask**. Do NOT bump both blindly — each has its own risk surface.

---

## A. Update `claude-code` (the CLI)

Tracks Anthropic's GCS distribution, not npm. Immune to npm-side refactors
like the 2.1.113 optionalDependencies split.

### Prerequisites

- [ ] `git status` clean (or know what's dirty and why)
- [ ] `gh auth status` OK
- [ ] Current `claude --version` captured for the commit body

### Steps

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

### Rollback

- `sudo nixos-rebuild switch --rollback` (per-host) OR `git revert`.

---

## B. Update `claude-desktop` (the Electron app)

Tracks `aaddrick/claude-desktop-debian` via a flake input (commit SHA, not
tag — Nix's `github:` fetcher resolves tags to commits anyway).

**Runs on razer + p620 only.** p510 is headless — don't test anything UI-ish
there.

### Prerequisites (same as A, plus:)

- [ ] Check upstream release notes for breaking changes
- [ ] Check upstream issue tracker for active regressions (especially
      cowork / `_svcLaunched` / sandbox / node-pty)
- [ ] If running claude-desktop right now, backup `~/.config/Claude`:
      ```bash
      cp -a ~/.config/Claude ~/.config/Claude.bak-$(date +%Y%m%d)
      ```

### Steps

1. **Inspect upstream.** Read BEFORE bumping:
   ```bash
   # Latest releases
   gh api repos/aaddrick/claude-desktop-debian/releases --jq '.[:5] | .[] | {tag: .tag_name, published: .published_at, body_lines: (.body | split("\n") | .[0:5])}'

   # Open issues labeled regression / critical
   gh issue list -R aaddrick/claude-desktop-debian --label "bug" --state open --limit 10

   # Commits between our pin and the candidate target
   OURS=$(jq -r '.nodes."claude-desktop-linux".locked.rev' flake.lock)
   TARGET=<tag-or-commit>
   gh api "repos/aaddrick/claude-desktop-debian/compare/$OURS...$TARGET" \
     --jq '.commits[] | "\(.sha[0:8]) \(.commit.message | split("\n")[0])"'
   ```

   **Red flags to stop on:**
   - `_svcLaunched` still in open issues → Cowork daemon recovery broken
   - Recent `build.sh` changes → our overlay's sed pattern may miss
   - New `optionalDependencies` changes in claude npm → may require overlay rework

2. **Resolve target → commit SHA.**
   ```bash
   TAG=v1.3.32+claude1.3109.0                       # pick from releases list
   TARGET=$(gh api "repos/aaddrick/claude-desktop-debian/git/ref/tags/$TAG" --jq '.object.sha')
   echo "Will pin to: $TARGET"
   ```
   Or, if tracking `main` HEAD (for post-release fixes):
   ```bash
   TARGET=$(gh api repos/aaddrick/claude-desktop-debian/commits/main --jq '.sha')
   ```

3. **Edit `flake.nix`** — update the input URL AND its comment so future-you
   knows what tag this SHA corresponds to:
   ```nix
   # = tag v1.3.32+claude1.3109.0 (2026-04-17) [or: main @ 4cc6cc21 (2026-04-19)]
   claude-desktop-linux.url = "github:aaddrick/claude-desktop-debian/<TARGET>";
   ```

4. **Lock + sanity-eval.**
   ```bash
   nix flake lock --update-input claude-desktop-linux
   # Confirm the resolved rev
   jq -r '.nodes."claude-desktop-linux".locked | "rev: \(.rev[0:10])\ndate: \(.lastModified | todate)"' flake.lock
   ```

5. **Verify our overlay's sed pattern still matches upstream build.sh.**
   ```bash
   SRC=$(nix build --print-out-paths --no-link ".#inputs.claude-desktop-linux.outPath" 2>/dev/null \
         || jq -r '.nodes."claude-desktop-linux".locked | "github:\(.owner)/\(.repo)/\(.rev)"' flake.lock \
         | xargs -I{} nix eval --raw "{}" --apply 'x: x' 2>/dev/null)
   grep -c 'Copying node-pty native binaries to unpacked directory' "$SRC/build.sh"
   # Must be exactly 1. If 0, upstream finally removed it → remove our sed.
   # If >1, sed may match more than intended → investigate.
   ```

6. **Build + verify the asar is correctly packed.**
   ```bash
   # Build the FHS wrapper (exposed via nixosConfigurations.razer.pkgs)
   FHS=$(nix build --no-link --print-out-paths '.#nixosConfigurations.razer.pkgs.claude-desktop-linux')
   INNER=$(nix-store -qR "$FHS" | grep -E "claude-desktop-1\.[0-9]" | head -1)
   echo "Inner: $(basename $INNER)"

   # Linux pty.node is an ELF and present in .unpacked/
   PTY="$INNER/lib/claude-desktop/electron/resources/app.asar.unpacked/node_modules/node-pty/build/Release/pty.node"
   file "$PTY" | grep -q ELF && echo "OK: pty.node is ELF" || echo "FAIL: not ELF"
   ```

7. **Host matrix.** claude-desktop only runs on razer + p620; p510 still
   needs to BUILD (it's in the closure via overlay) but won't install UI.
   ```bash
   for h in p620 razer p510; do
     nix build --no-link .#nixosConfigurations.$h.config.system.build.toplevel
   done
   ```

8. **Issue / branch / commit / PR.** Same pattern as claude-code.
   Branch naming: `feat/<N>-claude-desktop-<tag>`.

9. **Deploy — razer first** (primary claude-desktop host):
   ```bash
   ssh razer 'cd ~/.config/nixos && git pull && sudo nixos-rebuild switch --flake .#razer'
   # Verify on razer:
   ssh razer 'pgrep -af "claude-desktop-1\.[0-9]"'
   ```
   Then p620 (user confirmation on timing — desktop requires quit-and-relaunch
   to pick up the new binary; see "Idiot-proofing" below).

### Idiot-proofing (READ BEFORE DEPLOY)

- **claude-desktop is usually RUNNING** when you deploy. `nixos-rebuild
  switch` activates the new generation but the existing Electron processes
  keep running from the OLD store path until killed.
- To use the new version: `pkill -f claude-desktop` then relaunch from app
  menu. Warn the user before doing this — they'll lose in-flight state.
- Always check the post-deploy process tree:
  ```bash
  ssh razer 'pgrep -af "claude-desktop-1\.[0-9]" | head -3'
  # Should show the NEW inner hash. If OLD hash → user hasn't restarted.
  ```
- `~/.config/Claude/vm_bundles/` state is version-sensitive. After a major
  bump (e.g. claude binary 1.2278→1.3109, ~800 version advance), a stale
  bundle can cause "VM service not running" — see upstream issue #408.
  First thing to try after a failed launch: `rm -rf ~/.config/Claude/vm_bundles/`
  and relaunch.

### Rollback

- `sudo nixos-rebuild switch --rollback` OR `git revert` + redeploy.

---

## Anti-patterns to avoid

- ❌ Do NOT bump both packages in one PR. Each has different release cadence
  and risk surface.
- ❌ Do NOT assume "upstream fixed our overlay's bug → remove overlay". Verify
  the specific fix landed in a reachable tag AND that no NEW bug replaces it
  (e.g. v1.3.32 fixed the asar manifest, but introduced the read-only
  `.unpacked/` cp regression we now patch).
- ❌ Do NOT deploy to razer while the user has claude-desktop running unless
  they've explicitly OK'd the pkill. Loss of in-flight state is user-facing.
- ❌ Do NOT skip the 'grep -c "Copying node-pty native binaries"' check in
  step B5 — if upstream removes that block, our sed becomes a silent no-op
  and a subtly-broken build could land.

## Related files

- `pkgs/claude-code-native/default.nix` — claude-code package
- `scripts/update-claude-code-native.sh` — claude-code prefetch helper
- `flake.nix` — `inputs.claude-desktop-linux` (pin) + claude-desktop overlay
- `home/default.nix` — `programs.claude-code.package = pkgs.claude-code-native;`
- `.github/workflows/claude-code-watch.yml` — watcher for claude-code
- `.github/workflows/claude-desktop-watch.yml` — watcher for claude-desktop

## Watchers

Both workflows run hourly. They compare upstream HEAD against the version
pinned in the repo. When drift is detected they open a deduped issue with
the appropriate label (`claude-code-update` or `claude-desktop-update`).
This command handles both — just follow the relevant section.
