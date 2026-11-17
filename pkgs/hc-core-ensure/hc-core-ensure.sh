# shellcheck shell=bash
inner="${HC_CORE_ENSURE_INNER:-}"
unset HC_CORE_ENSURE_INNER

log() {
  printf '%s: %s\n' "$mode" "$1" | systemd-cat -t hc-core-ensure || :
}

mode="${1:-unknown}"
case "$mode" in
  login | launch) ;;
  *)
    log "unknown mode"
    exit 0
    ;;
esac

if [[ ! -S "${XDG_RUNTIME_DIR:-}/bus" ]]; then
  log "no user bus"
  exit 0
fi

if [[ "$inner" != 1 ]]; then
  if ! systemd-run --user --collect --wait --quiet -p Type=oneshot -p TimeoutStartSec=60 \
    --setenv=HC_CORE_ENSURE_INNER=1 -- "$0" "$mode"; then
    log "systemd-run failed"
  fi
  exit 0
fi

if ! exec 9>"$XDG_RUNTIME_DIR/hc-core-ensure.lock"; then
  log "lock unavailable"
  exit 0
fi
if ! flock -w "${HC_CORE_ENSURE_LOCK_WAIT:-60}" 9; then
  log "busy"
  exit 0
fi

if @hc@ server status >/dev/null 2>&1; then
  if [[ "$mode" == login ]]; then
    if @hc@ server restart --fresh; then log "restart --fresh"; else log "restart failed"; fi
  else
    log "core running"
  fi
else
  if @hc@ server start; then log "start"; else log "start failed"; fi
fi
