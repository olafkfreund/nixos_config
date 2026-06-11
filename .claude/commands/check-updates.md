---
description: Check our pinned flake inputs + packages against upstream and report what's ready to update
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

# Check Updates

Compare our **running configuration** (everything pinned in `flake.lock`) against
the upstream sources it tracks, then report — input by input — **what is ready to
update, how far behind we are, and what a bump would pull in**.

This command is **read-only**. It never runs `nix flake update`, never edits
`flake.lock`, and never deploys. It produces a report; bumping is a separate,
explicit step the user runs afterwards (see `docs/UPDATE-DEPLOY.md`).

> Not to be confused with the Justfile recipe also named `check-updates`
> (a validation helper). This command audits *flake input freshness and package
> version deltas*, not configuration validity.

---

## Output you should produce

A single markdown report in this shape:

```text
# Update Check — <date>

Tracking:
- nixpkgs lock: <rev>  (last bumped <date>, channel: nixos-unstable)
- NixOS release: <release>
- Inputs reviewed: <N>

## Summary

| State | Count | Meaning |
|---|---|---|
| 🟢 Up to date | … | At upstream tip — nothing to pull |
| 🔵 Update available | … | Upstream advanced — bump is a real change |
| 🟡 Stale but blocked | … | Upstream advanced but gated (e.g. channel behind master) |
| ⚪ Pinned / intentional | … | Old by design (pinned rev, archived input) |

## nixpkgs (the one that matters most)

- Our rev:        <rev> (<date>)
- nixos-unstable: <rev> (<date>)  → <identical | N commits ahead>
- master:         <rev> (<date>)  → channel is <M> commits behind master
- Verdict: <no-op | bump pulls N commits>

<If a bump would change things, list notable package version deltas for
packages WE ACTUALLY RUN — gnome-shell, ollama, docker, etc.>

## Other flake inputs

| Input | Owner/repo | Ours | Upstream tip | Behind | Ready? |
|---|---|---|---|---|---|
| home-manager | nix-community/home-manager | <sha> (<date>) | <sha> (<date>) | <N commits / n days> | 🔵 |
| …            | …                          | …              | …               | …                     | … |

## Recommended actions

- `nix flake update nixpkgs` — <only if channel advanced; else "no-op, skip">
- `nix flake update home-manager microvm` — <inputs with real deltas>
- `nhs <host> all` or `just update-commit-deploy <host> all` — full bump + test + deploy
- "No action — everything tracked is at its upstream tip"
```

---

## Process

### Step 1 — Resolve what we actually build against

```bash
# Root nixpkgs node. CRITICAL: `.nodes.nixpkgs` is usually a TRANSITIVE dep
# (agenix/home-manager's pinned nixpkgs). The input the system builds against is
# whatever root.inputs.nixpkgs points to (often `nixpkgs_<N>`). Resolve that.
NIXPKGS_NODE=$(jq -r '.nodes.root.inputs.nixpkgs' flake.lock)
OUR_REV=$(jq -r --arg n "$NIXPKGS_NODE" '.nodes[$n].locked.rev' flake.lock)
OUR_DATE=$(jq -r --arg n "$NIXPKGS_NODE" '.nodes[$n].locked.lastModified | todate' flake.lock)
echo "root nixpkgs node=$NIXPKGS_NODE rev=$OUR_REV date=$OUR_DATE"

# NixOS release identifier (sanity)
nix eval --raw .#nixosConfigurations.p620.config.system.nixos.release 2>/dev/null
```

### Step 2 — Position nixpkgs vs its channel and master

The single most important comparison. `nix flake update nixpkgs` follows the
`nixos-unstable` channel ref, NOT master. Always compare against the channel.

```bash
UNSTABLE_SHA=$(gh api repos/NixOS/nixpkgs/commits/nixos-unstable --jq '.sha')
UNSTABLE_DATE=$(gh api repos/NixOS/nixpkgs/commits/nixos-unstable --jq '.commit.committer.date')

# Are we behind the channel? (this is what a bump would actually pull)
gh api "repos/NixOS/nixpkgs/compare/$OUR_REV...$UNSTABLE_SHA" \
  --jq '{ahead_by, behind_by, total_commits, status}'

# Why might the channel be stale? Master advances continuously; nixos-unstable
# only advances when a Hydra jobset passes. Show the backlog for context.
MASTER_SHA=$(gh api repos/NixOS/nixpkgs/commits/master --jq '.sha')
gh api "repos/NixOS/nixpkgs/compare/$UNSTABLE_SHA...$MASTER_SHA" \
  --jq '{channel_behind_master_by: .ahead_by}'
```

**Interpretation:**

- `status: identical` → we ARE the channel tip. `nix flake update nixpkgs` is a
  **no-op**. Say so plainly. Do not recommend bumping nixpkgs.
- `behind_by > 0` → a bump pulls `behind_by` commits. Proceed to Step 3.
- Channel far behind master → note that desired fixes may exist on master but
  haven't cascaded; a nixpkgs bump won't get them until Hydra advances the channel.

### Step 3 — Package version deltas (only if the channel advanced)

