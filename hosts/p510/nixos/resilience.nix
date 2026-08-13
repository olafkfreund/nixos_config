{ lib, pkgs, ... }:
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
  # ── 4. Keep k3d alive across a nixos-rebuild ────────────────────────────
  # nixos-upgrade.timer rebuilds nightly (~04:00). When the docker unit changes
  # — which it does whenever nvidia-container-toolkit-cdi-generator.service, a
  # hard `Requires=`, is rebuilt — activation restarts docker.service and takes
  # every k3d container with it.
  #
  # The server and serverlb come back on their `unless-stopped` policy. The
  # agent does not, because its shutdown deadlocks: a pod holding an open file
  # on the in-cluster NFS export cannot complete __fput -> nfs_file_release ->
  # nfs4_do_close without an RPC to a server that docker has just stopped. The
  # kubelet's mounts are `vers=4.1` with no `soft`, so the RPC retries forever,
  # the container's PID namespace never drains, and docker reports the corpse
  # as `Up` with zero processes inside — so `restart: unless-stopped` never
  # fires and the node sits NotReady.
  #
  # That is not theoretical: 2026-08-06, agent killed 04:15, node NotReady for
  # 7h. It stranded argocd-application-controller (every deploy landed nowhere
  # while ArgoCD still reported Synced), nfs-provisioner (its local-path PV
  # pins it to that node), and tfactory (FailedMount x218). The wedge was
  # SIGKILL-proof kernel state, so recovery meant rebuilding the container by
  # hand. See Factory#582 and factory-gitops#138.
  #
  # Not restarting docker on rebuild removes the trigger entirely. The cost is
  # that daemon.settings changes need a manual `systemctl restart docker` (or a
  # reboot) to take effect — the same trade already accepted for libvirtd in
  # modules/virt/virt.nix. Cheap, because that config changes rarely and the
  # cluster it carries is expensive to rebuild.
  systemd.services.docker.restartIfChanged = false;

  # ...and that was only half the trigger. On 2026-08-12 the k3d SERVER wedged
  # the same way despite the line above, and the cluster sat dead ~6h. The
  # nightly upgrade never restarted docker for its own definition — it stopped
  # docker as a DEPENDENCY:
  #
  #   $ systemctl show docker.service -p Requires
  #   Requires=... nvidia-container-toolkit-cdi-generator.service ...
  #   $ systemctl show nvidia-container-toolkit-cdi-generator.service -p ActiveState
  #   ActiveState=failed
  #
  # nixpkgs' nvidia-container-toolkit module sets
  # `requiredBy = mkIf virtualisation.docker.enable [ "docker.service" ]`
  # (services/hardware/nvidia-container-toolkit/default.nix). A `Requires=` on a
  # unit that FAILS stops docker, and `restartIfChanged` has no bearing on that
  # — it governs restart-on-changed-definition only. The knob was applied, and
  # inert, which is why it looked fixed for six days.
  #
  # The generator fails after every driver update until the box reboots:
  #   "failed to initialize NVML: Driver/library version mismatch"
  # — new nvidia-x11 in the store, old kernel module still loaded. So the
  # trigger is not rare, it is EVERY nvidia bump, on a nightly timer.
  #
  # A GPU spec generator must not be able to take the cluster down. `wantedBy`
  # still runs it with docker and `before` orders it properly (upstream has
  # requiredBy with NO ordering, so docker could already start before the spec
  # existed — fatal, and not even reliably first). Failing now degrades GPU
  # containers instead of stopping the container runtime.
  #
  # This removes the TRIGGER. The reason a stopped docker is catastrophic here
  # is the NFS __fput deadlock described above, which is unchanged: any docker
  # stop can still strand a container holding a file on the in-cluster export.
  # See Factory#687.
  # podman is enabled here too and upstream gives it the same fatal `requiredBy`,
  # so both are re-wired. Dropping podman's without replacing it would quietly
  # cost it the CDI spec it does want, just not at the price of the runtime.
  systemd.services.nvidia-container-toolkit-cdi-generator = {
    requiredBy = lib.mkForce [ ];
    wantedBy = [
      "docker.service"
      "podman.service"
    ];
    before = [
      "docker.service"
      "podman.service"
    ];
  };

  # ── 5. Disk health monitoring ───────────────────────────────────────────
  # p510 had NO way to see disk health: smartctl was not installed, so the
  # state of four drives holding ~4TB of media was pure guesswork. #1194 was
  # filed against the ST1000LM035 on the strength of dmesg lines that turned
  # out to be a grep matching "UNC" inside "f-unc-tions"; the drive's own data
  # is clean (0 reallocated, 0 pending, 0 uncorrectable, no logged errors).
  #
  # The drive that IS degrading was never suspected: /dev/sdb, the 12TB
  # ST12000NM0127 carrying /mnt/media — 2872 reallocated, 624 pending, 624
  # offline-uncorrectable, 1693 logged ATA errors, at only 14101 power-on
  # hours. Pending == uncorrectable means those sectors are confirmed
  # unreadable, not merely queued for remap.
  #
  # Note smartctl still reports "PASSED" for it: the overall verdict only
  # fails when a NORMALISED value crosses its threshold, and
  # Current_Pending_Sector's threshold is 0, so it can never trip that verdict
  # however high the raw count climbs. Judge these drives on raw attributes,
  # not on the headline.
  environment.systemPackages = [ pkgs.smartmontools ];

  services.smartd = {
    enable = true;
    autodetect = true;
    # -a: all attributes. -o on/-S on: keep offline collection + attribute
    # autosave enabled so the counters above stay current between reads.
    # Short self-test nightly, long self-test weekly (Saturday 03:00, before
    # the 04:00 nixos-upgrade window rather than during it).
    defaults.monitored = "-a -o on -S on -s (S/../.././02|L/../../6/03)";
  };

  # ── Give docker containers a resolver that actually answers ─────────────
  # Without this, containers get `nameserver 172.18.0.1` — the bridge gateway,
  # where NOTHING listens: systemd-resolved binds only 127.0.0.53/127.0.0.54,
  # so every lookup in every container returns `connection refused`. Docker
  # picks the gateway because the host's /etc/resolv.conf lists only loopback
  # addresses, which it cannot copy into a container namespace, so it assumes
  # the host proxies DNS on the bridge. NixOS does not.
  #
  # Found the slow way, 2026-08-13. Generation 512 restarted docker at 04:50,
  # the k3d nodes came back with the broken resolv.conf, and containerd could
  # not resolve ghcr.io at all (`lookup ghcr.io: Try again`). Already-running
  # pods were fine — their images were cached — so the ONLY symptom was new
  # image tags failing to pull, which reads like a registry or auth fault
  # rather than a dead resolver. fides sat on a 13-day-old unsigned image
  # because of it (fides#395).
  #
  # Public resolvers rather than the host stub: reachable from any container
  # namespace with no bridge-address assumption, so this keeps working if the
  # k3d network is recreated on a different subnet.
  #
  # Merges with the daemon.settings block in modules/system/logging.nix.
  #
  # NOTE: `daemon.settings` needs a manual `systemctl restart docker` to take
  # effect — the same trade the restartIfChanged block above accepts, and it
  # applies only to containers created after that restart.
  virtualisation.docker.daemon.settings.dns = [
    "1.1.1.1"
    "8.8.8.8"
  ];
}
