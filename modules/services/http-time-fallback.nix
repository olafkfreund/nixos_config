{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption mkIf types escapeShellArgs;
  cfg = config.services.httpTimeFallback;

  syncScript = pkgs.writeShellScript "http-time-fallback" ''
    set -euo pipefail

    # Only act as a fallback: if the primary NTP path (timesyncd over
    # Tailscale, or the public pool) has already synchronised, do nothing.
    if [ "$(${pkgs.systemd}/bin/timedatectl show -p NTPSynchronized --value)" = "yes" ]; then
      echo "NTP already synchronised; HTTPS time fallback not needed."
      exit 0
    fi

    echo "NTP not synchronised — setting clock from HTTPS Date headers."
    for url in ${escapeShellArgs cfg.urls}; do
      date_hdr=$(${pkgs.curl}/bin/curl -sf --max-time 10 -I "$url" \
        | ${pkgs.gnugrep}/bin/grep -i '^date:' \
        | ${pkgs.gnused}/bin/sed 's/^[Dd]ate: //I' \
        | ${pkgs.coreutils}/bin/tr -d '\r') || continue
      if [ -n "$date_hdr" ]; then
        ${pkgs.coreutils}/bin/date -s "$date_hdr"
        # --noadjfile avoids writing /etc/adjtime (ProtectSystem=strict makes
        # /etc read-only); RTC is kept in UTC on this fleet.
        ${pkgs.util-linux}/bin/hwclock --systohc --noadjfile --utc || true
        echo "Clock set from $url ($date_hdr)."
        exit 0
      fi
    done

    echo "http-time-fallback: no HTTPS time source reachable." >&2
    exit 1
  '';
in
{
  options.services.httpTimeFallback = {
    enable = mkEnableOption "HTTPS-based time sync fallback for networks that block NTP (UDP 123)";

    urls = mkOption {
      type = types.listOf types.str;
      default = [
        "https://www.cloudflare.com"
        "https://www.google.com"
        "https://www.kernel.org"
      ];
      description = "HTTPS endpoints whose Date response headers set the clock, tried in order.";
    };

    interval = mkOption {
      type = types.str;
      default = "*:0/15";
      description = "systemd OnCalendar expression controlling how often the fallback check runs.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.http-time-fallback = {
      description = "HTTPS time sync fallback (when NTP/UDP 123 is blocked)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = syncScript;

        # Setting the system clock and RTC requires CAP_SYS_TIME and access
        # to /dev/rtc; ProtectClock must stay false for both to work.
        AmbientCapabilities = [ "CAP_SYS_TIME" ];
        CapabilityBoundingSet = [ "CAP_SYS_TIME" ];
        ProtectClock = false;

        # Hardening otherwise.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
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
