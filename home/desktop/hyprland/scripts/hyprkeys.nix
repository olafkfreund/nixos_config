{ pkgs, ... }:

pkgs.writeShellScriptBin "rofi-hyprkeys" ''
hyprkeys --binds --from-ctl --json | jq -r 'range(0, length) as $i | "\($i) \(.[$i].mods) \(.[$i].key) \(.[$i].dispatcher) \(.[$i].arg)"' | rofi -dmenu -p 'Hyprland Keybinds'
''
