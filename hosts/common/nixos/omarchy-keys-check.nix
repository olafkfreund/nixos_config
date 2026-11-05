{ pkgs, ... }:
let
  hypr-keys-check = pkgs.writeShellApplication {
    name = "hypr-keys-check";
    runtimeInputs = [ pkgs.jq pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.gawk ];
    text = ''
      keys="''${XDG_CONFIG_HOME:-$HOME/.config}/hypr/repo-keys.json"
      docs=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --keys) keys="$2"; shift 2 ;;
          --docs) docs="$2"; shift 2 ;;
          *) echo "usage: hypr-keys-check [--keys FILE] [--docs FILE]" >&2; exit 2 ;;
        esac
      done

      jq -e '(.keys | type == "array") and (.external | type == "array") and (.unbind | type == "array") and ((.keys + .external) | length > 0)' "$keys" >/dev/null \
        || { echo "FAIL: cannot read a key declaration from $keys"; exit 1; }

      # shellcheck disable=SC2016
      # Canonical chord: SUPER, CTRL, ALT, SHIFT, then the key.
      canon='def canon:
        [split("[+ ]+"; "g")[] | select(. != "") | ascii_upcase] as $p
        | ($p[:-1]) as $pre
        | ([("SUPER","CTRL","ALT","SHIFT") as $m | select($pre | index($m)) | $m] | join("+")) as $mods
        | (($pre | map(select(. != "SUPER" and . != "CTRL" and . != "ALT" and . != "SHIFT"))) + [$p[-1]])
        | [$mods] + . | map(select(. != "")) | join("+");'

      raw=$(hyprctl binds -j) || { echo "FAIL: hyprctl binds -j failed; run this inside a session"; exit 1; }
      binds=$(printf '%s\n' "$raw" | jq -r "$canon"'
        def mods($m): [(if ($m/64|floor)%2==1 then "SUPER" else empty end),
                       (if ($m/4|floor)%2==1 then "CTRL" else empty end),
                       (if ($m/8|floor)%2==1 then "ALT" else empty end),
                       (if $m%2==1 then "SHIFT" else empty end)];
        .[] | select(.submap == "" and (.release | not) and (.mouse | not) and .key != "")
        | ((mods(.modmask) + [.key]) | join("+") | canon) + "\t" + .description')

      menu=$(timeout 30 omarchy-menu-keybindings --print </dev/null) || { echo "FAIL: omarchy-menu-keybindings --print failed or timed out"; exit 1; }
      menu=$(printf '%s\n' "$menu" | sed 's/→.*//' | jq -R -r "$canon"' select(. != "") | canon')

      fail=0
      problem() { echo "FAIL: $*"; fail=1; }

      while IFS=$'\t' read -r chord desc; do
        got=$(printf '%s\n' "$binds" | awk -F'\t' -v c="$chord" '$1 == c { print $2; found=1 } END { exit !found }') \
          || { problem "no bind for $chord ($desc)"; continue; }
        printf '%s\n' "$got" | grep -xF -- "$desc" >/dev/null || problem "$chord has description '$got', declared '$desc'"
      done < <(jq -r "$canon"' (.keys + .external)[] | [(.key | canon), .description] | @tsv' "$keys")

      while IFS=$'\t' read -r chord desc; do
        printf '%s\n' "$menu" | grep -xF -- "$chord" >/dev/null || problem "$chord ($desc) missing from the keybindings menu"
      done < <(jq -r "$canon"' (.keys + .external)[] | [(.key | canon), .description] | @tsv' "$keys")

      while IFS=$'\t' read -r chord desc; do
        printf '%s\n' "$binds" | cut -f1 | grep -xF -- "$chord" >/dev/null && problem "unbound chord $chord is still bound"
      done < <(jq -r "$canon"' .unbind[] | [canon, ""] | @tsv' "$keys")

      dups=$(printf '%s\n' "$binds" | cut -f1 | sort | uniq -d)
      [ -z "$dups" ] || while read -r c; do problem "$c is bound more than once"; done <<< "$dups"

      if [ -n "$docs" ]; then
        while IFS=$'\t' read -r chord desc; do
          grep -F -- "| \`$chord\` | $desc |" "$docs" >/dev/null || problem "$docs has no line with $chord and '$desc'"
        done < <(jq -r "$canon"' (.keys + .external)[] | [(.key | canon), .description] | @tsv' "$keys")
      fi

      [ "$fail" -eq 0 ] && echo "hypr-keys-check: ok"
      exit "$fail"
    '';
  };
in
{
  home-manager.users.olafkfreund.home.packages = [ hypr-keys-check ];
}
