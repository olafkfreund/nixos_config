{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.desktop.displayManager;
in
{
  options.desktop.displayManager = {
    backend = mkOption {
      type = types.enum [ "gdm" "cosmic-greeter" "none" ];
      default = "none";
      description = ''
        Which display manager runs at boot.

        - gdm: GDM (used by the headless RDP host for auto-login GNOME)
        - cosmic-greeter: COSMIC's own greeter (used by hosts with COSMIC)
        - none: no DM enabled (e.g. host uses start* command directly)

        This option exists to keep the wiring in one place and prevent
        lightdm from sneaking back in (nixpkgs enables it by default
        when xserver is enabled).
      '';
    };

    autoLogin = {
      enable = mkEnableOption "auto-login at boot (recommended only for headless RDP hosts)";
      user = mkOption {
        type = types.str;
        default = "";
        description = "User to auto-login as. Required when autoLogin.enable = true.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = !cfg.autoLogin.enable || cfg.autoLogin.user != "";
        message = "desktop.displayManager.autoLogin.user must be set when autoLogin.enable = true";
      }
    ];

    services = {
      # Always disable lightdm — nixpkgs enables it as the X11 default;
      # we don't use it on any host.
      xserver.displayManager.lightdm.enable = lib.mkForce false;

      displayManager = {
        gdm.enable = cfg.backend == "gdm";
        cosmic-greeter.enable = cfg.backend == "cosmic-greeter";

        autoLogin = mkIf cfg.autoLogin.enable {
          # mkOverride 0 to win over the cosmic-remote-desktop /
          # gnome-remote-desktop modules' lib.mkForce false (priority 50).
          enable = lib.mkOverride 0 true;
          user = cfg.autoLogin.user;
        };
      };
    };
  };
}
