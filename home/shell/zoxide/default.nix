{ config
, lib
, ...
}:
with lib; let
  cfg = config.cli.zoxide;
in
{
  options.cli.zoxide = {
    enable = mkEnableOption {
      default = true;
      description = "Enable zoxide";
    };
  };
  config = mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };
  };
}
