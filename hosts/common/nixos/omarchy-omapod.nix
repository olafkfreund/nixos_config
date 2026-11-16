# omaPOD: podcast app, podcast/OPML link handlers and an Omarchy bar widget
# (#2977). No manual step needed: the widget plugin is installed and enabled
# once per host by a post-boot hook (turning it off later in Setup > Plugins
# sticks); the widget and the keys appear after the next login.
# Keys, bound by omaPOD's module defaults (nixarchy Lua backend), all on
# Super+Ctrl+Shift: K toggle, "," rewind, "." forward, N skip, O show.
# Feeds refresh hourly; auto-downloads skip battery by omaPOD's default.
{ inputs, pkgs, ... }:
let
  id = "io.github.arikisonfire.pod";
  omapod = inputs.omapod.packages.${pkgs.stdenv.hostPlatform.system}.omapod;
in
{
  imports = [
    inputs.omapod.nixosModules.default
    ./omarchy-enable-once.nix
  ];

  programs.omapod.enable = true; # package, desktop entry, podcast/OPML handlers

  # Bound by omaPOD's omapod-binds.lua; declared so the duplicate-chord assertion
  # (omarchy-keys.nix) and hypr-keys-check see them. Descriptions match upstream's.
  local.omarchy.keys.external =
    map
      (k: {
        key = "SUPER + CTRL + SHIFT + ${k.key}";
        description = "omaPOD: ${k.action}";
      })
      [
        { key = "K"; action = "toggle"; }
        { key = "COMMA"; action = "rewind"; }
        { key = "PERIOD"; action = "forward"; }
        { key = "N"; action = "skip"; }
        { key = "O"; action = "show"; }
      ];

  # A function so lib is Home Manager's (lib.hm.dag), not nixpkgs'.
  home-manager.users.olafkfreund = { lib, ... }: {
    imports = [ inputs.omapod.homeManagerModules.default ];
    programs.omapod = {
      enable = true;
      refreshTimer.enable = true;
      # widget.enable stays false: the plugin comes from programs.nixarchy.plugins.
    };

    # User units cannot take DynamicUser/ProtectHome/ProtectSystem (docs/applications/omapod.md).
    systemd.user.services.omapod-refresh.Service.NoNewPrivileges = true;
    systemd.user.services.omapod-settings.Service.NoNewPrivileges = true;

    programs.nixarchy.plugins.${id}.src = "${omapod}/share/omapod/widget";
    local.omarchy.enableOnce = [ id ];

    # Append-only so the user's edits to bindings.lua stay theirs (as Altscape, #2503).
    home.activation.omapodRequire = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/.config/hypr/bindings.lua"
      if [ -f "$f" ] && ! grep -qF '"hypr.omapod-binds"' "$f"; then
        # The redirect lives inside run, so a dry run cannot append to the file.
        run ${pkgs.bash}/bin/bash -c 'printf "\n%s\n" "$2" >> "$1"' _ "$f" \
          'pcall(require, "hypr.omapod-binds") -- managed by NixOS (#2977)'
      fi
    '';
  };
}
