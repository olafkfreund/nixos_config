#!/usr/bin/env bash
# razer post-deploy health check.
#
# NVIDIA Optimus PRIME-sync laptop with GDM. This is the host where the
# silent compositor crash (mesa 26.1.1 / GNOME 50.0) was first caught on
# 2026-06-08 — the failure mode that motivated this whole health-check
# layer. See commit d62a86f80 and around for the post-mortem.
#
# Exit 0 = healthy, non-zero = scripts/update-commit-deploy.sh rolls back.
set -uo pipefail

if ! systemctl is-active --quiet display-manager.service; then
  echo "FAIL: display-manager.service not active"
  exit 1
fi

# The 2026-06-08 signature. Don't tighten the time window below 2 minutes —
# update-commit-deploy.sh waits ~15s before invoking this; the exhaustion
# message has had time to land, but we still want to catch slower repro.
if journalctl -u display-manager.service --since "2 minutes ago" --no-pager 2>/dev/null \
  | grep -qF "GdmLocalDisplayFactory: maximum number of display failures reached"; then
  echo "FAIL: GDM exhausted display-spawn retries in the last 2 minutes"
  echo "      (silent gnome-session crash — likely a mesa / Optimus / GNOME regression)"
  exit 1
fi

# Positive signal: at least one session on seat0 — either GDM's greeter or
# someone (e.g. olafkfreund) actually logged in.
if loginctl list-sessions --no-legend 2>/dev/null \
  | awk '$4 == "seat0" {found=1} END {exit !found}'; then
  echo "OK: display-manager live, seat0 has a session"
else
  echo "OK: display-manager live (no seat0 session yet but no GDM exhaustion)"
fi
exit 0
