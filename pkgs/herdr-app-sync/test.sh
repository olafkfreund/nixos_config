#!/usr/bin/env bash
set -euo pipefail

target=$1
root=$(mktemp -d)
trap 'rm -r "${root:?}"' EXIT
export HOME="$root/home" HERDR_APP_HOME="$root/home/.config/herdr-app"
source_dir="$root/source"
mkdir -p "$root/bin" "$source_dir/mods/demo" "$source_dir/layouts" "$HERDR_APP_HOME" "$root/outside"
printf 'keep\n' >"$root/outside/sentinel"
printf '#!%s\n' "$(command -v bash)" >"$root/bin/herdr-app"
cat >>"$root/bin/herdr-app" <<'EOF'
case $1 in
  check) [[ -f $2/main.js && ! -e $2/BAD ]] || exit 1; touch "$2/gpui-kit.d.ts" "$2/jsconfig.json" ;;
  status|do) printf '%s\n' "$*" >> "$HOME/calls" ;;
esac
EOF
chmod +x "$root/bin/herdr-app"
export PATH="$root/bin:$PATH"
printf '{"mods":["demo"],"layouts":["freund"],"first_layout":"freund"}\n' >"$source_dir/managed.json"
printf 'original\n' >"$source_dir/mods/demo/mod.js"
printf 'export default {}\n' >"$source_dir/mods/demo/main.js"
printf '{"id":"freund","type":"row"}\n' >"$source_dir/layouts/freund.json"
printf '{"theme":"omarchy"}\n' >"$source_dir/settings.json"
printf '{"global":{"ours":"go"}}\n' >"$source_dir/keys.json"
state="$HOME/.local/state/herdr-app-sync"

# Existing untracked content is backed up on first take-over.
mkdir -p "$HERDR_APP_HOME/mods/demo" "$HERDR_APP_HOME/layouts"
printf 'old\n' >"$HERDR_APP_HOME/mods/demo/mod.js"
printf '{"old":true}\n' >"$HERDR_APP_HOME/layouts/freund.json"
printf '{"global":{"user":"keep"}}\n' >"$HERDR_APP_HOME/keys.json"
"$target" "$source_dir"
[[ $(cat "$HERDR_APP_HOME/mods/demo/mod.js") == original ]]
[[ $(jq -r '.id' "$HERDR_APP_HOME/layouts/freund.json") == freund ]]
[[ $(jq -r '.global.user' "$HERDR_APP_HOME/keys.json") == keep ]]
[[ $(jq -r '.global.ours' "$HERDR_APP_HOME/keys.json") == go ]]
[[ -f "$HERDR_APP_HOME/mods/demo/gpui-kit.d.ts" ]]
[[ $(find "$state/backups" -type f | wc -l) -eq 3 ]]
[[ $state != "$HERDR_APP_HOME"/* ]]
[[ $(grep -c '^do layout.switch --name freund$' "$HOME/calls") -eq 1 ]]
before=$(sha256sum "$state/manifest.json")
"$target" "$source_dir"
[[ $(sha256sum "$state/manifest.json") == "$before" ]]
[[ $(grep -c '^do layout.switch --name freund$' "$HOME/calls") -eq 1 ]]
[[ $(find "$state/backups" -type f | wc -l) -eq 3 ]]

# A changed source replaces an unchanged install without another backup.
printf 'upstream\n' >"$source_dir/mods/demo/mod.js"
"$target" "$source_dir"
[[ $(cat "$HERDR_APP_HOME/mods/demo/mod.js") == upstream ]]
[[ $(find "$state/backups" -name demo -type d | wc -l) -eq 2 ]]

# A local edit is backed up even when the source has not changed.
printf 'local\n' >"$HERDR_APP_HOME/mods/demo/mod.js"
"$target" "$source_dir"
[[ $(cat "$HERDR_APP_HOME/mods/demo/mod.js") == upstream ]]
[[ $(find "$state/backups" -name mod.js | wc -l) -eq 3 ]]

# An absent item is installed even with a manifest entry.
rm -rf "${HERDR_APP_HOME:?}/mods/demo"
"$target" "$source_dir"
[[ $(cat "$HERDR_APP_HOME/mods/demo/mod.js") == upstream ]]

# A failed check keeps the current install and manifest.
touch "$source_dir/mods/demo/BAD"
before=$(sha256sum "$state/manifest.json")
"$target" "$source_dir"
[[ $(cat "$HERDR_APP_HOME/mods/demo/mod.js") == upstream ]]
[[ $(sha256sum "$state/manifest.json") == "$before" ]]
rm -f "${source_dir:?}/mods/demo/BAD"

# A malformed layout leaves the installed layout and manifest intact.
printf '[]\n' >"$source_dir/layouts/freund.json"
before=$(sha256sum "$state/manifest.json")
"$target" "$source_dir"
[[ $(jq -r '.id' "$HERDR_APP_HOME/layouts/freund.json") == freund ]]
[[ $(sha256sum "$state/manifest.json") == "$before" ]]

# Invalid installed JSON stays untouched; valid JSON gets a backup before merge.
printf 'broken\n' >"$HERDR_APP_HOME/settings.json"
"$target" "$source_dir"
[[ $(cat "$HERDR_APP_HOME/settings.json") == broken ]]
printf '{"local":true}\n' >"$HERDR_APP_HOME/settings.json"
"$target" "$source_dir"
[[ $(jq -r '.theme' "$HERDR_APP_HOME/settings.json") == omarchy ]]
[[ $(jq -r '.local' "$state"/backups/*/settings.json | tail -1) == true ]]

[[ -f "$root/outside/sentinel" ]]
[[ ! -e "$root/outside/manifest.json" ]]
HERDR_APP_HOME="$root/absent-home" "$target" "$source_dir"
[[ ! -e "$root/absent-home" ]]
