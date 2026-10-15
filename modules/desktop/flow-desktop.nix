# Flow Desktop YouTube client (Issue #2317), from the nixos-FlowTube flake.
{ config, lib, inputs, ... }:
let
  cfg = config.features.flow-desktop;
in
{
  options.features.flow-desktop.enable =
    lib.mkEnableOption "Flow Desktop, a privacy-respecting YouTube client";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      inputs.flowtube.homeManagerModules.default
      { programs.flow-desktop.enable = true; }
    ];
  };
}
