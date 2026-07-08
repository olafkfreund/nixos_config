_:
# Resilience hardening for p510 (headless media / k3d-factory server).
#
# Added after a 2026-07-08 hard freeze: the Odin metrics pod hammered sshd in a
# reconnect loop (each connection spawning a login shell) on top of k3d pod
# churn, wedging the host with no safety net — it sat dead ~2h until a manual
# power-cycle. earlyoom (memory.nix) exists but only fires on absolute free
# memory + swap, and is a userspace process a hard hang can starve, so it never
# acted.
#
# Defense in depth (each layer is independent):
#   1. Hardware watchdog  — a hung kernel auto-reboots in ~2min.
#   2. sshd rate-limiting — bound a login storm at the door.
#   3. systemd-oomd       — cgroup-pressure OOM management over system.slice
#                           (docker/k3d), killing the offending pod before the
#                           whole host deadlocks.
{
  # ── 1. Intel TCO hardware watchdog (Xeon C61x PCH) ──────────────────────
  # systemd pets /dev/watchdog every runtimeTime; if the kernel hangs, the chip
  # hardware-resets the box. rebootTime bounds a graceful reboot before that.
  boot.kernelModules = [ "iTCO_wdt" ];
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s"; # ping /dev/watchdog; hang -> hardware reset
    RebootWatchdogSec = "2min"; # graceful-reboot deadline before hard reset
  };

  # ── 2. sshd throttling ──────────────────────────────────────────────────
  # Caps how fast/many any single source can open sessions, so a looping client
  # (or a scanner) cannot fork-storm the host. Merges with the shared openssh
  # module (which only sets enable + X11Forwarding).
  services.openssh.settings = {
    LoginGraceTime = 20;
    MaxStartups = "10:30:60";
    MaxSessions = 20;
    PerSourceMaxStartups = 10;
  };

  # ── 3. systemd-oomd (cgroup-pressure OOM management) ─────────────────────
  # Kills the heaviest cgroup under sustained memory pressure (typically a
  # runaway k3d pod) instead of letting the host deadlock. Complements earlyoom
  # in memory.nix (an absolute-free-memory backstop).
  systemd.oomd = {
    enable = true;
    enableSystemSlice = true;
  };
  # Act on docker (and thus its k3d containers) when the cgroup's memory
  # pressure stays high, capping the cluster's blast radius without a brittle
  # hard MemoryMax that could kill the cluster under normal load.
  systemd.services.docker.serviceConfig = {
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "80%";
  };
}
