---
description: Audit nixpkgs/NixOS GitHub issues against our config and suggest changes
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

# Check NixOS Issues

Cross-reference recent and recently-closed `NixOS/nixpkgs` and `NixOS/nixos`
GitHub issues against our pinned config, then surface concrete actions:
**update lock**, **change configuration**, **add workaround**, or **no action
needed**.

This command is **read-only** — it never edits files. It produces a ranked
report. Acting on the recommendations is a separate step.

---

## Output you should produce

A single markdown report in this shape:

```
# NixOS Issue Audit — <date>

Audited against:
- nixpkgs lock: <rev>  (last bumped <date>)
- NixOS release: <release>
- Hosts: p620, razer
- Packages reviewed: <N>
- Modules reviewed: <N>

## Summary

| Severity | Count |  Action category |
|---|---|---|
| 🔴 Critical / security | … | Update lock or disable now |
| 🟠 Regression affecting our config | … | Pin / patch |
| 🟡 Open bug we are likely to hit | … | Watch or workaround |
| 🟢 Already fixed in our lock | … | No action |

## Findings

### 🔴 #<issue> — <title>
- **Affects:** <package or module> on <host(s)>
- **Status:** open / closed (merged in <commit>, <date>)
- **Why it touches us:** <one-line explanation tying it to our enabled config>
- **Recommendation:** <update lock | edit X | open tracking issue>
- **Concrete change:**
    ```nix
    <minimal diff snippet if applicable>
    ```
- **Upstream:** https://github.com/NixOS/nixpkgs/issues/<n>

… repeat per finding, ranked by severity …

## Tracking issues to open in this repo (optional)

For each 🔴/🟠 finding the user accepts:
- `gh issue create --title "Track upstream NixOS/nixpkgs#<n>: …"`
```

---

## Process

### Step 1 — Inventory our config (5 min)

Build the list of things to match issues against. Do this once, cache the
output.

```bash
# 1. Pinned nixpkgs commit + last bump date.
#    IMPORTANT: `.nodes.nixpkgs` is usually a TRANSITIVE dep (e.g. agenix's
#    pinned nixpkgs). The flake input you actually build against is whatever
#    root.inputs.nixpkgs points to (often `nixpkgs_<N>`). Resolve that first.
NIXPKGS_NODE=$(jq -r '.nodes.root.inputs.nixpkgs' flake.lock)
jq -r --arg n "$NIXPKGS_NODE" '.nodes[$n].locked | "\(.rev)  \(.lastModified | todate)"' flake.lock

# 2. NixOS release identifier (e.g. 25.05, 25.11)
nix eval --raw .#nixosConfigurations.p620.config.system.nixos.release 2>/dev/null

# 3. Other flake inputs (anything else we follow that nixpkgs issues might affect)
jq -r '.nodes | to_entries[] | select(.value.locked.type == "github")
  | "\(.key)\t\(.value.locked.owner)/\(.value.locked.repo)@\(.value.locked.rev[0:7])\t\(.value.locked.lastModified | todate)"' flake.lock

# 4. Enabled service modules per host (the option paths that actually evaluate)
for h in p620 razer; do
  echo "=== $h ==="
  nix eval --json ".#nixosConfigurations.$h.config.services" \
    --apply 'svcs: builtins.attrNames (builtins.intersectAttrs
      (builtins.mapAttrs (_: _: null) svcs)
      (builtins.mapAttrs (n: v: v)
        (builtins.removeAttrs svcs (builtins.filter
          (n: !(builtins.tryEval (svcs.${n}.enable or false)).value
              || (svcs.${n}.enable or false) == false)
          (builtins.attrNames svcs)))))' 2>/dev/null
done

# 5. Custom packages in this repo
ls pkgs/ 2>/dev/null

# 6. System packages on each host (top-level names only — fast, useful)
for h in p620 razer; do
  echo "=== $h ==="
  nix eval --json ".#nixosConfigurations.$h.config.environment.systemPackages" \
    --apply 'ps: builtins.map (p: p.pname or p.name or "?") ps' 2>/dev/null \
    | jq -r '.[]' | sort -u | head -200
done
```

