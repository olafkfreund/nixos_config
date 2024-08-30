{
  config,
  lib,
  pkgs,
  ...
}: 
with lib; let 
  cfg = config.vpn.tailscale;
in {
  options.vpn.tailscale = {
    enable = mkEnableOption {
      default = true;
      description = "Enable Tailscale";
    };
  };
  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
    };

    environment.systemPackages = [
      pkgs.trayscale
      pkgs.ktailctl
      pkgs.tailscale
    ];
  };  
}
