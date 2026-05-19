{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.wave;
in
{
  options.wave = {
    enable = mkEnableOption "Wave terminal emulator";
  };

  config = mkIf cfg.enable {
    # Wave Terminal — Electron + Go hybrid, in nixpkgs as pkgs.waveterm.
    # We use the home-manager module so future declarative `programs.waveterm.settings`
    # / `programs.waveterm.themes` wiring is a one-line addition. The AppImage
    # upstream ships does NOT render on NixOS, so nixpkgs is the only viable path.
    programs.waveterm.enable = true;
  };
}
