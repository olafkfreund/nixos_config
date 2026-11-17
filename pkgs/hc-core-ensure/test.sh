#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
socket_pid=
trap '[[ -z "$socket_pid" ]] || kill "$socket_pid" 2>/dev/null || :; rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/runtime"
export XDG_RUNTIME_DIR="$tmp/runtime" HC_LOG="$tmp/hc.log" RUN_LOG="$tmp/run.log" CAT_LOG="$tmp/cat.log"

bash_path=$(command -v bash)
printf '#!%s\n' "$bash_path" >"$tmp/bin/hc"
cat >>"$tmp/bin/hc" <<'EOF'
printf '%s inner=%s\n' "$*" "${HC_CORE_ENSURE_INNER+set}" >>"$HC_LOG"
case "$*" in
  'server status') [[ -e "$HC_UP" ]] ;;
  'server start'|'server restart --fresh')
    if [[ -n "${HC_BLOCK:-}" && ! -e "$HC_BLOCK.ready" ]]; then
      printf 'ready\n' >"$HC_BLOCK.ready"
      read -r _ <"$HC_BLOCK"
    fi
    [[ -z "${HC_FAIL:-}" ]] ;;
esac
EOF
printf '#!%s\n' "$bash_path" >"$tmp/bin/systemd-run"
cat >>"$tmp/bin/systemd-run" <<'EOF'
printf '%s\n' "$*" >>"$RUN_LOG"
while [[ "$1" != -- ]]; do
  [[ "$1" == --setenv=* ]] && setting=${1#--setenv=}
  shift
done
shift
export "$setting"
"$@"
EOF
printf '#!%s\n' "$bash_path" >"$tmp/bin/systemd-cat"
cat >>"$tmp/bin/systemd-cat" <<'EOF'
cat >>"$CAT_LOG"
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" HC_UP="$tmp/up"
{
  printf '#!%s\nset -euo pipefail\n' "$bash_path"
  sed "s|@hc@|$tmp/bin/hc|g" "$1"
} >"$tmp/bin/hc-core-ensure"
chmod +x "$tmp/bin/hc-core-ensure"
script="$tmp/bin/hc-core-ensure"

python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(); time.sleep(120)' "$XDG_RUNTIME_DIR/bus" &
socket_pid=$!
for _ in {1..100}; do
  [[ -S "$XDG_RUNTIME_DIR/bus" ]] && break
  sleep 0.01
done
[[ -S "$XDG_RUNTIME_DIR/bus" ]]

reset() {
  : >"$HC_LOG"
  : >"$RUN_LOG"
  : >"$CAT_LOG"
  rm -f "$HC_UP"
}
expect_hc() { diff -u <(printf '%s' "$1") "$HC_LOG"; }
expect_log() { [[ $(wc -l <"$CAT_LOG") == 1 ]] && grep -q "$1" "$CAT_LOG"; }

reset
touch "$HC_UP"
"$script" login
grep -q -- '--setenv=HC_CORE_ENSURE_INNER=1 -- .*hc-core-ensure login' "$RUN_LOG"
expect_hc $'server status inner=\nserver restart --fresh inner=\n'
expect_log 'login: restart --fresh'

reset
"$script" login
expect_hc $'server status inner=\nserver start inner=\n'
expect_log 'login: start'

reset
"$script" launch
expect_hc $'server status inner=\nserver start inner=\n'
expect_log 'launch: start'

reset
touch "$HC_UP"
"$script" launch
expect_hc $'server status inner=\n'
expect_log 'launch: core running'

reset
export HC_FAIL=1
"$script" launch
expect_hc $'server status inner=\nserver start inner=\n'
expect_log 'launch: start failed'
unset HC_FAIL

reset
kill "$socket_pid" 2>/dev/null || :
wait "$socket_pid" 2>/dev/null || :
rm "$XDG_RUNTIME_DIR/bus"
"$script" login
expect_hc ''
[[ ! -s "$RUN_LOG" ]]
expect_log 'login: no user bus'
python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(); time.sleep(120)' "$XDG_RUNTIME_DIR/bus" &
socket_pid=$!
for _ in {1..100}; do
  [[ -S "$XDG_RUNTIME_DIR/bus" ]] && break
  sleep 0.01
done

reset
HC_CORE_ENSURE_LOCK_WAIT=1 flock "$XDG_RUNTIME_DIR/hc-core-ensure.lock" -c 'sleep 2' &
lock_pid=$!
sleep 0.1
HC_CORE_ENSURE_LOCK_WAIT=1 "$script" launch
wait "$lock_pid"
expect_hc ''
expect_log 'launch: busy'

reset
"$script" bogus
expect_hc ''
expect_log 'bogus: unknown mode'

reset
export HC_BLOCK="$tmp/block"
mkfifo "$HC_BLOCK"
"$script" launch &
first=$!
for _ in {1..100}; do
  [[ -e "$HC_BLOCK.ready" ]] && break
  sleep 0.01
done
[[ -e "$HC_BLOCK.ready" ]]
"$script" launch &
second=$!
sleep 0.1
expect_hc $'server status inner=\nserver start inner=\n'
printf 'go\n' >"$HC_BLOCK"
unset HC_BLOCK
wait "$first" "$second"
expect_hc $'server status inner=\nserver start inner=\nserver status inner=\nserver start inner=\n'
[[ $(wc -l <"$CAT_LOG") == 2 ]]
printf 'hc-core-ensure fake tests passed\n'
