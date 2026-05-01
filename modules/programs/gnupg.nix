{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.security.gnupg;
in
{
  options.security.gnupg = {
    enable = mkEnableOption {
      default = false;
      description = "Enable GnuPG";
    };
  };
  config = mkIf cfg.enable {
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    environment.systemPackages = [
      pkgs.gpg-tui
      pkgs.gpgme
      pkgs.gnupg
    ];
  };
}
