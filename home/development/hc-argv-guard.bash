# Re-exec hc argv launches into their own pane scope before bash startup runs (#2987).
if [ -n "${HC_TERMINAL_ID:-}" ] \
  && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ] \
  && _hc_cg=$(cat "${HC_ARGV_GUARD_CGROUP:-/proc/self/cgroup}" 2>/dev/null) \
  && ! grep -qE '/herdr-pane-[0-9]+\.scope(/|$)' <<<"$_hc_cg" \
  && mapfile -d "" -t _hc_argv 2>/dev/null </proc/$$/cmdline && [ "${#_hc_argv[@]}" -gt 0 ]; then
  exec @hcShell@ "${_hc_argv[@]:1}"
fi
unset _hc_cg _hc_argv
