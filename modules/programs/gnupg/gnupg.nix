{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.security.gnupg;
in {
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
  };
}
