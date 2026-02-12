# COSMIC Radio Applet - Internet radio player for COSMIC Desktop panel
# Local module to work around upstream mkPackageOption 'description' arg bug
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.cosmic-ext-applet-radio;
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

    autostart = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to automatically start the applet with COSMIC Desktop.
        When enabled, the applet will appear in the panel on login.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Add the package to system packages (includes mpv as runtime dependency)
    environment.systemPackages = [ cfg.package pkgs.mpv ];

    # Add autostart entry if enabled
    environment.etc = mkIf cfg.autostart {
      "xdg/autostart/com.marcos.RadioApplet.desktop".source =
        "${cfg.package}/share/applications/com.marcos.RadioApplet.desktop";
    };
  };
}
