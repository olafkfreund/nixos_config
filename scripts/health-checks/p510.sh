#!/usr/bin/env bash
# p510 post-deploy health check.
#
# Headless media-server + k3d + Backstage host. No display manager. The
# things that matter: Plex serves video, Backstage serves the portal,
# k3d-factory cluster is reachable, SSH still works for next deploy.
#
# Exit 0 = healthy, non-zero = scripts/update-commit-deploy.sh rolls back.
set -uo pipefail

state=$(systemctl is-system-running 2>/dev/null || echo unknown)
case "$state" in
  running | degraded) ;;
  *)
    echo "FAIL: systemctl is-system-running reports '$state' (expected running|degraded)"
    exit 1
    ;;
esac

# sshd has to stay alive — without it the next remote deploy/rollback breaks.
if ! systemctl is-active --quiet sshd.service 2>/dev/null; then
  echo "FAIL: sshd.service not active"
  exit 1
fi

# Plex is the headline workload. If it's dead the deploy regressed.
if ! systemctl is-active --quiet plex.service 2>/dev/null; then
  echo "FAIL: plex.service not active"
  exit 1
fi

# Backstage lives in podman on p510. The container service starts the
# backend; the env-setup oneshot has to have succeeded for the container
# to even start, so checking podman-backstage.service covers both.
if systemctl list-unit-files --no-legend podman-backstage.service 2>/dev/null \
  | grep -q "podman-backstage.service"; then
  if ! systemctl is-active --quiet podman-backstage.service 2>/dev/null; then
    echo "FAIL: podman-backstage.service not active (Backstage portal down)"
    exit 1
  fi
fi

# Surface any other failed units so the report is useful but don't fail
# the deploy on them — degraded is acceptable as long as the headlines
# above are green.
failed=$(systemctl list-units --state=failed --no-legend --plain 2>/dev/null \
  | awk '{print $1}' | head -3 | paste -sd, -)
if [ "$state" = "degraded" ]; then
  echo "OK: system degraded but Plex + sshd + (Backstage if enabled) active (failed: ${failed:-none})"
else
  echo "OK: system running, Plex + sshd + (Backstage if enabled) active"
fi
exit 0
