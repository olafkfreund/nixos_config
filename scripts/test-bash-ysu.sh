#!/usr/bin/env bash
# Self-check for the __ysu_check preexec hook from home/shell/bash.nix.
# (zsh-you-should-use has no bash port; this is our reimplementation over
# bash-preexec. Mirrors the function body — keep the two in sync.)

__ysu_check() {
  local cmd="$1"
  [[ -z $cmd ]] && return 0

  local line name value best_name="" best_len=0
  while IFS= read -r line; do
    line=${line#alias }
    name=${line%%=*}
    value=${line#*=}
    # alias output single-quotes the value; unwrap it.
    value=${value#\'}
    value=${value%\'}
    [[ -z $name || -z $value || $name == "$line" ]] && continue
    # Never suggest the alias for its own expansion, or we nag on every
    # aliased command the user already typed via the alias.
    [[ $cmd == "$name" || $cmd == "$name "* ]] && return 0
    if [[ $cmd == "$value" || $cmd == "$value "* ]] && ((${#value} > best_len)); then
      best_name=$name
      best_len=${#value}
    fi
  done < <(alias 2>/dev/null)

  [[ -n $best_name ]] && printf '\033[2mysu: alias %s exists for this\033[0m\n' "$best_name"
  return 0
}

# ---- checks ----
alias gc='git commit -v'
alias gst='git status'
alias ls='eza --icons=auto'

fails=0
check() { # desc, cmd, want (substring, or empty for no output)
  local got
  got=$(__ysu_check "$2")
  if [[ -z $3 ]]; then
    if [[ -n $got ]]; then
      printf 'FAIL %-38s expected silence, got [%s]\n' "$1" "$got"
      fails=$((fails + 1))
    else
      printf 'ok   %-38s (silent)\n' "$1"
    fi
  elif [[ $got == *"$3"* ]]; then
    printf 'ok   %-38s %s\n' "$1" "$3"
  else
    printf 'FAIL %-38s want [%s] got [%s]\n' "$1" "$3" "$got"
    fails=$((fails + 1))
  fi
}

check "exact alias expansion" "git commit -v" 'gc'
check "expansion plus args" "git commit -v -m hi" 'gc'
check "other alias" "git status" 'gst'
check "already used the alias" "gc -m hi" ''
check "alias name alone" "gst" ''
check "unrelated command" "make build" ''
check "empty command" "" ''
check "prefix but not word boundary" "git commit -vvv" ''
check "longest match wins" "eza --icons=auto -l" 'ls'

if ((fails)); then
  echo "FAILED: $fails"
  exit 1
fi
echo "all you-should-use checks passed"
