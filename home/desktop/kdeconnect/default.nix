{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: 
with lib; let
  cfg = config.programs.kdeconnect;
  kdeconnect-cli = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-cli";
  fortune = "${pkgs.fortune}/bin/fortune";
  script-fortune = pkgs.writeShellScriptBin "fortune" ''
    ${kdeconnect-cli} -d $(${kdeconnect-cli} --list-available --id-only) --ping-msg "$(${fortune})"
  '';
in {
  options.programs.kdeconnect = {
    enable = mkEnableOption {
      default = false;
      description = "KDE Connect";
    };
  };
  config = mkIf cfg.enable {
    xdg.desktopEntries = {
      "org.kde.kdeconnect.sms" = {
        exec = "";
        name = "KDE Connect SMS";
        settings.NoDisplay = "true";
      };
      "org.kde.kdeconnect.nonplasma" = {
        exec = "";
        name = "KDE Connect Indicator";
        settings.NoDisplay = "true";
      };
      "org.kde.kdeconnect.app" = {
        exec = "";
        name = "KDE Connect";
        settings.NoDisplay = "true";
      };
    };

    services.kdeconnect = {
      enable = true;
      indicator = true;
    };

    xdg.configFile = {
      "kdeconnect-scripts/fortune.sh".source = "${script-fortune}/bin/fortune";
    };
  };
}
