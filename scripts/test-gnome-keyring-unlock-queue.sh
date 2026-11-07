#!/usr/bin/env bash
set -u

if (($# != 2)) || [[ ! -x $1/bin/gnome-keyring-daemon || ! -f $2 ]]; then
  printf 'usage: %s <gnome-keyring store path> <expect-file>\n' "$0" >&2
  exit 2
fi

keyring=$1 expect_file=$2 status=0
nixpkgs=$(nix eval --raw .#nixosConfigurations.p620.pkgs.path) || exit 2
while read -r scenario expected extra; do
  [[ -z $scenario || $scenario == \#* ]] && continue
  expected=${expected:-}
  if [[ -n ${extra:-} || ! $scenario =~ ^(abort|hang|dismiss|many|normal)$ || ! $expected =~ ^(ABORT|HANG|OK|INCONCLUSIVE)$ ]]; then
    printf 'invalid expectation: %s %s\n' "$scenario" "$expected" >&2
    exit 2
  fi
  if out=$(nix-build scripts/test-gnome-keyring-unlock-queue.nix \
    --arg nixpkgs "$nixpkgs" --argstr keyring "$keyring" \
    --argstr scenario "$scenario" --argstr nonce "$(date +%s%N)" </dev/null) \
    && result=$(cat "$out") && [[ $result =~ ^result=(ABORT|HANG|OK|INCONCLUSIVE)$ ]]; then
    :
  else
    result=result=INCONCLUSIVE
  fi
  printf '%s %s (expected result=%s)\n' "$scenario" "$result" "$expected"
  if [[ $result == result=INCONCLUSIVE ]]; then
    status=2
  elif [[ $result != "result=$expected" && $status -eq 0 ]]; then
    status=1
  fi
done <"$expect_file"
exit "$status"
