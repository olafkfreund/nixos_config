# Update Claude Code (native binary)

Update the `claude-code-native` package to a given version (or `latest` /
`stable` channel). This tracks Anthropic's official GCS distribution, not
the npm registry — so it's **immune to the npm-side packaging refactors**
(e.g. the 2.1.113 optionalDependencies split) that break `buildNpmPackage`.

The npm-based `home/development/claude-code/` derivation is **deprecated**
and may be removed in a follow-up chore.

## When to invoke

- When the claude-code watcher opens a "new version available" issue
  (label: `claude-code-update`).
- On explicit request: `/update-claude-code 2.1.114` or `/update-claude-code latest`.

## Prerequisites

- [ ] `git status` clean (no unrelated dirty files that would land in the PR)
- [ ] `gh auth status` OK
- [ ] Current `claude --version` (for the commit body): `claude --version`

## Step 1 — Pick the version

```bash
# Show both channels, do nothing
./scripts/update-claude-code-native.sh
# → Channels:
#     stable  = 2.1.98
#     latest  = 2.1.114
```

If the user passed an arg to the command, use that. Otherwise default to
**`latest`** — that's the channel this infra tracks per policy decision
2026-04-18. If you have a reason to pick `stable` instead, tell the user
before doing it.

## Step 2 — Fetch hashes and preview Nix snippet

```bash
./scripts/update-claude-code-native.sh <version>   # e.g. 2.1.114 or latest
```

The script:
- Resolves `latest`/`stable` → concrete version
- Prefetches both Linux binaries (x86_64 + aarch64) via `nix store prefetch-file`
- Prints SRI hashes and a ready-to-paste Nix snippet
- **Does NOT edit any file** — it's read-only

Capture the script output. You need exactly three values:
- `version`
- x86_64-linux `hash`
- aarch64-linux `hash`

## Step 3 — Edit `pkgs/claude-code-native/default.nix`

Update three lines:

```nix
  version = "<NEW_VERSION>";
  ...
  sources = {
    x86_64-linux = {
      url = "${gcs_bucket}/${version}/linux-x64/claude";
      hash = "<NEW_X64_HASH>";
    };
    aarch64-linux = {
      url = "${gcs_bucket}/${version}/linux-arm64/claude";
      hash = "<NEW_ARM64_HASH>";
    };
  };
```

**Do NOT change anything else** in the derivation.

## Step 4 — Build and sanity-check

```bash
nix build --no-link --print-out-paths .#claude-code-native
# Take the printed path, verify:
$(nix build --no-link --print-out-paths .#claude-code-native)/bin/claude --version
# → 2.1.114 (Claude Code)

ldd $(nix build --no-link --print-out-paths .#claude-code-native)/bin/claude \
  | grep -E "not found|missing" && echo "MISSING LIBS" || echo "libs OK"
```

If `--version` mismatches the target, abort and re-check the hash.

## Step 5 — Full host build matrix

```bash
# Parallel. Any failure → stop; fix before proceeding.
just quick-test   # builds all 3 host closures
# OR individually:
nix build --no-link .#nixosConfigurations.p620.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.razer.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.p510.config.system.build.toplevel
```

## Step 6 — Issue → branch → commit → PR

```bash
# Check for an existing auto-opened watcher issue first.
gh issue list -l claude-code-update --search "$VERSION" --state open

# If an issue exists, reference it as $ISSUE. If not, create one:
gh issue create \
  --label claude-code-update \
  --title "chore(claude-code): update to $VERSION" \
  --body "Bump claude-code-native from <OLD> to $VERSION.

Source: https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/$VERSION/manifest.json
Release notes: https://github.com/anthropics/claude-code/releases/tag/v$VERSION"

# Standard issue-driven flow
git checkout -b chore/<ISSUE>-claude-code-$VERSION
git add pkgs/claude-code-native/default.nix
git commit -m "chore(claude-code): update to $VERSION (#$ISSUE)

Bump claude-code-native from <OLD> to $VERSION via the GCS
distribution channel (\`latest\`).

- x86_64-linux hash refreshed
- aarch64-linux hash refreshed
- Verified: claude --version = $VERSION
- Built all 3 host closures

Closes #$ISSUE

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"

git push -u origin chore/<ISSUE>-claude-code-$VERSION
gh pr create --fill
gh pr merge --squash --delete-branch
```

If pre-commit hook hangs on statix (established precedent), use
`git commit --no-verify` — this project has that as a known workaround.

## Step 7 — Deploy

```bash
# Local host (p620)
sudo nixos-rebuild switch --flake ~/.config/nixos#p620

# Remote hosts (SSH aliases in ~/.ssh/config)
ssh razer 'cd ~/.config/nixos && git pull && sudo nixos-rebuild switch --flake .#razer'
ssh p510  'cd ~/.config/nixos && git pull && sudo nixos-rebuild switch --flake .#p510'

# Verify each
for h in "" razer p510; do
  out=$( [ -z "$h" ] && claude --version || ssh "$h" claude --version )
  echo "${h:-local}: $out"
done
```

## Rollback

```bash
# Option A: revert the commit, re-deploy
git revert <COMMIT_SHA>
git push

# Option B: NixOS generation rollback (no git change)
sudo nixos-rebuild switch --rollback
```

## Anti-patterns to avoid

- ❌ Do NOT use `buildNpmPackage` — that's the deprecated path. Upstream
  npm packaging changes (e.g. 2.1.113) will silently break your build.
- ❌ Do NOT hand-compute hashes with `nix-prefetch-url` — use the script
  (`nix store prefetch-file` is the modern, authenticated route).
- ❌ Do NOT commit without running `claude --version` on the built binary.
  A wrong hash produces a valid but stale binary.
- ❌ Do NOT skip host builds. The 2 minutes you save loses 2 hours if
  razer's NVIDIA stack regresses against the new binary.

## Related files

- `pkgs/claude-code-native/default.nix` — the package
- `scripts/update-claude-code-native.sh` — the prefetch helper
- `home/default.nix` — `programs.claude-code.package = pkgs.claude-code-native;`
- `.github/workflows/claude-code-watch.yml` — hourly watcher that opens
  issues when `/latest` advances
