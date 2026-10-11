# tfm terminal file manager (Issue #2243), from the nixos-tfm flake.
{ config, lib, inputs, ... }:
let
  cfg = config.features.tfm;
in
{
  options.features.tfm = {
    enable = lib.mkEnableOption "tfm, the mouse-first terminal file manager";
    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Seed for ~/.config/tfm/config.toml, written only when the file is missing.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      inputs.nixos-tfm.homeManagerModules.default
      { programs.tfm = { enable = true; inherit (cfg) settings; }; }
    ];
  };
}
