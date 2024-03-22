{ pkgs, home-manager, config, lib, ... }: {

  programs.yazi = {
    enable = true;
    package = pkgs.yazi;
    enableBashIntegration = true;
    settings = {
      log = {
      enabled = false;
      };
      manager = {
        show_hidden = false;
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
      };
    };
  };
}