{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.media.graphics = {
    enable = lib.mkEnableOption "graphics and image editing support";

    viewers = {
      enable = lib.mkEnableOption "image viewers";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          feh
          gwenview
          nomacs
          gthumb
        ];
        description = "Image viewer packages to install";
      };
    };

    editors = {
      enable = lib.mkEnableOption "image editors";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          gimp
          inkscape
          krita
          blender
        ];
        description = "Image editing packages to install";
      };
    };

    screenshots = {
      enable = lib.mkEnableOption "screenshot tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          flameshot
          spectacle
          grim
          slurp
        ];
        description = "Screenshot tool packages to install";
      };
    };

    vector = {
      enable = lib.mkEnableOption "vector graphics tools";
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          inkscape
          dia
          drawio
        ];
        description = "Vector graphics packages to install";
      };
    };
  };

  config = lib.mkIf config.modules.media.graphics.enable {
    environment.systemPackages = lib.flatten [
      (lib.optionals config.modules.media.graphics.viewers.enable
        config.modules.media.graphics.viewers.packages)
      (lib.optionals config.modules.media.graphics.editors.enable
        config.modules.media.graphics.editors.packages)
      (lib.optionals config.modules.media.graphics.screenshots.enable
        config.modules.media.graphics.screenshots.packages)
      (lib.optionals config.modules.media.graphics.vector.enable
        config.modules.media.graphics.vector.packages)
    ];

    # Hardware acceleration for graphics applications
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Font support for graphics applications
    fonts.packages = with pkgs; [
      liberation_ttf
      dejavu_fonts
      google-fonts
    ];
  };
}
