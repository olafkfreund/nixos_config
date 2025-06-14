{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.applications.browsers = {
    enable = lib.mkEnableOption "web browsers";

    primary = lib.mkOption {
      type = lib.types.enum ["firefox" "chromium" "brave" "edge"];
      default = "firefox";
      description = "Primary web browser";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        firefox
        chromium
      ];
      description = "Browser packages to install";
    };

    extensions = {
      enable = lib.mkEnableOption "browser extensions and policies";
    };
  };

  config = lib.mkIf config.modules.applications.browsers.enable {
    environment.systemPackages = config.modules.applications.browsers.packages;

    # Set default browser
    xdg.mime.defaultApplications = {
      "text/html" = "${config.modules.applications.browsers.primary}.desktop";
      "x-scheme-handler/http" = "${config.modules.applications.browsers.primary}.desktop";
      "x-scheme-handler/https" = "${config.modules.applications.browsers.primary}.desktop";
      "x-scheme-handler/about" = "${config.modules.applications.browsers.primary}.desktop";
      "x-scheme-handler/unknown" = "${config.modules.applications.browsers.primary}.desktop";
    };

    # Firefox configuration
    programs.firefox =
      lib.mkIf
      (lib.any (pkg: pkg.pname or pkg.name == "firefox")
        config.modules.applications.browsers.packages) {
        enable = true;
        policies = lib.mkIf config.modules.applications.browsers.extensions.enable {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
          DisablePocket = true;
          DisableFirefoxAccounts = false;
          DisableAccounts = false;
          DisableFirefoxScreenshots = true;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          DontCheckDefaultBrowser = true;
        };
      };

    # Chromium configuration
    programs.chromium =
      lib.mkIf
      (lib.any (pkg: pkg.pname or pkg.name == "chromium")
        config.modules.applications.browsers.packages) {
        enable = true;
        extensions = lib.mkIf config.modules.applications.browsers.extensions.enable [
          "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
          "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
        ];
      };
  };
}
