#!/usr/bin/env bash
# Status-only replacement for upstream's bin/altscape-binds: NixOS owns the
# binds file, so this writes and reloads nothing.
set -uo pipefail

err=""
if [[ "${1:-}" == "sync" && ("${2:-}" == "super" || "${2:-}" == "off") ]]; then
  err="Alt+Tab is set by NixOS (hosts/common/nixos/omarchy-altscape.nix)"
fi

if binds=$(@hyprctl@ -j binds 2>/dev/null); then
  if printf '%s' "$binds" | @jq@ -e 'any(.[]; (.key|ascii_downcase)=="tab" and .modmask==8 and ((.arg//"")|contains("io.github.qempexe.altscape")))' >/dev/null 2>&1; then
    active=true
  else
    active=false
  fi
else
  active=unknown
fi

# shellcheck disable=SC2016 # jq program, not shell
@jq@ -nc --arg file "$HOME/.config/hypr/altscape-binds.lua" --arg active "$active" --arg err "$err" \
  '{ok:true,format:"lua",file:$file,shortcut:"alt",changed:false,active:$active,error:$err}'
