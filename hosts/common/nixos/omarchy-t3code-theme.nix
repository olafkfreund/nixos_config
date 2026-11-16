# Publish the Omarchy palette to T3 Code and select it.
#
# Omarchy's T3 Code installer creates ~/.t3/userdata, publishes the palette
# there and selects it. NixOS never runs that installer, so T3 Code stays on
# its default theme. This Home Manager activation entry does those steps at
# every switch and boot (a skipped run is retried).
#
# Tracking: olafkfreund/nixos_config#2973
# Upstream: olafkfreund/nixarchy#1803. Delete this module (and its imports in
# hosts/*/nixos/nixarchy.nix) once nixarchy#1803 ships.
{ config, pkgs, lib, ... }:
let
  enabled = config.programs.nixarchy.apps.t3-code.enable;
  themeId = "omarchy";
  script = import ./t3code-theme-script.nix { inherit pkgs; } {
    inherit themeId;
    binPath = "${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.jq ]}:/etc/profiles/per-user/olafkfreund/bin:/run/current-system/sw/bin";
  };
in
{
  home-manager.users.olafkfreund = { lib, ... }: {
    home.activation.t3codeOmarchyTheme = lib.mkIf enabled
      (lib.hm.dag.entryAfter [ "writeBoundary" "nixarchySeed" ] ''
        run ${script}
      '');
  };
}
