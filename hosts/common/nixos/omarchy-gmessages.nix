# Messages: Google Messages (RCS/SMS) as the Omarchy shell plugin
# olafkfreund.gmessages. A user service (gmessages-tui serve) owns the session and
# the SQLCipher store, its key in the keyring; the plugin talks to it over a
# private socket in $XDG_RUNTIME_DIR. Pair once per host from the plugin window.
# State: ~/.local/share/gmessages-tui. Logs: journalctl --user -u gmessages-tui.
{ inputs, pkgs, ... }:
let
  gmessages = inputs.gmessages.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ./omarchy-enable-once.nix ];

  # Every SUPER chord on M is taken here; S for SMS.
  local.omarchy.keys.extra = [
    { key = "SUPER + CTRL + ALT + S"; description = "Messages"; action = "omarchy-shell olafkfreund.gmessages toggle"; }
  ];

  home-manager.users.olafkfreund = {
    imports = [ inputs.gmessages.homeManagerModules.default ];
    services.gmessages = {
      enable = true;
      package = gmessages.gmessages-tui;
    };
    programs.nixarchy.plugins."olafkfreund.gmessages".src = "${gmessages.plugin}";
    local.omarchy.enableOnce = [ "olafkfreund.gmessages" ];
  };
}
