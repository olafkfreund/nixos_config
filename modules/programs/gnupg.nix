{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.security;
in
{
  config = mkIf (cfg.enable && cfg.gnupg) {
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
