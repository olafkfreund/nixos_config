#!/usr/bin/env bash
# Nightly NixOS-upstream issue audit.
#
# Cross-references recently-opened and recently-closed NixOS/nixpkgs
# issues against our pinned flake and surfaces actionable findings.
# Produces a markdown report on stdout and a machine-readable findings
# JSONL stream to a separate file.
#
# Mirrors the /check-nixos-issues slash-command logic so a human and
# the workflow produce the same shape of report.
#
# Usage:
#   scripts/nixos-issue-audit.sh                # report → stdout, findings → ./findings.jsonl
#   scripts/nixos-issue-audit.sh --out DIR      # report → DIR/report.md, findings → DIR/findings.jsonl
#
# Requires: gh (authed), jq, nix (for cross-check), curl.

set -euo pipefail

OUT_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      OUT_DIR="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [ -n "$OUT_DIR" ]; then
  mkdir -p "$OUT_DIR"
  REPORT_FILE="$OUT_DIR/report.md"
  FINDINGS_FILE="$OUT_DIR/findings.jsonl"
else
  REPORT_FILE=/dev/stdout
  FINDINGS_FILE="./findings.jsonl"
fi

# stdout for narration / progress (goes to GH Actions log); the report
# itself is buffered then written at the end.
log() { printf '[audit] %s\n' "$*" >&2; }

REPORT_BUF=$(mktemp)
: >"$FINDINGS_FILE"

