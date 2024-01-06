
{ self, config, pkgs, ... }: {

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    };
}
