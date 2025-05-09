{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.browsers.firefox;
in {
  options.browsers.firefox = {
    enable = mkEnableOption {
      default = true;
      description = "Enable Firefox support.";
    };
  };
  config = mkIf cfg.enable {
    programs = {
      firefox = {
        enable = true;
        package = pkgs.firefox;
      };
    };

    # Add Firefox profile names for Stylix theming
    stylix.targets.firefox = {
      enable = true;
      profileNames = ["default"]; # Add your actual profile name(s) here
    };
  };
}