# 1. Resolve root nixpkgs node + cutoff -------------------------------------
NIXPKGS_NODE=$(jq -r '.nodes.root.inputs.nixpkgs' flake.lock)
SINCE=$(jq -r --arg n "$NIXPKGS_NODE" '.nodes[$n].locked.lastModified | todate' flake.lock)
OUR_REV=$(jq -r --arg n "$NIXPKGS_NODE" '.nodes[$n].locked.rev' flake.lock)
RELEASE=$(nix eval --raw .#nixosConfigurations.p620.config.system.nixos.release 2>/dev/null || echo "unknown")
TODAY=$(date -u +%Y-%m-%d)

log "cutoff: $SINCE  rev: ${OUR_REV:0:10}  release: $RELEASE"

# 2. Pull issue feeds -------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP" "$REPORT_BUF"' EXIT
log "fetching open + closed nixpkgs issues since cutoff …"
gh api --paginate "repos/NixOS/nixpkgs/issues?state=open&since=$SINCE&per_page=100" \
  --jq '.[] | select(.pull_request == null) | {n: .number, t: .title, labels: [.labels[].name], created: .created_at, body_preview: (.body // "" | .[0:400])}' \
  >"$TMP/open.jsonl"
gh api --paginate "repos/NixOS/nixpkgs/issues?state=closed&since=$SINCE&per_page=100" \
  --jq '.[] | select(.pull_request == null) | select(.closed_at > "'"$SINCE"'") | {n: .number, t: .title, labels: [.labels[].name], closed: .closed_at, body_preview: (.body // "" | .[0:400])}' \
  >"$TMP/closed.jsonl"

OPEN_TOTAL=$(wc -l <"$TMP/open.jsonl")
CLOSED_TOTAL=$(wc -l <"$TMP/closed.jsonl")
log "open=$OPEN_TOTAL  closed=$CLOSED_TOTAL"

# 3. Inventory regex --------------------------------------------------------
# Curated set of packages, modules, and subsystems this repo actually uses.
# Update when adding hosts or major subsystems. False positives cost a 🟡
# entry in the report; false negatives mean we miss exposure — prefer
# broader.
REGEX='(claude-desktop|claude-code|claude-router|citrix-workspace|intune-portal|microsoft-defender|splashboard|kosli-cli|warp-terminal|whatsapp|audiobook|gnome-shell|gnome-session|gnome-online|cosmic-(?:session|greeter|comp|panel|files|ext)|hyprland|\bnvidia\b|nvidia-(?:open|prime|optimus|container)|amdgpu|\brocm\b|pipewire|pulseaudio|wireplumber|tailscale|syncthing|podman|docker(?:-compose)?|libvirt|qemu|incus|microvm|virtualbox|spice|lanzaboote|agenix|sops-nix|openssh|polkit|home-manager|stylix|spicetify|bubblewrap|electron|node-pty|wayland|xwayland|\bnfs\b|bluez|\btlp\b|plymouth|nix-snapd|secure[- ]?boot)'

jq -c --arg re "$REGEX" 'select((.t | test($re; "i")) or (.body_preview | test($re; "i")))' "$TMP/open.jsonl" >"$TMP/matches-open.jsonl"
jq -c --arg re "$REGEX" 'select((.t | test($re; "i")) or (.body_preview | test($re; "i")))' "$TMP/closed.jsonl" >"$TMP/matches-closed.jsonl"

OPEN_MATCHES=$(wc -l <"$TMP/matches-open.jsonl")
CLOSED_MATCHES=$(wc -l <"$TMP/matches-closed.jsonl")
log "matches: open=$OPEN_MATCHES  closed=$CLOSED_MATCHES"

# 4. Helpers ----------------------------------------------------------------
# Effective-enable check across our active hosts. Echoes true/false.
host_eval_bool() {
  local host="$1" attr="$2"
  nix eval --raw ".#nixosConfigurations.${host}.config.${attr}" \
    --apply 'b: if b then "true" else "false"' 2>/dev/null || echo "false"
}

# Any host has this option true?
any_host_enables() {
  local attr="$1"
  local h
  for h in p620 razer p510; do
    if [ "$(host_eval_bool "$h" "$attr")" = "true" ]; then return 0; fi
  done
  return 1
}

# Emit a finding record + buffer it for the report. Args:
#   sev (CRITICAL|REGRESSION|WATCH|GREEN), upstream_number, title, why, recommendation, url
emit_finding() {
  local sev="$1" n="$2" t="$3" why="$4" rec="$5" url="$6"
  printf '%s\n' "$(jq -cn --arg sev "$sev" --argjson n "$n" --arg t "$t" --arg why "$why" --arg rec "$rec" --arg url "$url" \
    '{severity:$sev, n:$n, title:$t, why:$why, recommendation:$rec, url:$url}')" >>"$FINDINGS_FILE"
}

# 5. Classify ---------------------------------------------------------------
# We don't try to be exhaustive here. We use a deterministic rule table
# that captures the highest-value cases the slash command spelled out.
# Anything not in the table falls to 🟡 WATCH (low confidence).

classify_one() {
  local stream="$1" # open|closed
  local row="$2"
  local n t labels
  n=$(jq -r '.n' <<<"$row")
  t=$(jq -r '.t' <<<"$row")
  # Case-folded once so the rule table can use plain lowercase regex
  # without char-class tricks (the spell-checker can't parse [bB] etc.)
  local tl="${t,,}"
  labels=$(jq -r '.labels | join(",")' <<<"$row")
  local url="https://github.com/NixOS/nixpkgs/issues/$n"

  # Severity rules — ORDER MATTERS, first match wins. Defaults catch
  # the case where a top-level branch matches but its inner condition
  # doesn't assign (e.g. pipewire keyword but bluetooth disabled).
  local sev=WATCH
  local why="Inventory keyword matched but specific exposure not auto-verified."
  local rec="Needs human triage."

  # --- direct-exposure regression rules ---
  if [[ "$tl" =~ pipewire ]] && [[ "$tl" =~ bluetooth ]] && [ "$stream" = "open" ]; then
    if any_host_enables 'services.pipewire.enable' && any_host_enables 'hardware.bluetooth.enable'; then
      sev=REGRESSION
      why="PipeWire + Bluetooth active on at least one host."
      rec="Watch upstream; workaround restart pipewire stack."
    fi
  elif [[ "$tl" =~ tailscale ]] && [[ "$tl" =~ (dns|magicdns|resolv) ]] && [ "$stream" = "open" ]; then
    if any_host_enables 'services.tailscale.enable'; then
      sev=WATCH
      why="Tailscale enabled on hosts; existing dns-fallback module partially mitigates."
      rec="Watch upstream; no actionable nixpkgs change yet."
    fi
  elif [[ "$tl" =~ hyprland ]]; then
    if any_host_enables 'programs.hyprland.enable'; then
      sev=WATCH
      why="Hyprland enabled."
      rec="Review impact, no auto-action."
    else
      sev=GREEN
      why="programs.hyprland.enable = false on all hosts."
      rec="No action."
    fi
  elif [[ "$tl" =~ plymouth ]]; then
    if any_host_enables 'boot.plymouth.enable'; then
      sev=WATCH
      why="Plymouth enabled on at least one host."
      rec="Cosmetic; review only if visual issue observed."
    else
      sev=GREEN
      why="boot.plymouth.enable = false."
      rec="No action."
    fi
  elif [[ "$tl" =~ incus ]]; then
    if any_host_enables 'services.incus.enable'; then
      # CRITICAL only if a fix actually shipped — see cross-check below.
      sev=REGRESSION
      why="Incus enabled on at least one host."
      rec="Run version cross-check before bumping."
    else
      sev=GREEN
      why="services.incus.enable = false everywhere."
      rec="No action."
    fi
  elif [[ "$tl" =~ systemd\ stage\ 1 ]]; then
    # Specific to ZFS+LUKS, not us.
    sev=GREEN
    why="We don't run ZFS+LUKS initrd stack."
    rec="No action."
  elif [[ "$tl" =~ (steam|cargo|amphetype|bambu|logseq|bitwarden|element-desktop|qutebrowser|nextcloud-client|calibre|signal-desktop|bitwig|stoat|proton-authenticator|stevenblack|weblate|mautrix) ]]; then
    sev=GREEN
    why="Package not in our system or user package sets."
    rec="No action."
  elif [[ "$labels" =~ 2\.status:\ stale ]]; then
    sev=GREEN
    why="Upstream marked stale."
    rec="No action."
  else
    sev=WATCH
    why="Inventory keyword matched but specific exposure not auto-verified."
    rec="Needs human triage."
  fi

  # 6. Cross-check before raising CRITICAL ---------------------------------
  # Only run for CLOSED security/regression candidates that we've already
  # classified as REGRESSION. See the slash command's mandatory check —
  # we never raise CRITICAL without verifying a fix actually shipped past
  # our lock.
  if [ "$sev" = "REGRESSION" ] && [ "$stream" = "closed" ] && [[ "$labels" =~ "security" ]]; then
    # Heuristic: extract package name as the first word from the title before ':' or space
    local pkg
    pkg=$(printf '%s' "$t" | sed -E 's/[: ].*//' | tr '[:upper:]' '[:lower:]')
    log "cross-check: closed-security #$n pkg=$pkg"
    local ours unstable
    ours=$(nix eval --raw "github:NixOS/nixpkgs/${OUR_REV}#${pkg}.version" 2>/dev/null || echo "")
    unstable=$(nix eval --raw "github:NixOS/nixpkgs/nixos-unstable#${pkg}.version" 2>/dev/null || echo "")
    if [ -n "$ours" ] && [ -n "$unstable" ] && [ "$ours" != "$unstable" ]; then
      sev=CRITICAL
      rec="Lock bump actionable: ours=$ours, unstable=$unstable. Run \`nix flake update nixpkgs && just test-all-parallel\`."
    else
      # Tracker-bot close without shipped fix — downgrade to WATCH.
      sev=WATCH
      rec="Tracker closure only; ours=$ours unstable=$unstable. No shipped fix in nixos-unstable yet. Do NOT bump lock."
    fi
  fi

  emit_finding "$sev" "$n" "$t" "$why" "$rec" "$url"
}

log "classifying matches …"
while IFS= read -r row; do classify_one open "$row"; done <"$TMP/matches-open.jsonl"
while IFS= read -r row; do classify_one closed "$row"; done <"$TMP/matches-closed.jsonl"

# 7. Render the report ------------------------------------------------------
C_CRIT=$(grep -c '"severity":"CRITICAL"' "$FINDINGS_FILE" || true)
C_REG=$(grep -c '"severity":"REGRESSION"' "$FINDINGS_FILE" || true)
C_WATCH=$(grep -c '"severity":"WATCH"' "$FINDINGS_FILE" || true)
C_GREEN=$(grep -c '"severity":"GREEN"' "$FINDINGS_FILE" || true)

emit_section() {
  local sev_label="$1" sev_key="$2" emoji="$3"
  local rows
  rows=$(jq -c --arg s "$sev_key" 'select(.severity == $s)' "$FINDINGS_FILE")
  if [ -z "$rows" ]; then return; fi
  printf '\n## %s %s\n\n' "$emoji" "$sev_label" >>"$REPORT_BUF"
  printf '%s\n' "$rows" | while IFS= read -r f; do
    n=$(jq -r '.n' <<<"$f")
    t=$(jq -r '.title' <<<"$f")
    why=$(jq -r '.why' <<<"$f")
    rec=$(jq -r '.recommendation' <<<"$f")
    url=$(jq -r '.url' <<<"$f")
    printf -- '- **#%s — %s**\n  - Why: %s\n  - Action: %s\n  - Upstream: %s\n' "$n" "$t" "$why" "$rec" "$url" >>"$REPORT_BUF"
  done
}

SHORT_REV="${OUR_REV:0:10}"
cat >"$REPORT_BUF" <<EOF
# NixOS Issue Audit — $TODAY

**Audited against:**
- nixpkgs lock: \`$SHORT_REV\` (last bumped $SINCE)
- NixOS release: $RELEASE
- Hosts: p620, razer, p510
- Open issues scanned: $OPEN_TOTAL · closed issues scanned: $CLOSED_TOTAL
- Matches after inventory regex: open=$OPEN_MATCHES closed=$CLOSED_MATCHES

## Summary

| Severity | Count |
|---|---|
| 🔴 Critical / security | $C_CRIT |
| 🟠 Regression affecting our config | $C_REG |
| 🟡 Watch | $C_WATCH |
| 🟢 Not applicable | $C_GREEN |
EOF

emit_section "Critical / security" CRITICAL 🔴
emit_section "Regression in our config" REGRESSION 🟠
emit_section "Watch (manual triage)" WATCH 🟡
emit_section "Dismissed (not applicable)" GREEN 🟢

cat "$REPORT_BUF" >"$REPORT_FILE"

log "done. CRIT=$C_CRIT REG=$C_REG WATCH=$C_WATCH GREEN=$C_GREEN"
log "report: $REPORT_FILE  findings: $FINDINGS_FILE"
