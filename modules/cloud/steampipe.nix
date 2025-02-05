{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.steampipe.packages;
in {
  options.steampipe.packages = {
    enable = mkEnableOption "Enable cloud steampipe tools";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      steampipe
      steampipePackages.steampipe-plugin-aws
      steampipePackages.steampipe-plugin-azure
      steampipePackages.steampipe-plugin-github
    ];
  };
}