If any of these eval calls fail because of evaluation errors elsewhere, fall
back to grep-based inventory:

```bash
grep -rhE "services\.[A-Za-z0-9_-]+\.enable\s*=\s*true" hosts/ modules/ \
  | sed -E 's/.*services\.([A-Za-z0-9_-]+).*/\1/' | sort -u
```

### Step 2 — Pull issue feeds from upstream (3 min)

Use `gh api` (NOT WebFetch — `gh` is auth'd, paginates, and respects
rate limits). Pull two windows:

```bash
# Cutoff = the date our nixpkgs lock was bumped. Use ISO-8601.
# Resolve the actual root nixpkgs node (see Step 1 note re: transitive deps).
NIXPKGS_NODE=$(jq -r '.nodes.root.inputs.nixpkgs' flake.lock)
SINCE=$(jq -r --arg n "$NIXPKGS_NODE" '.nodes[$n].locked.lastModified | todate' flake.lock)
OUR_REV=$(jq -r --arg n "$NIXPKGS_NODE" '.nodes[$n].locked.rev' flake.lock)

# Recently-OPENED issues (potential new bugs we may hit)
gh api --paginate "repos/NixOS/nixpkgs/issues?state=open&since=$SINCE&per_page=100" \
  --jq '.[] | select(.pull_request == null)
  | {n: .number, t: .title, labels: [.labels[].name], created: .created_at, body_preview: (.body // "" | .[0:500])}' \
  > /tmp/nixpkgs-open-issues.jsonl

# Recently-CLOSED issues (fixes that may be in or out of our lock)
gh api --paginate "repos/NixOS/nixpkgs/issues?state=closed&since=$SINCE&per_page=100" \
  --jq '.[] | select(.pull_request == null) | select(.closed_at > "'"$SINCE"'")
  | {n: .number, t: .title, labels: [.labels[].name], closed: .closed_at, body_preview: (.body // "" | .[0:500])}' \
  > /tmp/nixpkgs-closed-issues.jsonl

# Same for NixOS/nixos (smaller, more system-config focused)
gh api --paginate "repos/NixOS/nixos/issues?state=all&since=$SINCE&per_page=100" \
  --jq '.[] | select(.pull_request == null) | {n: .number, t: .title, state: .state, updated: .updated_at}' \
  > /tmp/nixos-issues.jsonl 2>/dev/null || true
```

For really high-signal narrowing, also pull issues labeled `0.kind: regression`,
`0.kind: security`, `6.topic: security`:

```bash
for L in '0.kind: regression' '0.kind: security' '6.topic: security' 'backport'; do
  gh api --paginate "repos/NixOS/nixpkgs/issues?state=all&labels=$(printf '%s' "$L" | jq -sRr @uri)&since=$SINCE&per_page=100" \
    --jq '.[] | select(.pull_request == null) | {n: .number, t: .title, labels: [.labels[].name], state: .state, updated: .updated_at}'
done > /tmp/nixpkgs-priority.jsonl
```

### Step 3 — Match issues against our inventory

For each issue title + body preview:

1. **Direct hit**: title or body mentions a package name from our inventory
   (e.g. `claude-desktop`, `kosli-cli`, `cosmic-session`, `bubblewrap`,
   `syncthing`, `tailscale`).
2. **Module hit**: title mentions an enabled module (`services.<x>`,
   `programs.<x>`, `boot.<x>`, `virtualisation.<x>`).
3. **Subsystem hit**: title mentions a subsystem we depend on
   (`gnome`, `cosmic`, `electron`, `pipewire`, `nvidia`, `amdgpu`, `kvm`,
   `nfs`, `agenix`, `home-manager`).
4. **Hardware hit**: matches host hardware (AMD/ROCm for p620;
   Intel/NVIDIA hybrid for razer).

Prefer a deterministic regex pass over LLM-style matching at this stage —
it's cheaper and gives reproducible diffs between runs.

