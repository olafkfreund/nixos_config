# Tailscale Serve on p620 — exposes the LiteLLM router at
# https://p620.<tailnet>.ts.net/router for remote Claude Code clients
# (mainly razer when roaming outside the office LAN).
#
# Matches the path-based pattern already established on p510
# (hosts/p510/nixos/tailscale-serve.nix): every service goes under
# HTTPS :443 with a unique path, avoiding port conflicts.
#
# Currently only exposes /router. Add new paths here if other p620
# services need tailnet HTTPS exposure later.
{ config, pkgs, lib, ... }:
let
  routerCfg = config.features.litellm-router;
in
{
  systemd.services.tailscale-serve = lib.mkIf routerCfg.enable {
    description = "Tailscale Serve — Expose LiteLLM Router";
    after = [ "tailscaled.service" "network-online.target" "litellm-router.service" ];
    wants = [ "network-online.target" "litellm-router.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tailscale-serve-start" ''
        # Wait for Tailscale to be ready
        until ${pkgs.tailscale}/bin/tailscale status &>/dev/null; do
          sleep 2
        done

        # LiteLLM router — accessible at https://p620.<tailnet>.ts.net/router
        ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 \
          --set-path=/router http://localhost:${toString routerCfg.port}
      '';

      ExecStop = pkgs.writeShellScript "tailscale-serve-stop" ''
        # Remove all serve configurations
        ${pkgs.tailscale}/bin/tailscale serve reset || true
      '';
    };
  };
}
