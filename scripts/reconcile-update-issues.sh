#!/usr/bin/env bash
# Close package-update tracking issues once they no longer describe pending work.
#
# Usage:
#   ./scripts/reconcile-update-issues.sh <label> <pinned> <latest>
#
# Each open issue carrying <label> is titled "...: update to <version>". For
# every one:
#
#   version <= pinned            -> DONE        (the bump landed; close as completed)
#   pinned < version < latest    -> SUPERSEDED  (a newer release replaced it)
#   version == latest > pinned   -> kept open   (the one live piece of work)
#
# Why this exists, and why it must run on EVERY watch run: the watch workflows
# used to close only superseded issues, and only inside `if: latest != pinned`.
# The moment the nightly autoupdate landed a version, latest == pinned, that
# step was skipped, and the issue for the version that had just been done was
# never touched. Every release left one behind -- ten claude-code issues piled
# up that way before anyone noticed.
#
# It runs in the watch rather than in package-autoupdate.yml on purpose. The
# autoupdate only reaches a merge step when it performs a bump, so it would miss
# a manual bump -- and it has gone six consecutive days without its schedule
# firing at all. The watch recomputes the pin each run, so closing here is
# self-healing however the version arrived.
#
# Testing without GitHub:
#   ISSUES_JSON='[{"number":1,"title":"x: update to 1.2.0"}]' DRY_RUN=1 \
#     ./scripts/reconcile-update-issues.sh some-label 1.2.0 1.3.0

set -euo pipefail

label="${1:?usage: $0 <label> <pinned> <latest>}"
pinned="${2:?usage: $0 <label> <pinned> <latest>}"
latest="${3:?usage: $0 <label> <pinned> <latest>}"

# a <= b, by version order rather than string order: 2.1.9 < 2.1.10.
ver_le() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]; }

close_issue() {
  local n="$1" reason="$2" comment="$3"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf 'would close #%s (%s)\n' "$n" "$reason"
  else
    gh issue close "$n" --reason "$reason" --comment "$comment" >/dev/null
    printf 'closed #%s (%s)\n' "$n" "$reason"
  fi
}

issues="${ISSUES_JSON:-$(gh issue list --label "$label" --state open --limit 200 --json number,title)}"

printf '%s' "$issues" | jq -r '.[] | "\(.number)\t\(.title)"' \
  | while IFS=$'\t' read -r n title; do
    v="${title##* }"
    # A title that does not end in a version is not ours to judge -- leave it.
    if ! printf '%s' "$v" | grep -Eq '^[0-9]+(\.[0-9]+)+'; then
      printf 'skipping #%s: no version in title "%s"\n' "$n" "$title"
      continue
    fi

    if ver_le "$v" "$pinned"; then
      close_issue "$n" completed \
        "Done: the pin is at **$pinned**, which covers **$v**. Closed automatically by the watch workflow."
    elif [ "$v" != "$latest" ] && ver_le "$v" "$latest"; then
      close_issue "$n" "not planned" \
        "Superseded by a newer release (**$latest**). Closed automatically by the watch workflow."
    else
      printf 'keeping #%s open (%s is the pending release)\n' "$n" "$v"
    fi
  done
