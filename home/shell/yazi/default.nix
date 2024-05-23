{ pkgs, pkgs-stable, home-manager, config, lib, ... }: {

  programs.yazi = {
    enable = true;
    package = pkgs-stable.yazi;
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
      filetype = {
        rules = [
          { fg = "#7AD9E5"; mime = "image/*"; }
          { fg = "#F3D398"; mime = "video/*"; }
          { fg = "#F3D398"; mime = "audio/*"; }
          { fg = "#CD9EFC"; mime = "application/x-bzip"; }
        ];
        previewers = [
          # Code
          { mime = "text/*";                 exec = "code"; }
          { mime = "*/xml";                  exec = "code"; }
          { mime = "*/javascript";           exec = "code"; }
          { mime = "*/x-wine-extension-ini"; exec = "code"; }
          # JSON
          { mime = "application/json"; exec = "json"; }
          # Image
          # { mime = "image/vnd.djvu"; exec = "noop"; }
          # { mime = "image/*";        exec = "image"; }
          # Video
          { mime = "video/*"; exec = "video"; }
          # PDF
          { mime = "application/pdf"; exec = "pdf"; }
          # Archive
          { mime = "application/zip";             exec = "archive"; }
          { mime = "application/gzip";            exec = "archive"; }
          { mime = "application/x-tar";           exec = "archive"; }
          { mime = "application/x-bzip";          exec = "archive"; }
          { mime = "application/x-bzip2";         exec = "archive"; }
          { mime = "application/x-7z-compressed"; exec = "archive"; }
          { mime = "application/x-rar";           exec = "archive"; }
          { mime = "application/xz";              exec = "archive"; }
          # Fallback
          { name = "*"; exec = "file"; }
        ];
      };
    };
  };
}
