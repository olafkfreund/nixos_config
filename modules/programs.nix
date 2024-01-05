
{ self, config, pkgs, ... }: {

programs.dconf.enable = true;
programs.firefox = {
    enable = true;
    preferences = {
      "widget.use-xdg-desktop-portal.file-picker" = 1;
    };
  };
programs.mtr.enable = true;
programs.gnupg.agent = {
  enable = true;
  enableSSHSupport = true;
  };
}
