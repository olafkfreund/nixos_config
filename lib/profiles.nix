{lib}: let
  inherit (lib) mkMerge;
in {
  # Base profile - minimal system essentials
  base = {
    description = "Minimal base system configuration";
    modules = [
      ../modules/core
      ../modules/nix
      ../modules/security/basic
    ];
  };

  # Desktop profile - GUI applications and desktop environment
  desktop = {
    description = "Desktop environment and GUI applications";
    modules = [
      ../modules/desktop
      ../modules/programs/gui
      ../modules/fonts
    ];

    config = {
      custom.desktop.enable = true;
      custom.applications.gui.enable = true;
    };
  };

  # Development profile - programming tools and environments
  development = {
    description = "Development tools and programming environments";
    modules = [
      ../modules/development
      ../modules/programs/development
    ];

    config = {
      custom.development = {
        enable = true;
        languages = ["nix" "rust" "python" "javascript"];
        editors = ["nixvim" "vscode"];
        tools = ["git" "docker"];
      };
    };
  };

  # Server profile - server-specific optimizations
  server = {
    description = "Server configuration with optimizations";
    modules = [
      ../modules/services
      ../modules/security/hardened
      ../modules/networking/server
    ];

    config = {
      custom.server = {
        enable = true;
        ssh.enable = true;
        firewall.strict = true;
      };
    };
  };

  # Gaming profile - gaming optimizations and tools
  gaming = {
    description = "Gaming optimizations and platforms";
    modules = [
      ../modules/gaming
      ../modules/hardware/gaming
    ];

    config = {
      custom.gaming = {
        enable = true;
        steam.enable = true;
        performance.enable = true;
      };
    };
  };

  # Media profile - multimedia applications and codecs
  media = {
    description = "Multimedia applications and codec support";
    modules = [
      ../modules/media
      ../modules/hardware/media
    ];

    config = {
      custom.media = {
        enable = true;
        codecs.enable = true;
        streaming.enable = true;
      };
    };
  };

  # AI/ML profile - AI and machine learning tools
  ai = {
    description = "AI and machine learning development environment";
    modules = [
      ../modules/ai
      ../modules/development/ml
    ];

    config = {
      custom.ai = {
        enable = true;
        cuda.enable = true; # Can be overridden per host
        frameworks = ["pytorch" "tensorflow"];
      };
    };
  };
}
