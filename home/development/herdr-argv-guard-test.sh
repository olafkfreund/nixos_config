#!/usr/bin/env bash
set -euo pipefail

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
guard=$dir/guard.bash
log=$dir/log
err=$dir/stderr
scope=$dir/scope
cg=$dir/cgroup
fake=$dir/hc-shell

python3 -c 'import socket, sys; s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$dir/bus"
printf '0::/user.slice/app.slice/hc-hold-1.scope\n' >"$cg"
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
if grep -q '^wrap ' "$HC_TEST_LOG"; then
  printf 'wrapper ran twice\n' >&2
  exit 1
fi
printf 'wrap %s\n' "$$" >> "$HC_TEST_LOG"
printf '0::/user.slice/app.slice/herdr-pane-%s.scope\n' "$$" > "$HC_TEST_SCOPE"
export HC_ARGV_GUARD_CGROUP=$HC_TEST_SCOPE
exec bash "$@"
EOF
chmod +x "$fake"
sed "s|@hcShell@|$fake|" "$1" >"$guard"

check_stderr() {
  sed -e '/cannot set terminal process group/d' -e '/no job control in this shell/d' "$err" >"$dir/other-stderr"
  [ ! -s "$dir/other-stderr" ] || {
    cat "$dir/other-stderr" >&2
    exit 1
  }
}

run() {
  : >"$log"
  : >"$err"
  HC_TEST_LOG=$log HC_TEST_SCOPE=$scope HC_ARGV_GUARD_CGROUP=$cg XDG_RUNTIME_DIR=$dir \
    HC_TERMINAL_ID=t1 "$@" </dev/null 2>"$err" &
  pid=$!
  wait "$pid"
  check_stderr
}

# shellcheck disable=SC2016
cmd='printf "run %s %s\n" "$$" "$0" >> "$HC_TEST_LOG"; printf "arg <%s>\n" "$@" >> "$HC_TEST_LOG"'
run bash --rcfile "$guard" -ic "$cmd" n 'a b' '' '$x' "it's" 'say "hi"'
# shellcheck disable=SC2016
printf 'wrap %s\nrun %s n\narg <a b>\narg <>\narg <$x>\narg <it\047s>\narg <say "hi">\n' "$pid" "$pid" >"$dir/expected"
diff -u "$dir/expected" "$log"

# shellcheck disable=SC2016
cmd='printf "run %s\n" "$$" >> "$HC_TEST_LOG"; exec bash --rcfile "$HC_TEST_GUARD" -ic "$HC_TEST_SECOND"'
# shellcheck disable=SC2016
second='printf "run2 %s\n" "$$" >> "$HC_TEST_LOG"'
HC_TEST_GUARD=$guard HC_TEST_SECOND=$second run bash --rcfile "$guard" -ic "$cmd"
printf 'wrap %s\nrun %s\nrun2 %s\n' "$pid" "$pid" "$pid" >"$dir/expected"
diff -u "$dir/expected" "$log"

for cgroup in 'herdr-pane-9.scope' 'herdr-pane-9.scope/child.scope'; do
  printf '0::/user.slice/app.slice/%s\n' "$cgroup" >"$cg"
  run bash --rcfile "$guard" -ic "$second"
  printf 'run2 %s\n' "$pid" >"$dir/expected"
  diff -u "$dir/expected" "$log"
done

printf '0::/user.slice/app.slice/hc-hold-1.scope\n' >"$cg"
run env -u HC_TERMINAL_ID bash --rcfile "$guard" -ic "$second"
printf 'run2 %s\n' "$pid" >"$dir/expected"
diff -u "$dir/expected" "$log"

run env XDG_RUNTIME_DIR="$dir/no-bus" bash --rcfile "$guard" -ic "$second"
printf 'run2 %s\n' "$pid" >"$dir/expected"
diff -u "$dir/expected" "$log"

run env HC_ARGV_GUARD_CGROUP="$dir/missing" bash --rcfile "$guard" -ic "$second"
printf 'run2 %s\n' "$pid" >"$dir/expected"
diff -u "$dir/expected" "$log"
