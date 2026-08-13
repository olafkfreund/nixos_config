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

  # ── 5. Give docker containers a resolver that actually answers ──────────
  # Without this, containers get `nameserver 172.18.0.1` — the bridge gateway,
  # where NOTHING listens: systemd-resolved binds only 127.0.0.53/127.0.0.54,
  # so every lookup returns `connection refused`. Docker picks the gateway
  # because the host's /etc/resolv.conf lists only loopback addresses, which it
  # cannot copy into a container namespace, and it assumes the host proxies on
  # the bridge. NixOS does not.
  #
  # Measured 2026-08-13: generation 512 restarted docker at 04:50, the k3d
  # nodes came back with the broken resolv.conf, and containerd could not
  # resolve ghcr.io at all (`lookup ghcr.io: Try again`). Running pods were
  # fine — their images were already cached — so this surfaced ONLY as new
  # image tags failing to pull, which is a slow and confusing way to discover
  # a dead resolver. fides sat on a 13-day-old image because of it (fides#395).
  #
  # Public resolvers rather than the host stub: they are reachable from any
  # container namespace with no bridge-address assumption, so this keeps
  # working if the k3d network is recreated on a different subnet.
  #
  # NOTE: this is `daemon.settings`, so it needs a manual `systemctl restart
  # docker` to take effect — see the trade recorded in section 4 above. It
  # applies to containers created AFTER that restart.
  virtualisation.docker.daemon.settings.dns = [
    "1.1.1.1"
    "8.8.8.8"
  ];
}
