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

    guestAgent = mkEnableOption ''
      the spice-vdagent guest daemon. Only meaningful when THIS machine is
      itself a SPICE/VM guest. On a physical host it has no SPICE session
      and logs "Error getting active session: No data available" on a
      tight loop, so it stays off even when SPICE (USB redirection / client
      tools for running VMs locally) is enabled'';
  };
  config = mkIf cfg.enable {
    virtualisation = {
      spiceUSBRedirection.enable = true;
    };
    # Guest agent only — pointless and log-spammy on a physical host, so
    # it tracks guestAgent (default off) rather than cfg.enable.
    services.spice-vdagentd.enable = cfg.guestAgent;
    environment.systemPackages = with pkgs; [
      spice
      spice-gtk
      spice-protocol
      spice-vdagent
      swtpm
    ];
  };
}
