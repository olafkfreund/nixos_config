{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.slack;
in {
  options.programs.slack = {
    enable = mkEnableOption "Slack";
  };

  config = mkIf cfg.enable {
    # Ensure PipeWire and portal dependencies are available
    home.packages = [
      pkgs.slack
    ];

    # Add environment variables to user session for Slack
    home.sessionVariables = {
      # Improve Electron/Slack stability
      NIXOS_OZONE_WL = "1";
      ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
      ELECTRON_ENABLE_LOGGING = "1";
    };
  };
}
