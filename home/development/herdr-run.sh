#!/usr/bin/env bash
# Usage: herdr-run <codex|agy> <command> [args...]
# HERDR_RUN_TIME_SCALE scales waits for the isolated self-test (default: 1).
label=${1:?usage: herdr-run <codex|agy> <command> [args...]}
shift
if [[ $label != codex && $label != agy || $# -eq 0 ]]; then
  echo 'usage: herdr-run <codex|agy> <command> [args...]' >&2
  exit 2
fi
if [[ ${HERDR_ENV:-} != 1 || -z ${HERDR_SOCKET_PATH:-} || -z ${HERDR_TAB_ID:-} || -z ${HERDR_WORKSPACE_ID:-} ]]; then
  exec "$@"
fi

scale=${HERDR_RUN_TIME_SCALE:-1}
sleep_for() { sleep "$(awk -v n="$1" -v s="$scale" 'BEGIN { printf "%.3f", n*s }')"; }
h() { "${HERDR_BIN_PATH:-herdr}" "$@"; }
socket() { printf '%s\n' "$1" | socat -t5 - "UNIX-CONNECT:$HERDR_SOCKET_PATH"; }
same_pane() {
  local reply
  reply=$(h pane get "$pane" 2>/dev/null) || return 1
  jq -e --arg terminal "$terminal" '.result.pane.terminal_id == $terminal' >/dev/null <<<"$reply"
}
close_pane() { if same_pane; then h pane close "$pane" >/dev/null 2>&1 || :; fi; }
report() { if same_pane; then h pane report-agent "$pane" --source herdr-run --agent "$label" --state "$1" >/dev/null 2>&1 || :; fi; }
release_pane() { if same_pane; then h pane release-agent "$pane" --source herdr-run --agent "$label" >/dev/null 2>&1 || :; fi; }
mark() { if same_pane; then h pane report-metadata "$pane" --source herdr-run --token "split_mark=↳ $label" >/dev/null 2>&1 || :; fi; }
kill_group() {
  local pgid
  if [[ -f $dir/cmd.pgid ]]; then
    read -r pgid <"$dir/cmd.pgid" || return 0
    if [[ $pgid =~ ^[0-9]+$ ]] && ((pgid > 1)); then
      kill -"$1" -- "-$pgid" 2>/dev/null || return 1
      return 0
    fi
  fi
  return 1
}
# TERM the command's group, give it up to 5 s to go, then KILL what is left.
stop_group() {
  kill_group TERM || return 0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill_group 0 || return 0
    sleep_for 0.5
  done
  kill_group KILL || :
}
# shellcheck disable=SC2329 # EXIT trap
cleanup() {
  trap - EXIT
  if [[ -n ${marker_pid:-} ]]; then kill "$marker_pid" 2>/dev/null || :; fi
  rm -rf -- "$dir"
}
# shellcheck disable=SC2329 # signal traps
interrupt() {
  trap '' INT TERM
  : >"$dir/cancel"
  for _ in 1 2 3 4; do
    [[ -e $dir/cmd.pgid || -e $dir/status ]] && break
    sleep_for 0.5
  done
  stop_group
  close_pane
  exit "$1"
}
headless() {
  local code=0
  trap - INT TERM
  "$@" <"$dir/stdin" || code=$?
  exit "$code"
}

dir=$(mktemp -d) || exit 1
chmod 700 "$dir"
trap cleanup EXIT
if [[ -t 0 ]]; then : >"$dir/stdin"; else cat >"$dir/stdin"; fi
declare -A readonly_names=()
while IFS= read -r name; do readonly_names[$name]=1; done < <(readonly -p | sed -n 's/^declare -[^ ]*r[^ ]* \([^=]*\).*/\1/p')
while IFS= read -r line; do
  name=${line#declare -x }
  name=${name%%=*}
  case $name in BASH* | SHELLOPTS | EUID | UID | PPID | GROUPS | FUNCNAME | DIRSTACK | PIPESTATUS) continue ;; esac
  [[ -z ${readonly_names[$name]:-} ]] || continue
  printf '%s\n' "$line"
done < <(export -p) >"$dir/env"
printf 'cwd=%q\n' "$PWD" >>"$dir/env"

title="$label review"
for arg in "$@"; do
  if [[ $arg == codex-implement || $arg == agy-implement ]]; then
    title="$label implement"
    break
  fi
done
{
  printf '#!/usr/bin/env bash\ncd %q || exit 127\n' "$dir"
  printf 'cmd=('
  printf '%q ' "$@"
  printf ')\n'
  printf 'helper_pid=%q\nlabel=%q\ntitle=%q\nscale=%q\nherdr_bin=%q\n' "$$" "$label" "$title" "$scale" "${HERDR_BIN_PATH:-herdr}"
  cat <<'RUNNER'
mkdir claim || exit 0
printf '%s\n' "$$" > runner.pid.tmp && mv runner.pid.tmp runner.pid
sleep_for() { sleep "$(awk -v n="$1" -v s="$scale" 'BEGIN { printf "%.3f", n*s }')"; }
same_pane() {
  local reply
  reply=$("$herdr_bin" pane get "$pane" 2>/dev/null) || return 1
  jq -e --arg terminal "$terminal" '.result.pane.terminal_id == $terminal' >/dev/null <<< "$reply"
}
close_pane() { if same_pane; then "$herdr_bin" pane close "$pane" >/dev/null 2>&1 || :; fi; }
kill_group() {
  local pgid
  if [[ -f cmd.pgid ]]; then
    read -r pgid < cmd.pgid || return 0
    if [[ $pgid =~ ^[0-9]+$ ]] && (( pgid > 1 )); then kill -"$1" -- "-$pgid" 2>/dev/null || return 1; return 0; fi
  fi
  return 1
}
stop_group() {
  kill_group TERM
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill_group 0 || break; sleep_for 0.5; done
  kill_group KILL
}
finish() {
  trap - EXIT
  if [[ ! -e status ]]; then printf '127\n' > status.tmp && mv status.tmp status; fi
  if [[ -n ${watchdog_pid:-} ]]; then kill "$watchdog_pid" 2>/dev/null || :; fi
  # with the helper gone nobody else closes this pane
  if ! kill -0 "$helper_pid" 2>/dev/null; then close_pane; fi
}
trap finish EXIT
(
  while sleep_for 2; do
    if ! kill -0 "$helper_pid" 2>/dev/null; then
      stop_group
      close_pane
      exit 0
    fi
  done
) &
watchdog_pid=$!
printf '\033]0;%s\007' "$title"
: > out; : > err
# $0 is the private directory: the command runs in the caller's cwd.
setsid -w env -i "$BASH" --noprofile --norc -c \
  'source "$0/env" && cd "$cwd" && [ ! -e "$0/cancel" ] &&
   echo $$ > "$0/cmd.pgid.tmp" && mv "$0/cmd.pgid.tmp" "$0/cmd.pgid" &&
   exec "$@"; exit 127' "$PWD" "${cmd[@]}" < stdin > out 2> err &
cpid=$!
tail --pid="$cpid" -f out err &
wait "$cpid"; code=$?
printf '%s\n' "$code" > status.tmp && mv status.tmp status
exit "$code"
RUNNER
} >"$dir/run"
chmod 700 "$dir/run"

pane='' terminal='' tab=''
lock="${XDG_RUNTIME_DIR:-/tmp}/herdr-run-${HERDR_TAB_ID}.lock"
exec {lock_fd}>"$lock"
flock "$lock_fd"
created=$(h tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "↳ $label" --no-focus 2>/dev/null) || {
  flock -u "$lock_fd"
  headless "$@"
}
pane=$(jq -r '.result.root_pane.pane_id // empty' <<<"$created")
terminal=$(jq -r '.result.root_pane.terminal_id // empty' <<<"$created")
tab=$(jq -r '.result.tab.tab_id // empty' <<<"$created")
if [[ -z $pane || -z $terminal || -z $tab ]]; then
  flock -u "$lock_fd"
  headless "$@"
fi
# Bake the returned identity ahead of the runner body.
{
  printf 'pane=%q\nterminal=%q\n' "$pane" "$terminal"
  cat "$dir/run"
} >"$dir/run.tmp"
mv "$dir/run.tmp" "$dir/run"
mark
tabs=$(socket "$(jq -nc --arg w "$HERDR_WORKSPACE_ID" '{id:"1",method:"tab.list",params:{workspace_id:$w}}')" 2>/dev/null) || tabs=
panes=$(socket "$(jq -nc --arg w "$HERDR_WORKSPACE_ID" '{id:"1",method:"pane.list",params:{workspace_id:$w}}')" 2>/dev/null) || panes=
if [[ -n $tabs && -n $panes ]]; then
  # leave out our own tab: it is already marked, and would count as a child
  mapfile -t ids < <(jq -r --arg own "$tab" '.result.tabs[].tab_id | select(. != $own)' <<<"$tabs")
  insert=-1
  for i in "${!ids[@]}"; do
    [[ ${ids[i]} == "$HERDR_TAB_ID" ]] && {
      insert=$((i + 1))
      break
    }
  done
  if ((insert >= 0)); then
    while ((insert < ${#ids[@]})); do
      child=$(jq -r --arg tab "${ids[insert]}" '.result.panes[] | select(.tab_id == $tab) | .pane_id' <<<"$panes" | head -n 1)
      [[ -n $child ]] || break
      child_reply=$(h pane get "$child" 2>/dev/null) || break
      jq -e '.result.pane.tokens.split_mark != null' >/dev/null <<<"$child_reply" || break
      ((insert += 1))
    done
    if ! socket "$(jq -nc --arg tab "$tab" --argjson n "$insert" '{id:"1",method:"tab.move",params:{tab_id:$tab,insert_index:$n}}')" >/dev/null 2>&1; then :; fi
  fi
fi
flock -u "$lock_fd"

trap 'interrupt 130' INT
trap 'interrupt 143' TERM
for ((attempt = 1; attempt <= 3; attempt++)); do
  if ! h pane run "$pane" "bash $(printf '%q' "$dir/run")" >/dev/null 2>&1; then break; fi
  for _ in 1 2; do
    [[ -d $dir/claim ]] && break 2
    sleep_for 0.5
  done
done
if [[ ! -d $dir/claim ]]; then
  if mkdir "$dir/claim" 2>/dev/null; then
    close_pane
    headless "$@"
  fi
  for _ in 1 2; do
    [[ -f $dir/runner.pid ]] && break
    sleep_for 0.5
  done
fi
report working
(
  sleep_for 2
  mark
  sleep_for 4
  mark
  sleep_for 9
  mark
) &
marker_pid=$!
while [[ ! -f $dir/status ]]; do
  sleep_for 5
  if [[ ! -f $dir/status ]]; then
    if ! same_pane || [[ ! -f $dir/runner.pid ]] || ! kill -0 "$(cat "$dir/runner.pid")" 2>/dev/null; then
      stop_group
      [[ -f $dir/out ]] && cat "$dir/out"
      [[ -f $dir/err ]] && cat "$dir/err" >&2
      echo "herdr-run: $label run lost (pane closed or runner died); not re-run" >&2
      close_pane
      exit 1
    fi
  fi
done
cat "$dir/out"
cat "$dir/err" >&2
read -r code <"$dir/status"
report idle
sleep_for 3
release_pane
close_pane
exit "$code"
