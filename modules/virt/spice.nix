{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.services.spice;
in
{
  options.services.spice = {
    enable = mkEnableOption {
      default = false;
      description = "Enable the SPICE protocol server.";
    };
  };
  config = mkIf cfg.enable {
    virtualisation = {
      spiceUSBRedirection.enable = true;
    };
    services.spice-vdagentd.enable = true;
    environment.systemPackages = with pkgs; [
      spice
      spice-gtk
      spice-protocol
      spice-vdagent
      swtpm
    ];
  };
}
