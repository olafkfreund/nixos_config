# Consolidated Desktop Module
# Replaces 25+ desktop-related modules with intelligent feature detection
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.consolidated.desktop;

  # Hardware detection helpers
  hasAMDGpu =
    any (pkg: hasInfix "amd" (toLower (toString pkg)))
      (config.hardware.graphics.extraPackages or [ ]);
  hasNvidiaGpu = config.hardware.nvidia.package or null != null;
  isLaptop = config.hardware.laptop or false;

  # Smart package selection based on hardware
  desktopPackages = with pkgs;
    [
      # Essential desktop apps
      firefox
      chromium

      # Productivity
      # libreoffice-bin

      # Media (conditional on hardware)
    ]
    ++ optionals hasAMDGpu [
      # AMD-optimized media tools
      mpv-unwrapped.override
      { vaapiSupport = true; }
    ]
    ++ optionals hasNvidiaGpu [
      # NVIDIA-optimized tools
      obs-studio.override
      { cudaSupport = true; }
    ]
    ++ optionals isLaptop [
      # Laptop-specific tools
      brightnessctl
      acpi
      powertop
    ];
in
{
  options.consolidated.desktop = {
    enable = mkEnableOption "consolidated desktop environment";

    environment = mkOption {
      type = types.enum [ "gnome" "cosmic" "minimal" ];
      default = "gnome";
      description = "Desktop environment to enable";
    };

    features = {
      gaming = mkEnableOption "gaming packages and optimizations";
      development = mkEnableOption "development tools";
      media = mkEnableOption "media creation tools";
      productivity = mkEnableOption "productivity suite";
    };

    hardware = {
      autoDetect = mkEnableOption "automatic hardware optimization" // { default = true; };
    };
  };

  config = mkIf cfg.enable {
    # Desktop environment configuration
    services = {
      # Display manager
      greetd = mkIf (cfg.environment != "minimal") {
        enable = true;
        settings.default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd ${
            if cfg.environment == "gnome"
            then "gnome-session"
            else if cfg.environment == "cosmic"
            then "cosmic-session"
            else "gnome-session" # fallback
          }";
        };
      };

      # Desktop environment specific
      xserver.enable = cfg.environment == "gnome";
    };

    # GNOME configuration
    services.xserver.desktopManager.gnome.enable = cfg.environment == "gnome";

    # Cosmic DE configuration
    services.desktopManager.cosmic.enable = cfg.environment == "cosmic";

    # Hardware-optimized graphics
    hardware.graphics = mkIf cfg.hardware.autoDetect {
      enable = true;
      enable32Bit = true;

      # Hardware-specific optimization packages
      extraPackages = with pkgs; (
        # AMD optimization
        optionals hasAMDGpu [
          amdvlk
          rocmPackages.rocm-runtime
        ]
        ++
        # NVIDIA optimization
        optionals hasNvidiaGpu [
          nvidia-vaapi-driver
        ]
      );
    };

    # Audio (consolidated from 3 modules)
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = cfg.features.media;
    };

    # Fonts (consolidated from 2 modules)
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
        inter
        source-code-pro
      ];
      fontconfig = {
        defaultFonts = {
          serif = [ "Inter" ];
          sansSerif = [ "Inter" ];
          monospace = [ "FiraCode Nerd Font" ];
        };
      };
    };

    # Desktop packages (smart selection)
    environment.systemPackages =
      desktopPackages
      ++ optionals cfg.features.gaming (with pkgs; [ steam ]) # lutris removed: slow pyrate-limiter dependency
      ++ optionals cfg.features.development (with pkgs; [ vscode git-crypt ])
      ++ optionals cfg.features.media (with pkgs; [ gimp blender kdenlive ]);

    # Performance optimizations for desktop
    services.thermald.enable = mkDefault isLaptop;
    powerManagement.cpuFreqGovernor = mkDefault (
      if isLaptop
      then "powersave"
      else "performance"
    );

    # Laptop-specific optimizations
    services.tlp = mkIf isLaptop {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    };
  };
}
