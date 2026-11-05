# Moves selected Omarchy plugins off the bar once per host. A marker per id
# means later changes in Settings stick.
# Use: local.omarchy.barFreeOnce = [ "<plugin id>" ];
{ config, lib, pkgs, ... }:
let
  ids = config.local.omarchy.barFreeOnce;
in
{
  options.local.omarchy.barFreeOnce = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Omarchy plugin ids to move off the bar once per host.";
  };

  config.home-manager.users.olafkfreund.xdg.configFile."omarchy/hooks/post-boot.d/zz-bar-free-once" = lib.mkIf (ids != [ ]) {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      # omarchy-shell comes from the session PATH.
      export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.diffutils pkgs.systemd ]}:$PATH
      conf="''${XDG_CONFIG_HOME:-$HOME/.config}"
      file="$conf/omarchy/shell.json"
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/nixarchy-local/bar-free-once"
      export OMARCHY_SHELL_IPC_TIMEOUT=''${OMARCHY_SHELL_IPC_TIMEOUT:-30s}

      todo=()
      for id in ${lib.escapeShellArgs ids}; do
        [ -e "$state/$id" ] || todo+=("$id")
      done
      [ "''${#todo[@]}" -eq 0 ] && exit 0

      up=
      for _ in $(seq 120); do
        if omarchy-shell shell ping >/dev/null 2>&1; then
          up=1
          break
        fi
        sleep 1
      done
      [ -n "$up" ] || exit 0

      stable=0
      previous=
      for _ in $(seq 60); do
        current=$(stat -c %y "$file") || exit 0
        if [ "$current" = "$previous" ]; then
          stable=$((stable + 1))
          [ "$stable" -ge 5 ] && break
        else
          stable=0
        fi
        previous=$current
        sleep 1
      done
      [ "$stable" -ge 5 ] || exit 0
      before=$(stat -c %y "$file") || exit 0

      movable=()
      for id in "''${todo[@]}"; do
        if [ -d "$conf/omarchy/plugins/$id" ] && ${pkgs.jq}/bin/jq -e --arg id "$id" '
          [.bar.layout | .[] | select(type == "array") | .[] | select(type == "object" and .id == $id)] | length > 0
        ' "$file" >/dev/null; then
          movable+=("$id")
        fi
      done

      if [ "''${#movable[@]}" -gt 0 ]; then
        wanted=$(${pkgs.jq}/bin/jq -n '$ARGS.positional' --args "''${movable[@]}") || exit 0
        tmp=$(mktemp "$file.XXXXXX") || exit 0
        trap 'rm -f "$tmp"' EXIT
        ${pkgs.jq}/bin/jq --argjson ids "$wanted" '
          reduce $ids[] as $id (.;
            .bar.layout |= with_entries(
              if (.value | type) == "array" then
                .value |= map(select((type == "object" and .id == $id) | not))
              else . end
            ) |
            if any(.plugins[]?; .id == $id) then . else .plugins += [{id: $id}] end
          )
        ' "$file" >"$tmp" || exit 0
        if ! cmp -s "$file" "$tmp"; then
          [ "$(stat -c %y "$file")" = "$before" ] || exit 0
          chmod --reference="$file" "$tmp" || exit 0
          mv -- "$tmp" "$file" || exit 0
        fi
      fi

      sleep 3
      for id in "''${todo[@]}"; do
        if ${pkgs.jq}/bin/jq -e --arg id "$id" '
          any(.plugins[]?; .id == $id) and
          ([.bar.layout | .[] | select(type == "array") | .[] |
            select(type == "object" and (.id == $id or any(.widgets[]?; . == $id)))] | length == 0)
        ' "$file" >/dev/null; then
          mkdir -p "$state"
          touch "$state/$id"
        else
          printf '%s: not enabled off the bar\n' "$id" | systemd-cat -t omarchy-bar-free-once
        fi
      done
    '';
  };
}
