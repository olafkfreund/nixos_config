# Govee lights in the Omarchy shell: bar widget and a keyboard menu
# (SUPER+CTRL+ALT+G, bound in hosts/p620/nixos/nixarchy.nix). Installed from
# the omagovee input instead of a hand copy (#3144). The API key stays in
# ~/.config/omagovee and is never in the store.
{ inputs, ... }:
{
  home-manager.users.olafkfreund = {
    programs.nixarchy.plugins."olafkfreund.govee".src = "${inputs.omagovee}/plugin";
  };
}
