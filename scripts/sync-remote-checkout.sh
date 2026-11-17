#!/usr/bin/env bash
set -uo pipefail

say() { printf 'checkout sync (%s): %s\n' "$host" "$1"; }

sync_checkout() {
  local tree=$1 commit output
  if [[ $host == p620 || $host == "$(hostname)" ]]; then
    say 'local host; skipped'
    return 0
  fi
  if ! git fetch -q origin main >/dev/null 2>&1; then
    say 'could not sync: source fetch failed'
    return 0
  fi
  if ! output=$(git log --first-parent -n 500 --format='%H %T' origin/main 2>/dev/null); then
    say 'could not sync: source history unavailable'
    return 0
  fi
  commit=$(awk -v tree="$tree" '$2 == tree { print $1; exit }' <<<"$output")
  if [[ -z $commit ]]; then
    say 'tree not on origin/main; skipped'
    return 0
  fi
  if output=$(
    timeout 120 ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" env GIT_TERMINAL_PROMPT=0 bash -s -- "$commit" <<'REMOTE'
# Wrapped in a function so bash reads the whole script before running any of it.
main() {
set -uo pipefail
cd "$HOME/.config/nixos" 2>/dev/null || { printf 'could not sync: checkout unavailable\n'; exit 1; }
branch=$(git symbolic-ref -q --short HEAD) || branch=
if [[ $branch != main ]]; then
  printf 'not on main; skipped\n'
  exit 0
fi
if ! status=$(git status --porcelain --ignored=no 2>/dev/null); then
  printf 'could not sync: target status failed\n'
  exit 1
fi
if [[ -n $status ]]; then
  printf 'dirty target; skipped\n'
  exit 0
fi
if ! git fetch -q origin >/dev/null 2>&1; then
  printf 'could not sync: target fetch failed\n'
  exit 1
fi
old=$(git rev-parse HEAD 2>/dev/null) || { printf 'could not sync: target HEAD unavailable\n'; exit 1; }
if [[ $old == "$1" ]]; then
  printf 'already current\n'
  exit 0
fi
if ! git merge-base --is-ancestor HEAD "$1" 2>/dev/null; then
  printf 'target is not an ancestor; skipped\n'
  exit 0
fi
count=$(git rev-list --count "$old..$1" 2>/dev/null) || { printf 'could not sync: commit count failed\n'; exit 1; }
if ! git merge --ff-only --no-overwrite-ignore --no-autostash -q "$1" >/dev/null 2>&1; then
  printf 'could not sync: fast-forward failed\n'
  exit 1
fi
printf 'fast-forwarded %s..%s (%s commits)\n' "$old" "$1" "$count"
}
main "$@"
REMOTE
  ); then
    say "${output//$'\n'/ }"
  else
    if [[ $output == 'could not sync:'* ]]; then
      say "${output//$'\n'/ }"
    else
      say "could not sync: ${output:-ssh failed}"
    fi
  fi
  return 0
}

case ${1:-} in
  around)
    if [[ $# -lt 4 || $3 != -- ]]; then
      printf 'usage: %s around HOST -- COMMAND...\n' "$0" >&2
      exit 2
    fi
    host=$2
    shift 3
    reason=
    if ! status=$(git status --porcelain 2>/dev/null); then
      reason='source status unavailable; skipped'
    elif [[ -n $status ]]; then
      reason='dirty source; skipped'
    else
      if branch=$(git symbolic-ref -q --short HEAD 2>/dev/null); then
        [[ $branch == main ]] || reason='source not on main or origin/main; skipped'
      elif [[ $(git rev-parse HEAD 2>/dev/null) != $(git rev-parse origin/main 2>/dev/null) ]]; then
        reason='source not on main or origin/main; skipped'
      fi
      if [[ -z $reason ]] && ! tree=$(git rev-parse 'HEAD^{tree}' 2>/dev/null); then
        reason='source tree unavailable; skipped'
      fi
    fi
    "$@"
    result=$?
    if ((result != 0)); then
      say 'command failed; skipped'
    elif [[ -z $reason && -n $(git status --porcelain 2>/dev/null) ]]; then
      # An edit while the command ran may have been deployed but is not in the recorded tree.
      say 'source changed during the command; skipped'
    elif [[ -n $reason ]]; then
      say "$reason"
    else
      sync_checkout "$tree"
    fi
    exit "$result"
    ;;
  sync)
    if [[ $# != 3 ]]; then
      printf 'usage: %s sync HOST TREE\n' "$0" >&2
      exit 2
    fi
    host=$2
    sync_checkout "$3"
    ;;
  *)
    printf 'usage: %s {around HOST -- COMMAND...|sync HOST TREE}\n' "$0" >&2
    exit 2
    ;;
esac
