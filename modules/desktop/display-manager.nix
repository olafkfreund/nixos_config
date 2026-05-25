{ config, lib, pkgs, ... }:
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

    # Workaround for nixpkgs#523332 — GDM 50's greeter session is a
    # gnome-shell kiosk that exec's `gnome-session`, but the
    # gdm-launch-environment PAM session does NOT inherit PATH /
    # XDG_DATA_DIRS from display-manager.service. So gdm-wayland-session
    # exits with exit 70 ("Unable to run session") and the greeter never
    # registers — "GdmDisplay: Session never registered, failing".
    # Hosts where the GNOME desktop module already pulls gnome-session
    # into environment.systemPackages can luck into a working PATH, but
    # any host that ever restarts display-manager after the GNOME 50
    # upgrade hits this. Drop this block once PR #523948 lands upstream
    # (we're pinned to nixpkgs 2025-08-01 which predates it).
    security.pam.services.gdm-launch-environment.rules.session.env-greeter-path = mkIf (cfg.backend == "gdm") {
      order = 10350; # after the existing env-greeter (10300), before systemd (10400)
      control = "required";
      modulePath = "${config.security.pam.package}/lib/security/pam_env.so";
      settings.conffile = pkgs.writeText "gdm-launch-environment-env-conf" ''
        PATH          DEFAULT="''${PATH}:${pkgs.gnome-session}/bin"
        XDG_DATA_DIRS DEFAULT="''${XDG_DATA_DIRS}:${config.services.displayManager.generic.environment.XDG_DATA_DIRS}"
      '';
      settings.readenv = 0;
    };
  };
}
