#!/usr/bin/env bash

log() {
  systemd-cat -t herdr-app-sync <<<"$*" 2>/dev/null || printf '%s\n' "$*" >&2
}

hash_item() {
  if [[ -d $1 ]]; then
    (cd "$1" && find -L . -type f ! -name gpui-kit.d.ts ! -name jsconfig.json -print0 | sort -z | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1)
  else
    sha256sum "$1" | cut -d' ' -f1
  fi
}

save_manifest() {
  local temp
  temp=$(mktemp "$state/.manifest.XXXXXX") || return 1
  if jq --arg kind "$1" --arg name "$2" --arg hash "$3" '.[$kind][$name] = $hash' "$manifest" >"$temp"; then
    mv -f "$temp" "$manifest"
  else
    rm -f "${temp:?}"
    return 1
  fi
}

install_item() {
  local kind=$1 name=$2 src=$3 dest=$4 old source_hash disk_hash temp backup_name out
  [[ $name =~ ^[a-zA-Z0-9_-]+$ ]] || {
    log "invalid $kind name: $name"
    return 1
  }
  [[ -e $src ]] || {
    log "missing source: $src"
    return 1
  }
  old=$(jq -r --arg kind "$kind" --arg name "$name" '.[$kind][$name] // empty' "$manifest") || return 1
  source_hash=$(hash_item "$src") || return 1
  if [[ -e $dest ]]; then
    disk_hash=$(hash_item "$dest") || return 1
    [[ -n $old && $disk_hash == "$old" && $source_hash == "$old" ]] && return 0
  fi

  if [[ $kind == mods ]]; then
    temp="$app/mods/.sync-$name.$$"
    mkdir -p "$temp" || return 1
    rsync -rL --chmod=u+w "$src/" "$temp/" || {
      rm -rf "${temp:?}"
      return 1
    }
    if ! out=$(herdr-app check "$temp" 2>&1); then
      log "check failed: $src: $out"
      rm -rf "${temp:?}"
      return 1
    fi
  else
    temp="$app/layouts/.sync-$name.$$.json"
    cp "$src" "$temp" || return 1
    chmod u+w "$temp" || return 1
    if ! jq -e 'type == "object" and (.id | type == "string") and (.type | type == "string")' "$temp" >/dev/null; then
      log "invalid layout: $src"
      rm -f "${temp:?}"
      return 1
    fi
  fi

  if [[ -e $dest ]]; then
    mkdir -p "$backup/$kind" || return 1
    backup_name=$name
    [[ $kind == layouts ]] && backup_name+=.json
    mv "$dest" "$backup/$kind/$backup_name" || return 1
    log "backup: $backup/$kind/$backup_name"
  fi
  if mv "$temp" "$dest"; then
    save_manifest "$kind" "$name" "$source_hash"
  else
    log "install failed: $dest"
    return 1
  fi
}

merge_json() {
  local name=$1 src="$source_dir/$1" dest="$app/$1" merged
  [[ -f $src ]] || return 0
  if ! jq -e 'type == "object"' "$src" >/dev/null; then
    log "invalid JSON: $src"
    return 1
  fi
  if [[ -e $dest ]] && ! jq -e 'type == "object"' "$dest" >/dev/null; then
    log "invalid JSON: $dest"
    return 1
  fi
  merged=$(mktemp "$app/.sync-$name.XXXXXX") || return 1
  if [[ -e $dest ]]; then
    jq -s '.[0] * .[1]' "$dest" "$src" >"$merged" || {
      rm -f "${merged:?}"
      return 1
    }
    if cmp -s <(jq -S . "$dest") <(jq -S . "$merged"); then
      rm -f "${merged:?}"
      return 0
    fi
    mkdir -p "$backup" || return 1
    cp "$dest" "$backup/$name" || return 1
    log "backup: $backup/$name"
  else
    cp "$src" "$merged" || return 1
  fi
  mv "$merged" "$dest"
}

main() {
  local source_dir=${1:-"$HOME/.config/herdr-app-sync/source"}
  local app=${HERDR_APP_HOME:-"$HOME/.config/herdr-app"}
  local state="$HOME/.local/state/herdr-app-sync"
  local manifest="$state/manifest.json" backup name
  [[ -d $app ]] || return 0
  [[ -f $source_dir/managed.json ]] || {
    log "missing managed.json: $source_dir"
    return 0
  }
  if ! jq -e '.mods | type == "array"' "$source_dir/managed.json" >/dev/null \
    || ! jq -e '.layouts | type == "array"' "$source_dir/managed.json" >/dev/null; then
    log "invalid managed.json: $source_dir/managed.json"
    return 0
  fi
  mkdir -p "$app/mods" "$app/layouts" "$state" || return 1
  [[ -f $manifest ]] || printf '{"mods":{},"layouts":{},"layout_switched":false}\n' >"$manifest"
  jq -e 'type == "object"' "$manifest" >/dev/null || {
    log "invalid manifest: $manifest"
    return 0
  }
  backup="$state/backups/$(date -u +%Y%m%dT%H%M%S.%N)-$$"

  while IFS= read -r name; do
    install_item mods "$name" "$source_dir/mods/$name" "$app/mods/$name" || log "sync failed: mod $name"
  done < <(jq -r '.mods[]' "$source_dir/managed.json")
  while IFS= read -r name; do
    install_item layouts "$name" "$source_dir/layouts/$name.json" "$app/layouts/$name.json" || log "sync failed: layout $name"
  done < <(jq -r '.layouts[]' "$source_dir/managed.json")
  merge_json settings.json || log "sync failed: settings.json"
  merge_json keys.json || log "sync failed: keys.json"

  name=$(jq -r '.first_layout // empty' "$source_dir/managed.json")
  if [[ -n $name && $(jq -r '.layout_switched // false' "$manifest") == false && -f $app/layouts/$name.json ]] \
    && jq -e --arg name "$name" '.layouts[$name] != null' "$manifest" >/dev/null; then
    if herdr-app status >/dev/null 2>&1; then
      if herdr-app "do" layout.switch --name "$name"; then
        local temp
        temp=$(mktemp "$state/.manifest.XXXXXX") || return 1
        jq '.layout_switched = true' "$manifest" >"$temp" && mv "$temp" "$manifest"
      fi
    elif [[ -n ${HERDR_APP_SYNC_RUNNING:-} ]]; then
      # Window launch: the app is not up yet, so switch once it answers.
      # shellcheck disable=SC2016 # expanded by the inner sh
      setsid -f sh -c 'for _ in $(seq 60); do herdr-app status >/dev/null 2>&1 && exec "$0" "$1"; sleep 1; done' \
        "$0" "$source_dir" >/dev/null 2>&1 || :
    fi
  fi
}

main "$@" || log "sync failed"
exit 0
