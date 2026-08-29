{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.cli.yazi;
in
{
  options.cli.yazi = {
    enable = mkEnableOption {
      default = true;
      description = "yazi";
    };
  };
  config = mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
      package = pkgs.yazi;
      enableBashIntegration = true;
      enableZshIntegration = true;
      settings = {
        log = {
          enabled = false;
        };
        manager = {
          show_hidden = true;
          sort_by = "modified";
          sort_dir_first = true;
          sort_reverse = true;
        };
        # No filetype colour rules here. Stylix's yazi target writes the whole
        # palette into theme.toml from the active base16 scheme; per-mime `fg`
        # belongs in theme.toml, not yazi.toml, so hardcoding it here only ever
        # risked pinning stale colours next to the themed ones.
        filetype = {
          previewers = [
            # Code
            {
              mime = "text/*";
              exec = "nvim";
            }
            {
              mime = "*/xml";
              exec = "nvim";
            }
            {
              mime = "*/yaml";
              exec = "nvim";
            }
            {
              mime = "*/javascript";
              exec = "nvim";
            }
            {
              mime = "*/x-wine-extension-ini";
              exec = "nvim";
            }
            {
              mime = "*/tf";
              exec = "nvim";
            }
            # JSON
            {
              mime = "application/json";
              exec = "nvim";
            }
            # Image
            # { mime = "image/vnd.djvu"; exec = "noop"; }
            {
              mime = "image/*";
              exec = "feh";
            }
            # Video
            {
              mime = "video/*";
              exec = "vlc";
            }
            # PDF
            {
              mime = "application/pdf";
              exec = "pdf";
            }
            # Archive
            {
              mime = "application/zip";
              exec = "archive";
            }
            {
              mime = "application/gzip";
              exec = "archive";
            }
            {
              mime = "application/x-tar";
              exec = "archive";
            }
            {
              mime = "application/x-bzip";
              exec = "archive";
            }
            {
              mime = "application/x-bzip2";
              exec = "archive";
            }
            {
              mime = "application/x-7z-compressed";
              exec = "archive";
            }
            {
              mime = "application/x-rar";
              exec = "archive";
            }
            {
              mime = "application/xz";
              exec = "archive";
            }
            # Fallback
            {
              name = "*";
              exec = "file";
            }
          ];
        };
      };
    };
    home.packages = with pkgs; [
      imagemagick
      fontpreview
      unar
      poppler
    ];
  };
}
