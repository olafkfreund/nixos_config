#!/usr/bin/env bash
# Self-check for the __abbr_expand widget from home/shell/bash.nix.
# Mirrors the generated case statements; fails loudly if expansion breaks.

__abbr_lookup() {
  case "$1" in
    'gst') printf '%s' 'git status' ;;
    'gcm') printf '%s' 'git commit -m' ;;
    'jv') printf '%s' 'just validate' ;;
    *) return 1 ;;
  esac
}

__abbr_lookup_global() {
  case "$1" in
    'G') printf '%s' '| grep -i' ;;
    'NUL') printf '%s' '&>/dev/null' ;;
    *) return 1 ;;
  esac
}

__abbr_expand() {
  local line="${READLINE_LINE}" point="${READLINE_POINT:-0}"
  local before="${line:0:$point}" after="${line:$point}"
  local word="${before##* }"
  local prefix="${before%"$word"}"
  if [[ -z $word ]]; then
    READLINE_LINE="${before} ${after}"
    READLINE_POINT=$((point + 1))
    return
  fi

  local expansion
  if [[ -z ${prefix//[[:space:]]/} ]] && expansion=$(__abbr_lookup "$word"); then
    :
  elif expansion=$(__abbr_lookup_global "$word"); then
    :
  else
    expansion="$word"
  fi

  READLINE_LINE="${prefix}${expansion} ${after}"
  READLINE_POINT=$((${#prefix} + ${#expansion} + 1))
}

fails=0
check() { # desc, in_line, in_point, want_line, want_point
  READLINE_LINE="$2"
  READLINE_POINT="$3"
  __abbr_expand
  if [[ $READLINE_LINE != "$4" || $READLINE_POINT != "$5" ]]; then
    printf 'FAIL %-42s got [%s]@%s want [%s]@%s\n' "$1" "$READLINE_LINE" "$READLINE_POINT" "$4" "$5"
    fails=$((fails + 1))
  else
    printf 'ok   %-42s [%s]@%s\n' "$1" "$READLINE_LINE" "$READLINE_POINT"
  fi
}

# command-position abbreviation
check "command abbr" "gst" 3 "git status " 11
check "command abbr, multiword" "gcm" 3 "git commit -m " 14
# NOT in command position -> must not expand as a command abbr
check "gst as argument" "echo gst" 8 "echo gst " 9
# global abbr expands anywhere
check "global abbr mid-line" "ls G" 4 "ls | grep -i " 13
check "global abbr NUL" "make NUL" 8 "make &>/dev/null " 17
# unknown word passes through with a space appended
check "unknown word" "foobar" 6 "foobar " 7
# plain space on empty buffer
check "empty buffer" "" 0 " " 1
# space after trailing space
check "trailing space" "git " 4 "git  " 5
# cursor mid-line: text after cursor preserved
check "cursor mid-line" "gst --short" 3 "git status  --short" 11
# leading whitespace still counts as command position
check "leading ws command" "  gst" 5 "  git status " 13

if ((fails)); then
  echo "FAILED: $fails"
  exit 1
fi
echo "all abbr expansion checks passed"
