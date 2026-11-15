{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.virtualization;
in
{
  config = mkIf (cfg.enable && cfg.spice) {
    virtualisation = {
      spiceUSBRedirection.enable = true;
    };
    # Guest agent only — pointless and log-spammy on a physical host, so
    # it tracks guestAgent (default off) rather than cfg.enable.
    services.spice-vdagentd.enable = cfg.spiceGuestAgent;
    environment.systemPackages = with pkgs; [
      spice
      spice-gtk
      spice-protocol
      spice-vdagent
      swtpm
    ];
  };
}
