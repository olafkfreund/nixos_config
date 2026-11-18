#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=modules/programs/claude-guard-prepare.sh
source "${BASH_SOURCE[0]%.test.sh}.sh"

check() {
  local actual expected=$2
  [[ -z $expected ]] || expected+=$'\n'
  expected+=$'\034'
  actual=$(
    printf '%s' "$1" | guard_prepare
    printf '\034'
  )
  if [[ $actual != "$expected" ]]; then
    printf 'input: %q\nexpected: %q\nactual: %q\n' "$1" "$expected" "$actual" >&2
    exit 1
  fi
}

runner=just
host=p510
other=razer
verb=nhs

# Split points are kept in the output; only dropped segments disappear.
check "$verb $host && $runner $other" "$verb $host  &&  $runner $other"
check "$verb $host || $runner $other" "$verb $host  ||  $runner $other"
check "$verb $host;$runner $other" "$verb $host ; $runner $other"
check "$verb $host|$runner $other" "$verb $host | $runner $other"
check "$verb $host"$'\n'"$runner $other" "$verb $host"$'\n'"$runner $other"
check "ssh $host 'cd /etc/nixos && $verb'" "ssh $host cd /etc/nixos  &&  $verb"
check "$verb 2>&1 $host" "$verb 2>&1 $host"
# A word right after an unspaced separator still starts a word.
check "true;$verb $host" "true ; $verb $host"
check "true&&$verb $host" "true && $verb $host"
check "true|$verb $host" "true | $verb $host"
check "$runner -n $other" ''
check "$runner --dry-run $host" ''
check "$runner -s $other" ''
check "$runner --show $host" ''
check "$runner -l $host" ''
check "$runner --list $host" ''
check "FOO=1 $runner -n $host" ''
check "$runner -f Justfile -n $host" ''
check "$runner --justfile Justfile --dry-run $host" ''
check "$runner -d . -s $other" ''
check "$runner --working-directory . --show $host" ''
# Any other option ends the walk: its value may look like -n.
check "$runner --unknown -n $host" "$runner --unknown -n $host"
check "$runner --shell-arg -n $host" "$runner --shell-arg -n $host"
check "$runner -f -n $host" "$runner -f -n $host"
check "sudo $runner -n $host" "sudo $runner -n $host"
check "env X=1 $runner -n $host" "env X=1 $runner -n $host"
check "$runner -n \"\$($verb $host)\"" "$runner -n   $verb $host "
check "$runner -n \`$verb $host\`" "$runner -n  $verb $host "
check "$runner -n <($verb $host)" "$runner -n < $verb $host "
check "$runner -n >($verb $host)" "$runner -n > $verb $host "
check "$runner -n $other & $runner $host" "$runner -n $other & $runner $host"
check "$runner $host -n" "$runner $host -n"
check "$runner -n $other && $runner $other" " &&  $runner $other"
check "$runner -n $other || $runner $other" " ||  $runner $other"
check "$runner -n $other;$runner $other" " ; $runner $other"
check "$runner -n $other|$runner $other" " | $runner $other"
check "$runner -n $other"$'\n'"$runner $other" "$runner $other"
# Quotes are removed, as the shell removes them; $ ( ) and backticks become spaces.
check "'$verb' $host" "$verb $host"
check "\"$verb\" $host" "$verb $host"
check "($verb $host)" " $verb $host "
check "\$($verb $host)" "  $verb $host "
check "bash -c '$verb $host'" "bash -c $verb $host"
check "$runner '$host'" "$runner $host"
check "$runner --justfile=\"Justfile\" $host" "$runner --justfile=Justfile $host"

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
ln -s "$(command -v awk)" "$temp_dir/awk"
if PATH=$temp_dir guard_prepare <<<'safe' >/dev/null 2>&1; then
  echo 'missing sed was not reported' >&2
  exit 1
fi
rm "$temp_dir/awk"
ln -s "$(command -v sed)" "$temp_dir/sed"
if PATH=$temp_dir guard_prepare <<<'safe' >/dev/null 2>&1; then
  echo 'missing awk was not reported' >&2
  exit 1
fi

echo 'guard_prepare tests passed'
