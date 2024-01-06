
{ self, config, pkgs, ... }: {

  programs.firefox = {
      enable = true;
      preferences = {
        "widget.use-xdg-desktop-portal.file-picker" = 1;
      };
    };
}
