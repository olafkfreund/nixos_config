{ pkgs }:
{ binPath, themeId ? "omarchy", timeoutSecs ? 30, killSecs ? 5 }:
# themeId is spliced into shell and file names unescaped.
assert builtins.match "[a-z0-9-]+" themeId != null;
pkgs.writeShellScript "t3code-omarchy-theme" ''
  set -u
  export PATH="${binPath}''${PATH:+:$PATH}"

  log() {
    printf 't3code-theme: %s\n' "$1" >&2
  }

  if [ -z "''${HOME:-}" ]; then
    log 'HOME unset'
    exit 0
  fi

  export T3CODE_HOME="$HOME/.t3"
  STATE="$T3CODE_HOME/userdata"

  for command in omarchy-theme-set-t3code t3; do
    if ! command -v "$command" >/dev/null 2>&1; then
      log "$command not found"
      exit 0
    fi
  done

  mkdir -p "$STATE"

  if [ ! -f "$HOME/.local/state/omarchy/current/theme/t3code.json" ]; then
    log 'no Omarchy palette staged yet; next activation retries'
    exit 0
  fi

  if omarchy-theme-set-t3code; then
    if grep -qF '{{' "$HOME/.local/state/omarchy/current/theme/t3code.json"; then
      log 'palette has unresolved colours; kept the previous one'
    fi
  else
    status=$?
    log "publisher exited $status"
    exit 0
  fi

  if [ ! -f "$STATE/themes/${themeId}.json" ]; then
    log 'theme ${themeId} not published'
    exit 0
  fi

  currentTheme=$(jq -r '.defaultTheme // empty' "$STATE/settings.json" 2>/dev/null)
  if [ "$currentTheme" = "${themeId}" ]; then
    exit 0
  fi

  output=$(mktemp) || {
    log 'could not create output file'
    exit 0
  }
  if { timeout -k ${toString killSecs} ${toString timeoutSecs} t3 theme set "${themeId}" --base-dir "$T3CODE_HOME"; } >"$output" 2>&1; then
    :
  else
    status=$?
    log "t3 theme set exited $status"
    tail -n 5 "$output" | while IFS= read -r line || [ -n "$line" ]; do
      log "$line"
    done
  fi
  rm -f "$output"
  exit 0
''
