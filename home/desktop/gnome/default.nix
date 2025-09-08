{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.gnome;
in {
  options.desktop.gnome = {
    enable = mkEnableOption "GNOME desktop environment";

    extensions = {
      enable = mkEnableOption "GNOME Shell extensions";

      packages = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "List of GNOME Shell extension packages to install";
        example = literalExpression ''
          with pkgs.gnomeExtensions; [
            dash-to-dock
            appindicator
            vitals
          ]
        '';
      };
    };

    apps = {
      enable = mkEnableOption "Additional GNOME applications";

      packages = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "List of additional GNOME application packages to install";
        example = literalExpression ''
          with pkgs; [
            gnome-tweaks
            dconf-editor
            gnome-extension-manager
          ]
        '';
      };
    };

    theme = {
      enable = mkEnableOption "GNOME theming with Gruvbox";

      variant = mkOption {
        type = types.enum ["dark" "light"];
        default = "dark";
        description = "Theme variant to use";
      };
    };

    keybindings = {
      enable = mkEnableOption "Custom GNOME keybindings";
    };
  };

  imports = [
    ./theme.nix
    ./extensions.nix
    ./apps.nix
    ./keybindings.nix
  ];

  config = mkIf cfg.enable {
    # Enable GNOME desktop services
    services.gnome-keyring.enable = true;

    # Essential GNOME packages
    home.packages = with pkgs; [
      # Core GNOME utilities
      gnome-tweaks
      dconf-editor
      gnome-extension-manager
      gruvbox-gtk-theme

      # Additional utilities
      gnome-screenshot
      gnome-system-monitor
      gnome-calculator
      gnome-calendar
      gnome-weather

      # File management
      nautilus
      file-roller

      # Media
      eog # Eye of GNOME (image viewer)
      totem # GNOME Videos

      # Text editing
      gedit
    ];

    # GNOME settings via dconf
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        clock-format = "24h";
        show-battery-percentage = true;
        gtk-theme = mkDefault (
          if cfg.theme.enable
          then "Adwaita-dark"
          else "Adwaita"
        );
        icon-theme = mkDefault "Adwaita";
        cursor-theme = mkDefault "Adwaita";
      };

      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
        focus-mode = "click";
      };

      "org/gnome/shell" = {
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "firefox.desktop"
          "org.gnome.Terminal.desktop"
          "code.desktop"
          "org.gnome.Settings.desktop"
        ];
      };

      # Privacy settings
      "org/gnome/desktop/privacy" = {
        report-technical-problems = false;
        send-software-usage-stats = false;
      };

      # Power settings
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "suspend";
        sleep-inactive-battery-timeout = 1200; # 20 minutes
      };

      # Window management
      "org/gnome/desktop/wm/keybindings" = {
        close = ["<Super>q"];
        toggle-maximized = ["<Super>m"];
        toggle-fullscreen = ["F11"];
      };

      # Application switcher
      "org/gnome/shell/keybindings" = {
        switch-to-application-1 = ["<Super>1"];
        switch-to-application-2 = ["<Super>2"];
        switch-to-application-3 = ["<Super>3"];
        switch-to-application-4 = ["<Super>4"];
        switch-to-application-5 = ["<Super>5"];
      };
    };

    # XDG mime applications (XDG directories handled by base-home.nix)
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
        "application/pdf" = "org.gnome.Evince.desktop";
        "image/jpeg" = "org.gnome.eog.desktop";
        "image/png" = "org.gnome.eog.desktop";
      };
    };
  };
}
