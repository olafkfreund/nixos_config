#!/usr/bin/env bash
# p620 post-deploy health check.
#
# Workstation: AMD Ryzen + Radeon, GDM + Hyprland desktop. Runs as the local
# binary cache server too. Run by scripts/update-commit-deploy.sh after the
# new generation has been activated; exit 0 = healthy, non-zero = roll back.
set -uo pipefail

if ! systemctl is-active --quiet display-manager.service; then
  echo "FAIL: display-manager.service not active"
  exit 1
fi

# Canonical "GDM gave up" signature. When mutter/gnome-shell crashes silently
# (mesa or Optimus regressions), GDM tries 8 times in <1s, gives up, and the
# unit stays "active" but produces no greeter. This message is the only
# load-bearing signal that distinguishes broken-but-running from healthy.
if journalctl -u display-manager.service --since "2 minutes ago" --no-pager 2>/dev/null \
  | grep -qF "GdmLocalDisplayFactory: maximum number of display failures reached"; then
  echo "FAIL: GDM exhausted display-spawn retries in the last 2 minutes"
  exit 1
fi

# Binary cache server — other hosts depend on it for fast deploys.
if ! systemctl is-active --quiet nix-serve.service 2>/dev/null; then
  echo "FAIL: nix-serve.service not active (other hosts can't use p620 as a cache)"
  exit 1
fi

# Positive signal: a session on seat0 (greeter or logged-in user). Useful but
# not load-bearing — on a freshly-activated config it may not exist yet.
if loginctl list-sessions --no-legend 2>/dev/null \
  | awk '$4 == "seat0" {found=1} END {exit !found}'; then
  echo "OK: display-manager live, nix-serve active, seat0 has a session"
else
  echo "OK: display-manager live, nix-serve active (no seat0 session yet but no GDM exhaustion)"
fi
exit 0
