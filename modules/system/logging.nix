# Logging configuration for reduced noise
{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.system.logging;
in
{
  options.system.logging = {
    enableFiltering = mkEnableOption "Enable log filtering for noise reduction";
  };

  config = mkIf cfg.enableFiltering {
    # Configure journald to filter noisy logs
    services.journald.settings.Journal = {
      # Maximum log level for containers
      MaxLevelStore = "info";
      MaxLevelSyslog = "info";
      MaxLevelConsole = "warning";

      # Rate limiting for high-volume logs
      RateLimitIntervalSec = "30s";
      RateLimitBurst = 10000;

      # Storage optimization
      SystemMaxUse = "1G";
      SystemMaxFileSize = "128M";
      RuntimeMaxUse = "512M";
      RuntimeMaxFileSize = "64M";

      # Retention policy
      MaxRetentionSec = "7day";
      MaxFileSec = "1day";
    };

    # Cap coredump storage the same way. systemd's default MaxUse is 10% of
    # the filesystem, which on p620's 916G root is ~90G of crash dumps before
    # anything is evicted. It had accumulated 2.1G by 2026-08-24, most of it a
    # single 968M Chrome core, and nothing was ever going to reclaim it.
    #
    # 1G keeps enough history to actually debug a repeat crash while staying
    # small enough that a browser core cannot quietly eat the disk.
    systemd.coredump.settings.Coredump = {
      MaxUse = "1G";
      KeepFree = "10G";
    };

    # Docker's log driver is deliberately NOT set here.
    #
    # This block used to pin daemon.settings.log-driver = "journald", which
    # silently beat virtualisation.docker.logDriver: daemon.settings IS the
    # rendered daemon.json, so a raw entry here wins over the typed option no
    # matter what a host sets. #1412 switched logDriver to "local" to stop k3s
    # inside k3d filing ~94k INFO lines a boot as host-level errors, and this
    # line quietly reverted it — the built daemon.json still read "journald"
    # after that deploy.
    #
    # A module whose purpose is noise reduction should not be the thing forcing
    # every container's stderr into the journal. The driver now comes from
    # modules/containers/docker.nix, which owns Docker's configuration.
  };
}
