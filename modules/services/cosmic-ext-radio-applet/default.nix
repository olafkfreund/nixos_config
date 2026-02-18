# COSMIC Radio Applet - Internet radio player for COSMIC Desktop panel
# Local module to work around upstream mkPackageOption 'description' arg bug
# Note: This is a COSMIC panel applet (X-CosmicApplet=true). It must be added
# to the panel via COSMIC Settings > Panel > Applets, not via XDG autostart.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.cosmic-ext-applet-radio;

  # Wayland library path required for all libcosmic/COSMIC applets
  waylandLibs = lib.makeLibraryPath [
    pkgs.wayland
    pkgs.libxkbcommon
    pkgs.vulkan-loader
    pkgs.libglvnd
  ];

  # Wrap the applet binary with Wayland libraries (matches cosmic.nix wrapCosmicApp pattern)
  wrappedPackage = pkgs.symlinkJoin {
    name = "cosmic-ext-applet-radio-wrapped";
    paths = [ cfg.package ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/cosmic-ext-applet-radio \
        --prefix LD_LIBRARY_PATH : "${waylandLibs}"
    '';
  };
in
{
  options.programs.cosmic-ext-applet-radio = {
    enable = mkEnableOption "COSMIC Radio Applet - internet radio player for COSMIC Desktop panel";

    package = mkOption {
      type = types.package;
      default = pkgs.cosmic-ext-applet-radio;
      defaultText = literalExpression "pkgs.cosmic-ext-applet-radio";
      description = "The cosmic-ext-applet-radio package to use.";
    };
  };

  config = mkIf cfg.enable {
    # Install the wrapped applet with Wayland libraries and mpv runtime dependency
    environment.systemPackages = [ wrappedPackage pkgs.mpv ];
  };
}
