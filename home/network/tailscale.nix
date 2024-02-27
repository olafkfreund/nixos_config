{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.hosts.tailscale;
in {
  options.hosts.tailscale = {
    enable = mkEnableOption "Enable Tailscale agent";
  };

  config = mkIf cfg.enable {
    # Setup tailscale default on all machines
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
    networking.firewall = {
      # Required for tailscale
      checkReversePath = "loose";
      trustedInterfaces = ["tailscale0"];
    };
    # create a systemd oneshot job to authenticate to Tailscale on startup
    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = ["network-pre.target" "tailscale.service"];
      wants = ["network-pre.target" "tailscale.service"];
      wantedBy = ["multi-user.target"];

      # set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      # have the job run this shell script
      script = ''
        # wait for tailscaled to settle
        echo "Waiting for tailscale.service start completion ..."
        sleep 5
      '';
    };
  };
}