```bash
# Build a single regex from inventory
INVENTORY=$(cat <<'EOF' | tr '\n' '|' | sed 's/|$//'
claude-desktop
claude-code
kosli-cli
cosmic-session
cosmic-greeter
bubblewrap
socat
syncthing
tailscale
gnome-session
agenix
home-manager
electron
node-pty
EOF
)

# Surface issues that mention any of those
jq -c --arg re "$INVENTORY" 'select(.t | test($re; "i") or .body_preview | test($re; "i"))' \
  /tmp/nixpkgs-open-issues.jsonl
```

### Step 4 — Classify each match

For every match, determine:

- **State**: open (potential exposure) vs closed (potential fix already
  available)
- **For closed issues**: was the fix merged BEFORE or AFTER our
  `nixpkgs.locked.lastModified`? If after, we're not yet getting the fix.
- **For open issues**: does it look like a regression, a security issue, or
  background noise?
- **Severity**:
  - 🔴 Security advisory, data loss, or boot failure on a config we run
    AND a fix is actually shipped in a reachable nixpkgs branch (see
    "Cross-check before 🔴" below).
  - 🟠 Regression in a package/module we have enabled
  - 🟡 Open bug we may hit but haven't yet, OR known exposure with no fix
    yet merged in nixpkgs (cannot be acted on by a lock bump)
  - 🟢 Already fixed in our lock — informational only

#### Cross-check before 🔴 (MANDATORY for closed security/regression issues)

`nixpkgs-security-tracker[bot]` closes tracker issues based on **upstream
CVE DB publication**, not on a merged nixpkgs PR. A closed security issue
is NOT evidence that a fix is reachable via `nix flake update`. Before you
mark any closed security issue as 🔴 actionable, verify:

```bash
# Identify the affected nixpkgs attribute (e.g. "imagemagick", "openssh")
PKG=<attrname>

# 1) What version does OUR lock ship?
OUR_VERSION=$(nix eval --raw "github:NixOS/nixpkgs/$OUR_REV#$PKG.version" 2>/dev/null)

# 2) What is master shipping right now?
MASTER_SHA=$(gh api repos/NixOS/nixpkgs/commits/master --jq '.sha')
MASTER_VERSION=$(nix eval --raw "github:NixOS/nixpkgs/$MASTER_SHA#$PKG.version" 2>/dev/null)

# 3) What is the nixos-unstable channel shipping (what a lock bump would pull)?
UNSTABLE_SHA=$(gh api repos/NixOS/nixpkgs/commits/nixos-unstable --jq '.sha')
UNSTABLE_VERSION=$(nix eval --raw "github:NixOS/nixpkgs/$UNSTABLE_SHA#$PKG.version" 2>/dev/null)

# 4) Did any PR bumping this attribute merge since our lock date?
gh search prs --repo NixOS/nixpkgs --state=closed --merged \
  --match=title "$PKG" --json number,title,mergedAt,mergeCommit --limit 20 \
  | jq -r '.[] | select(.mergedAt > "'"$SINCE"'") | "\(.mergedAt)  #\(.number)  \(.title)"'

echo "Ours:     $OUR_VERSION"
echo "Unstable: $UNSTABLE_VERSION  (what a lock bump would pull)"
echo "Master:   $MASTER_VERSION"
```

**Interpretation:**
- `UNSTABLE_VERSION > OUR_VERSION` → **true 🔴** — lock bump is actionable.
- `UNSTABLE_VERSION == OUR_VERSION == MASTER_VERSION` → **downgrade to 🟡**
  ("exposure present, no fix in nixpkgs yet"). Lock bump is a no-op.
- `MASTER_VERSION > UNSTABLE_VERSION > OUR_VERSION` → **🟠** — fix on master,
  not yet cascaded. Wait or pin an overlay.
- No PR listed AND all three versions match → **🟡** — tracker bot closure
  only; no shipped fix. Don't recommend `nix flake update`.

