# herdr-app starts argv launches outside hc's shell wrapper, in the shared hc-hold unit: re-exec them into their own
# pane scope (#2987). Builtins only, so the owner's aliases and PATH (cat=bat) cannot change the result.
if [ -n "${HC_TERMINAL_ID:-}" ] \
  && [ -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/bus" ] \
  && mapfile -t _hc_cg 2>/dev/null <"${HC_ARGV_GUARD_CGROUP:-/proc/self/cgroup}" \
  && [[ " ${_hc_cg[*]} " =~ /hc-hold-[^/[:space:]]*\.service\  ]] \
  && mapfile -d "" -t _hc_argv 2>/dev/null </proc/$$/cmdline && [ "${#_hc_argv[@]}" -gt 0 ]; then
  exec @hcShell@ "${_hc_argv[@]:1}"
fi
unset _hc_cg _hc_argv
