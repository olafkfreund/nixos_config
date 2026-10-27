# Altscape: Alt+Tab window switcher (Omarchy shell). No manual step needed:
# the plugin is installed, enabled once per host by a post-boot hook, and
# Alt+Tab is bound from a Nix-owned ~/.config/hypr/altscape-binds.lua whose
# require line is appended once to the user-owned bindings.lua at activation.
# To change the shortcut, edit the binds below (#2503).
{ config, pkgs, ... }:
let
  id = "io.github.qempexe.altscape";
  summon = "omarchy-shell shell summon ${id}";
  hyprland = config.programs.hyprland.package;
in
{
  imports = [ ./omarchy-enable-once.nix ];

  # A function so lib is Home Manager's (lib.hm.dag), not nixpkgs'.
  home-manager.users.olafkfreund = { lib, ... }: {
    programs.nixarchy.plugins.${id}.src =
      pkgs.customPkgs.altscape.override { inherit hyprland; };

    home.file.".config/hypr/altscape-binds.lua".text = ''
      hl.unbind("ALT + TAB")
      hl.unbind("ALT + SHIFT + TAB")
      o.bind("ALT + TAB", "Altscape: next window", "${summon} next")
      o.bind("ALT + SHIFT + TAB", "Altscape: previous window", "${summon} prev")
      o.bind("ALT + Alt_L", "Altscape: switch on release", "${summon} release", { release = true })
      o.bind("ALT + Alt_R", "Altscape: switch on release", "${summon} release", { release = true })
      o.bind("SUPER + ALT + SHIFT + S", "Altscape settings", "omarchy-shell ${id} settings")
    '';

    # Append-only so the user's edits to bindings.lua stay theirs.
    home.activation.altscapeRequire = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/.config/hypr/bindings.lua"
      if [ -f "$f" ] && ! grep -qF '"hypr.altscape-binds"' "$f"; then
        # The redirect lives inside run, so a dry run cannot append to the file.
        run ${pkgs.bash}/bin/bash -c 'printf "\n%s\n" "$2" >> "$1"' _ "$f" \
          'pcall(require, "hypr.altscape-binds") -- managed by NixOS (#2503)'
      fi
    '';

    local.omarchy.enableOnce = [ id ];
  };
}
