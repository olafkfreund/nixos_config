{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption mkIf types escapeShellArgs;
  cfg = config.services.httpTimeFallback;

  # nixpkgs builds htpdate HTTP-only; rebuild the Makefile's `https` target
  # (+ openssl) so the fallback works over TLS/443. Kept local to this module
  # since only roaming hosts (razer) enable it.
  htpdateHttps = pkgs.htpdate.overrideAttrs (o: {
    pname = "htpdate-https";
    buildInputs = (o.buildInputs or [ ]) ++ [ pkgs.openssl ];
    buildFlags = [ "https" ];
    makeFlags = (o.makeFlags or [ ]) ++ [ "SSL_LIBS=-lssl -lcrypto" ];
  });

  syncScript = pkgs.writeShellScript "http-time-fallback" ''
    set -euo pipefail

    # Fallback only: if NTP (timesyncd) has already synchronised, do nothing
    # so we never fight normal NTP discipline.
    if [ "$(${pkgs.systemd}/bin/timedatectl show -p NTPSynchronized --value)" = "yes" ]; then
      echo "NTP already synchronised; htpdate fallback not needed."
      exit 0
    fi

    echo "NTP not synchronised — setting clock via htpdate over HTTPS."
    # -s set clock, -4 IPv4, -c verify server certificate. htpdate samples
    # multiple HTTPS servers and compensates for request round-trip latency.
    if ${htpdateHttps}/bin/htpdate -s -4 -c ${escapeShellArgs cfg.urls}; then
      # Persist to RTC so a reboot on a blocked network keeps good time.
      # --noadjfile: /etc is read-only under ProtectSystem=strict; RTC is UTC.
      ${pkgs.util-linux}/bin/hwclock --systohc --noadjfile --utc || true
      exit 0
    fi

    echo "http-time-fallback: no HTTPS time source reachable." >&2
    exit 1
  '';
in
{
  options.services.httpTimeFallback = {
    enable = mkEnableOption "HTTPS-based time sync fallback (htpdate) for networks that block NTP (UDP 123)";

    urls = mkOption {
      type = types.listOf types.str;
      default = [
        "https://www.cloudflare.com"
        "https://www.google.com"
        "https://www.kernel.org"
      ];
      description = "HTTPS endpoints htpdate samples to set the clock.";
    };

    interval = mkOption {
      type = types.str;
      default = "*:0/15";
      description = "systemd OnCalendar expression controlling how often the fallback check runs.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.http-time-fallback = {
      description = "HTTPS time sync fallback via htpdate (when NTP/UDP 123 is blocked)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = syncScript;
        # htpdate's TLS uses openssl; point it at the system CA bundle.
        Environment = "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

        # Setting the system clock and RTC requires CAP_SYS_TIME and access
        # to /dev/rtc; ProtectClock must stay false for both to work.
        AmbientCapabilities = [ "CAP_SYS_TIME" ];
        CapabilityBoundingSet = [ "CAP_SYS_TIME" ];
        ProtectClock = false;

        # Hardening otherwise. AF_UNIX/AF_NETLINK are kept so glibc name
        # resolution (nss, getaddrinfo) still works.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
        RestrictNamespaces = true;
        MemoryDenyWriteExecute = true;
      };
    };

    systemd.timers.http-time-fallback = {
      description = "Periodic HTTPS time sync fallback check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnCalendar = cfg.interval;
        Persistent = true;
      };
    };
  };
}
