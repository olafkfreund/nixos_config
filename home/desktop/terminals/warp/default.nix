{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.warp;
in
{
  options.warp = {
    enable = mkEnableOption "Warp terminal emulator";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.warp-terminal ];

    # Register Warp's .desktop as an associated terminal handler. We deliberately
    # do NOT override the default terminal cascade in
    # home/desktop/terminals/default.nix (which prefers kitty → foot → alacritty).
    xdg.mimeApps.associations.added = {
      "x-scheme-handler/terminal" = "dev.warp.Warp.desktop";
    };
  };
}
