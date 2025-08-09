# Internationalization configuration for workstation template
{ lib
, pkgs
, ...
}:
let
  vars = import ../variables.nix;
in
{
  # Locale configuration
  i18n.defaultLocale = vars.locale;

  # Additional locale settings
  i18n.extraLocaleSettings = {
    LC_ADDRESS = vars.locale;
    LC_IDENTIFICATION = vars.locale;
    LC_MEASUREMENT = vars.locale;
    LC_MONETARY = vars.locale;
    LC_NAME = vars.locale;
    LC_NUMERIC = vars.locale;
    LC_PAPER = vars.locale;
    LC_TELEPHONE = vars.locale;
    LC_TIME = vars.locale;
  };

  # Time zone
  time.timeZone = vars.timezone;

  # Console configuration
  console = {
    keyMap = vars.keyboardLayouts.console;
    font = "Lat2-Terminus16";
    useXkbConfig = true; # Use xkb.layout for console keymap
  };

  # X11 keyboard configuration
  services.xserver.xkb = {
    layout = vars.keyboardLayouts.xserver;
    variant = "";
    model = "pc105";
    options = "grp:alt_shift_toggle,caps:escape"; # Alt+Shift to switch layouts, Caps as Escape
  };

  # Input method configuration (for non-Latin scripts)
  # Uncomment if you need input methods for Chinese, Japanese, Korean, etc.
  # i18n.inputMethod = {
  #   enabled = "fcitx5";
  #   fcitx5.addons = with pkgs; [
  #     fcitx5-gtk
  #     fcitx5-chinese-addons
  #     fcitx5-mozc  # For Japanese
  #   ];
  # };

  # Font configuration
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # Basic fonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji

      # Monospace fonts for development
      jetbrains-mono
      fira-code
      fira-code-nerdfont
      jetbrains-mono-nerdfont
      source-code-pro

      # Sans-serif fonts
      inter
      roboto
      open-sans
      ubuntu_font_family

      # Serif fonts
      merriweather
      crimson-pro

      # Icon fonts
      font-awesome
      material-design-icons

      # Additional programming fonts
      cascadia-code
      victor-mono
      hack-font
      inconsolata
      inconsolata-nerdfont

      # System fonts
      liberation_ttf
      dejavu_fonts

      # Microsoft fonts (if needed)
      # corefonts
      # vistafonts-chs
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ vars.theme.font.serif "Noto Serif" ];
        sansSerif = [ vars.theme.font.sans "Noto Sans" ];
        monospace = [ vars.theme.font.mono "JetBrainsMono Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };

      # Font rendering improvements
      subpixel.rgba = "rgb";
      hinting = {
        enable = true;
        style = "slight";
      };
      antialias = true;
    };
  };

  # Locale packages
  environment.systemPackages = with pkgs; [
    # Locale utilities
    glibc
    glibcLocales

    # Unicode support
    unicode-character-database
    unicode-emoji

    # Text processing
    hunspell
    hunspellDicts.en_US
    # Add more dictionaries as needed:
    # hunspellDicts.en_GB
    # hunspellDicts.de_DE
    # hunspellDicts.fr_FR

    # Font utilities
    fontconfig
    fontforge

    # Character maps and font viewers
    gucharmap
    font-manager
  ];

  # Regional settings
  # Uncomment and customize based on your region

  # # European settings
  # i18n.extraLocaleSettings = {
  #   LC_MEASUREMENT = "de_DE.UTF-8";  # Metric system
  #   LC_MONETARY = "de_DE.UTF-8";     # Euro currency
  #   LC_PAPER = "de_DE.UTF-8";        # A4 paper
  # };

  # # US settings
  # i18n.extraLocaleSettings = {
  #   LC_MEASUREMENT = "en_US.UTF-8";  # Imperial system
  #   LC_MONETARY = "en_US.UTF-8";     # Dollar currency
  #   LC_PAPER = "en_US.UTF-8";        # Letter paper
  # };

  # Date and time format preferences
  environment.variables = {
    # ISO 8601 date format
    LC_TIME = vars.locale;

    # Additional locale environment variables
    LANG = vars.locale;
    LANGUAGE = builtins.head (lib.strings.splitString "." vars.locale);
  };

  # Timezone synchronization
  services.ntp.enable = true;
  services.timesyncd.enable = false; # Disable systemd-timesyncd when using ntp

  # Hardware clock configuration
  time.hardwareClockInLocalTime = false; # Use UTC for hardware clock (recommended for dual-boot)
}
