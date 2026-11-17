#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
fixtures="$root/scripts/test-fixtures/nixos-issue-audit"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fixture runs must never reach live Nix, the store, or GitHub.
mkdir "$tmp/bin"
cat >"$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *'.version'*)
    if [[ "$*" == *nixos-unstable* && "${AUDIT_EQUAL_VERSIONS:-0}" != 1 ]]; then
      printf '2.0'
    else
      printf '1.0'
    fi
    ;;
  *'--apply'*'if b then'*) printf 'true' ;;
  *) echo "unexpected nix call: $*" >&2; exit 99 ;;
esac
EOF
cat >"$tmp/bin/nix-store" <<'EOF'
#!/usr/bin/env bash
echo 'unexpected nix-store call' >&2
exit 99
EOF
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo 'unexpected gh call' >&2
exit 99
EOF
chmod +x "$tmp/bin/nix" "$tmp/bin/nix-store" "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"

# Legacy expectations were checked once against origin/main with these feeds and nix responses.
critical=0
regression=0
for dir in "$fixtures"/*; do
  case_name=${dir##*/}
  mkdir "$tmp/$case_name"
  if [ "$case_name" = security-equal ]; then
    export AUDIT_EQUAL_VERSIONS=1
  else
    unset AUDIT_EQUAL_VERSIONS || true
  fi
  if ! bash "$root/scripts/nixos-issue-audit.sh" --fixture "$dir" --out "$tmp/$case_name" >"$tmp/$case_name/log" 2>&1; then
    cat "$tmp/$case_name/log" >&2
    echo "$case_name: audit failed" >&2
    exit 1
  fi
  while IFS=$'\t' read -r number severity; do
    if ! jq -e -s --argjson n "$number" --arg severity "$severity" \
      '[.[] | select(.n == $n)] | length == 1 and .[0].severity == $severity' \
      "$tmp/$case_name/findings.jsonl" >/dev/null; then
      echo "$case_name: #$number expected $severity" >&2
      exit 1
    fi
    [ "$severity" != CRITICAL ] || critical=$((critical + 1))
    [ "$severity" != REGRESSION ] || regression=$((regression + 1))
  done <"$dir/expected.tsv"
  expected_count=$(wc -l <"$dir/expected.tsv")
  actual_count=$(wc -l <"$tmp/$case_name/findings.jsonl")
  if [ "$actual_count" -ne "$expected_count" ]; then
    echo "$case_name: expected $expected_count findings, got $actual_count" >&2
    exit 1
  fi
  echo "$case_name: $actual_count findings passed"
done

if [ "$critical" -lt 1 ] || [ "$regression" -lt 1 ]; then
  echo 'fixtures must assert CRITICAL and REGRESSION' >&2
  exit 1
fi
