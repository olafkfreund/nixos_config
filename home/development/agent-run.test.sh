#!/usr/bin/env bash
set -euo pipefail

runner=$(cd "$(dirname "$0")" && pwd)/agent-run.sh
source_repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
git -c advice.detachedHead=false clone -q --shared "$source_repo" "$tmp/repo"
cd "$tmp/repo"
git switch -qc t
base=$(git rev-parse HEAD)
echo prompt >"$tmp/prompt"

cat >"$tmp/bin/agy-implement" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
count=$(cat "$AGENT_TEST_COUNT_FILE" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$AGENT_TEST_COUNT_FILE"
if [[ ${AGENT_TEST_MODE:-} == retry && $count == 1 ]]; then
  echo 'connecting to sandbox server' >&2
  exit 1
fi
if [[ ${AGENT_TEST_MODE:-} == exit ]]; then exit 7; fi
if [[ ${AGENT_TEST_MODE:-} != empty_diff ]]; then echo changed > README.md; fi
if [[ ${AGENT_TEST_MODE:-} == head_moved ]]; then git update-ref HEAD "$(git rev-parse HEAD^)"; fi
status=SUCCESS
denied='[]'
response='done'
case ${AGENT_TEST_MODE:-} in
  failed) status=FAILED ;;
  denied) denied='["blocked"]' ;;
  empty_response) response='   ' ;;
esac
jq -cn --arg status "$status" --argjson denied_actions "$denied" --arg response "$response" '{status: $status, denied_actions: $denied_actions, response: $response}'
STUB
cat >"$tmp/bin/codex-implement" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
count=$(cat "$AGENT_TEST_COUNT_FILE" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$AGENT_TEST_COUNT_FILE"
if [[ ${AGENT_TEST_MODE:-} == retry && $count == 1 ]]; then
  echo 'connecting to sandbox server' >&2
  exit 1
fi
if [[ ${AGENT_TEST_MODE:-} == exit ]]; then exit 7; fi
if [[ ${AGENT_TEST_MODE:-} != empty_diff ]]; then echo changed > README.md; fi
if [[ ${AGENT_TEST_MODE:-} == head_moved ]]; then git update-ref HEAD "$(git rev-parse HEAD^)"; fi
while (( $# )); do
  if [[ $1 == -o ]]; then shift; output=$1; fi
  shift
done
if [[ ${AGENT_TEST_MODE:-} == empty_response ]]; then echo '   ' > "$output"; else echo done > "$output"; fi
STUB
chmod +x "$tmp/bin/agy-implement" "$tmp/bin/codex-implement"
export PATH="$tmp/bin:$PATH" AGENT_TEST_COUNT_FILE="$tmp/count"

total=0
check() {
  local tool=$1 mode=$2 expected_rc=$3 expected_reason=$4 expected_count=${5:-1}
  git update-ref HEAD "$base"
  git restore -- README.md
  rm -f "$AGENT_TEST_COUNT_FILE"
  if output=$(AGENT_TEST_MODE="$mode" bash "$runner" "$tool" "$tmp/prompt"); then
    rc=0
  else
    rc=$?
  fi
  [[ $rc == "$expected_rc" ]]
  [[ $(printf '%s\n' "$output" | wc -l) -eq 1 ]]
  jq -e --arg tool "$tool" --arg reason "$expected_reason" --argjson ok "$([[ $expected_rc == 0 ]] && echo true || echo false)" \
    '.tool == $tool and .reason == $reason and .ok == $ok and (.changed | type == "array") and (.head_moved | type == "boolean") and (.log | type == "string")' <<<"$output" >/dev/null
  [[ $(cat "$AGENT_TEST_COUNT_FILE") == "$expected_count" ]]
  if [[ $mode == head_moved ]]; then jq -e '.head_moved == true' <<<"$output" >/dev/null; fi
  if [[ $expected_rc == 0 ]]; then jq -e '.changed == ["README.md"]' <<<"$output" >/dev/null; fi
  total=$((total + 1))
}

check agy success 0 ''
check codex success 0 ''
check agy exit 1 'tool exited 7'
check codex exit 1 'tool exited 7'
check agy failed 1 'agy status is not SUCCESS'
check agy denied 1 'agy denied actions'
check agy empty_response 1 'empty response'
check codex empty_response 1 'empty response'
check agy empty_diff 1 'empty diff'
check codex empty_diff 1 'empty diff'
check agy head_moved 1 'HEAD moved'
check codex head_moved 1 'HEAD moved'
check agy retry 0 '' 2
check codex retry 0 '' 2

git switch -qc main
rm -f "$AGENT_TEST_COUNT_FILE"
if output=$(bash "$runner" agy "$tmp/prompt"); then rc=0; else rc=$?; fi
[[ $rc == 2 && ! -e $AGENT_TEST_COUNT_FILE ]]
jq -e '.ok == false and .reason == "refusing shared checkout or main branch"' <<<"$output" >/dev/null
total=$((total + 1))
printf 'ok %s/%s\n' "$total" "$total"
