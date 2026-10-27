#!/bin/sh
# Usage: guard-test.sh [path/to/codex-wrapper.sh]
src=${1:-$(dirname "$0")/codex-wrapper.sh}
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
printf '#!%s\nreadlink /proc/self/fd/0\n' "$(command -v sh)" >"$tmp/stub"
chmod +x "$tmp/stub"
sed "s|@real@|$tmp/stub|" "$src" >"$tmp/codex"

fail=0
# check <want: null|pipe> <stdin: pipe|file> <args...>
check() {
  want=$1 in=$2
  shift 2
  if [ "$in" = pipe ]; then
    got=$(printf x | sh "$tmp/codex" "$@" 2>/dev/null)
  else got=$(sh "$tmp/codex" "$@" 2>/dev/null <"$src"); fi
  case $want:$got in
    null:/dev/null | pipe:pipe:*) ;;
    *)
      echo "FAIL ($in) $*: got '$got', want $want" >&2
      fail=1
      ;;
  esac
}

check null pipe exec hi
check null pipe exec --skip-git-repo-check -m o3 hi
check null pipe -c a=b -p implement exec hi
check null pipe e hi
check pipe pipe exec -
check pipe pipe exec
CODEX_EXEC_STDIN=1 check pipe pipe exec hi
check null file exec hi
check pipe pipe exec -m exec
check pipe pipe --version
check pipe pipe login status
check pipe pipe exec resume 0199-uuid -
check pipe pipe exec fork 0199-uuid -
check pipe pipe exec review --base main -
check null pipe exec resume 0199-uuid hi
check null pipe exec resume --last hi
check pipe pipe exec resume 0199-uuid

[ "$fail" = 0 ] && echo "guard-test: all 17 cases pass"
exit "$fail"
