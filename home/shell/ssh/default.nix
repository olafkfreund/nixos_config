{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.cli.programs.ssh;
in
{
  options.cli.programs.ssh = with types; {
    enable = mkEnableOption "ssh";
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      package = pkgs.openssh;
    };
    programs.keychain = {
      enable = true;
      keys = [ "id_ed25519" ];
      agents = [ "ssh" "gpg" ];
    };
  };
}
