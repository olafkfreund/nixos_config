{ pkgs, ... }:
# Dedicated least-privilege login for the Odin homelab-portal metrics collector
# (the odin-dashboard@factory pod, k3s/factory ns). It SSHes into each host to
# scrape system metrics.
#
# Previously its key sat on `olafkfreund` — a wheel user with passwordless sudo
# — so a Kubernetes pod effectively had root on every host, and every scrape
# spawned a full zsh login shell. On 2026-07-08 a tight reconnect loop from that
# pod hard-froze p510. This user fixes both problems: it is unprivileged (no
# wheel/sudo), uses a cheap bash shell (no interactive rc on `bash -c`), and can
# only read the journal (systemd-journal group) for log-based metrics. The key
# is `restrict`-ed to command execution — no forwarding — while still permitting
# a PTY, which the collector requests today.
#
# ⚠️ The Odin pod MUST connect as `metrics@<host>`, not `olafkfreund@<host>`.
let
  odinKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAXf9GfUzBSKmfIQcDmaEcG3rmorOzGSOFXqMbHvlWSH odin-dashboard@factory";
in
{
  users.groups.metrics = { };
  users.users.metrics = {
    isSystemUser = true;
    group = "metrics";
    # Read-only journal access for log-based metrics; deliberately NOT wheel.
    extraGroups = [ "systemd-journal" ];
    shell = pkgs.bash;
    home = "/var/lib/metrics";
    createHome = true;
    openssh.authorizedKeys.keys = [
      "restrict,pty ${odinKey}"
    ];
  };
}
