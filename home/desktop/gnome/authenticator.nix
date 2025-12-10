{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.desktop.gnome;
in
{
  config = mkIf (cfg.enable && cfg.apps.enable) {
    # GNOME Authenticator - TOTP/2FA application
    home.packages = with pkgs; [
      authenticator # Two-factor authentication code generator for GNOME
    ];

    # Authenticator application dconf settings
    dconf.settings = {
      "com/belmoussaoui/Authenticator" = {
        # Window preferences
        window-width = 800;
        window-height = 600;
        is-maximized = false;

        # Backup reminder (show reminder after 10 successful logins)
        backup-reminder-count = 10;

        # Dark mode preference (will follow system theme)
        prefer-dark-theme = cfg.theme.variant == "dark";
      };
    };

    # XDG desktop file association for Authenticator
    # Makes Authenticator handle otpauth:// URIs (QR code scanning)
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/otpauth" = "com.belmoussaoui.Authenticator.desktop";
      };
    };
  };
}