Skip entirely if Step 2 said `identical` — there is no delta to show. Otherwise,
diff versions for the packages/subsystems WE RUN, not the whole tree:

```bash
# Packages worth diffing — tied to our enabled config + custom pkgs.
ATTRS="gnome-shell ollama docker podman incus libvirt tailscale syncthing \
       firefox mesa linux pipewire qemu_kvm plex tautulli"

for a in $ATTRS; do
  OURS=$(nix eval --raw "github:NixOS/nixpkgs/$OUR_REV#$a.version" 2>/dev/null || echo "?")
  NEW=$(nix eval --raw "github:NixOS/nixpkgs/$UNSTABLE_SHA#$a.version" 2>/dev/null || echo "?")
  [ "$OURS" != "$NEW" ] && echo "$a: $OURS → $NEW"
done
```

Only report attrs where the version actually changed. A long unchanged list is noise.

### Step 4 — All other flake inputs

For every github input, compare our pinned rev to its upstream default-branch tip.
This catches home-manager, microvm, nixos-hardware, emacs-overlay, agenix, and the
many custom inputs in `pkgs/`.

```bash
# Emit: input, owner/repo, our rev+date, our ref (branch if recorded)
jq -r '.nodes | to_entries[]
  | select(.value.locked.type == "github")
  | select(.key | test("^(nixpkgs(_[0-9]+)?|flake-utils|flake-parts|nixpkgs-lib|systems|flake-compat)") | not)
  | "\(.key)\t\(.value.locked.owner)/\(.value.locked.repo)\t\(.value.locked.rev[0:9])\t\(.value.locked.lastModified|todate)\t\(.value.original.ref // "HEAD")"' \
  flake.lock | sort -u
```

Then for the inputs that matter (anything we follow directly — check
`.nodes.root.inputs` to see which are first-class vs transitive), query upstream:

```bash
# Example for one input; loop over the first-class ones.
OWNER_REPO="nix-community/home-manager"; REF="master"; OURS_REV="<from above>"
UP=$(gh api "repos/$OWNER_REPO/commits/$REF" --jq '.sha')
gh api "repos/$OWNER_REPO/compare/$OURS_REV...$UP" --jq '{behind_by: .ahead_by, status}'
```

Prefer first-class inputs (resolve via `jq -r '.nodes.root.inputs | keys[]'`).
Skip glue inputs (flake-utils, flake-parts, nixpkgs-lib, systems) — bumping them
rarely changes anything and adds noise.

### Step 5 — Classify and recommend

| Finding | State | Recommendation |
|---|---|---|
| Our rev == channel tip | 🟢 | "No nixpkgs update — already at channel tip" |
| Channel ahead of us | 🔵 | `nix flake update nixpkgs && just test-host <hosts>` |
| Fix only on master, channel stale | 🟡 | "Wait for channel cascade, or pin overlay if blocking" |
| First-class input behind upstream | 🔵 | `nix flake update <input>` |
| Pinned/old-by-design input | ⚪ | No action (note it's intentional) |

Map host list from the repo: p620, razer, p510. Suggest the repo's idiomatic
flow rather than raw commands when a bump IS warranted:

```bash
nhs <host> all                              # update all inputs + test + commit + deploy
just update-commit-deploy <host> nixpkgs    # single-scope bump + deploy
```

---

## Required behaviors

- **Read-only.** Never run `nix flake update`, never edit `flake.lock`, never deploy.
- **Resolve the real nixpkgs node** via `.nodes.root.inputs.nixpkgs` — never read
  `.nodes.nixpkgs.locked` directly (it's usually a transitive decoy).
- **Compare nixpkgs against `nixos-unstable`, not master** — the channel ref is
  what a bump follows. Mention master only to explain channel staleness.
- **Call a no-op a no-op.** If we're at the channel tip, say "nothing to update"
  rather than padding the report.
- **Only show changed versions.** Drop attrs whose version is unchanged.
- **Show the bump command, never run it.** The user decides when to update.

## Anti-patterns to avoid

- ❌ Reading `.nodes.nixpkgs.locked` directly (transitive dep, not what we build).
- ❌ Comparing nixpkgs against master and reporting "2800 commits behind!" as if a
  bump would pull them — the channel gates that. Compare against the channel.
- ❌ `gh api` without `--paginate` for list endpoints (compare endpoints are fine).
- ❌ Recommending `nix flake update` when our rev already equals the channel tip.
- ❌ Diffing every package in nixpkgs — only the ones we actually run.
- ❌ Editing files or running deploys from this command.

## When to invoke

- Before a planned `nix flake update` — see exactly what it would change first.
- Weekly/monthly freshness check across all inputs.
- After `/check-nixos-issues` flags a fix, to confirm whether it's reachable yet.
- When deciding whether a rebuild is worth it ("has anything actually moved?").

## Documentation references

- `docs/UPDATE-DEPLOY.md` — the idiot-proof `nhs` / `update-commit-deploy` flow
- `flake.lock` — source of truth for what we pin
- `.claude/commands/check-nixos-issues.md` — companion: audits upstream *issues*
- Channel status: <https://status.nixos.org> (nixos-unstable jobset progress)