This check caught a false-positive 🔴 for ImageMagick 2026-04-17: CVE
tracker issues were closed same day as our lock, but nixpkgs still pinned
`imagemagick 7.1.2-17` while upstream released `7.1.2-19` with fixes. A
lock bump would have done nothing.

### Step 5 — For each finding, draft the recommendation

The recommendation MUST include a concrete next step, not just "review this":

| Finding type | Recommendation template |
|---|---|
| Closed bug, fix merged in PR, PR landed on nixos-unstable AFTER our lock (per cross-check) | `nix flake update nixpkgs && just test-host p620 razer p510` |
| Closed bug, fix in commit X, X is in our lock (per cross-check) | "Already fixed — no action" |
| Closed security tracker, **no corresponding PR merged** (cross-check fails) | 🟡 "Exposure present, no fix in nixpkgs yet. Watch upstream PR." — **do NOT recommend `nix flake update`** |
| Closed security tracker, fix on master only (not nixos-unstable yet) | 🟠 "Wait for channel cascade, or pin the package via overlay to master rev." |
| Open security issue affecting enabled service | "Disable `services.<x>` on <host> until fixed" + diff snippet |
| Open regression in enabled package | "Pin to last-known-good version: `<flake.nix snippet>`" |
| Open bug, low impact | "Watch upstream. Open tracking issue (#cmd suggestion)" |
| Deprecation notice | "Migrate to new option: `services.<old>` → `services.<new>`" |

Always cite the upstream issue URL.

### Step 6 — Optional: open tracking issues in our repo

Only if the user agrees AFTER reading the report:

```bash
gh issue create \
  --title "Track NixOS/nixpkgs#<n>: <title>" \
  --label "upstream-watch" \
  --body "..."
```

Don't open these speculatively — small repo, the issue list is for things
we're committing to action.

---

## Required behaviors

- **Read-only.** This command must NEVER edit `.nix` files, `flake.lock`,
  or run deploys. It produces a report.
- **Cite every finding.** Every recommendation must link to the upstream
  issue/PR.
- **Skip noise.** Drop matches for packages mentioned only in passing
  (e.g. an issue title containing "in nginx and similar to electron" — we
  use neither directly).
- **Respect the cutoff.** Don't re-surface findings older than our lock —
  we already had the chance to address them when we bumped.
- **No false positives.** When unsure whether an issue actually affects us,
  put it under 🟡 with an explicit "needs human verification" note rather
  than escalating it to 🔴/🟠.

## Anti-patterns to avoid

- ❌ Calling the GitHub API without `--paginate` (you'll miss results past 30)
- ❌ Using WebFetch for github.com (use `gh api`, it's authenticated)
- ❌ Querying without a `since=` cutoff (returns 10000+ irrelevant issues)
- ❌ Editing files based on the report without explicit user approval
- ❌ Running `nix flake update` automatically — always show the diff first
- ❌ **Reading `.nodes.nixpkgs.locked` directly** — that node is usually a
  transitive dep pinned by agenix/home-manager/etc. Always resolve via
  `.nodes[<root.inputs.nixpkgs>]` to get the node your system actually
  builds against.
- ❌ **Treating a closed CVE tracker issue as proof of a merged fix.** The
  `nixpkgs-security-tracker[bot]` closes issues based on upstream CVE DB
  publication, NOT on a nixpkgs PR. Always run the Step 4 cross-check
  (`gh search prs --merged --match=title "<pkg>"` and `nix eval --raw
  #<pkg>.version` against our lock vs. nixos-unstable) before recommending
  a lock bump.

## When to invoke

- After any `nix flake update` to confirm we're not pulling in new regressions
- Before bumping a major nixpkgs release (e.g. 25.05 → 25.11)
- Weekly / monthly cadence for proactive awareness
- After any unexplained service failure on a host (cross-check upstream first)

## Documentation references

- `docs/PATTERNS.md` — module/package patterns
- `docs/NIXOS-ANTI-PATTERNS.md` — what we avoid
- `flake.lock` — source of truth for what we're pinning
- Upstream tracker: https://github.com/NixOS/nixpkgs/issues
