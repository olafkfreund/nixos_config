---
status: approved
issue: 3109
intent: intent/2026-11-19-3109-docker-volumes-nvme.md
---

# Spec: p620 docker volumes on NVMe through a bind mount

## Design

- New directory `/home/docker-volumes` on nvme0 (`/home` is nvme0n1p1, 303 GB free; after the copy about
  218 GB). Root-owned, mode 701 like the original `volumes/`. The live kubelet config (`/configz`, both nodes)
  evicts at 5 % free (`evictionHard` imagefs and nodefs) and runs image GC from 85 % used down to 80 %; after
  the copy `/home` is about 78 % used, so roughly 60 GB of further growth on `/home` starts image GC (Fable).
- `hosts/p620/nixos/hardware-configuration.nix`: a bind mount
  `fileSystems."/mnt/img_pool/docker/volumes" = { device = "/home/docker-volumes"; fsType = "none";
  options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/home" ]; }`. systemd orders it after
  `/mnt/img_pool` by path. `/home` itself is a mandatory mount (no `nofail`, hardware-configuration.nix), so
  the bind's `nofail` changes nothing at boot; docker's dependency below is what guards the data (Codex).
- `hosts/p620/configuration.nix`: `docker.unitConfig.RequiresMountsFor` gains
  `/mnt/img_pool/docker/volumes`, so docker never starts on the empty directory under the mount.
- Docker's data-root, containerd's root (images, build cache) and `/mnt/code/k3d/storage` (profile PVs) do
  not move. Docker sees the same path, so no volume, container or k3d metadata changes.
- The copy is offline, behind a restart barrier: the timers and units that can start docker or the cluster
  (`k3d-cluster-bootstrap`, `k3d-image-gc`, `nixos-upgrade`) are stopped and runtime-masked first (Codex,
  Fable), then the k3d cluster and every other container are stopped. Docker runs with
  `live-restore = true`, so stopping the daemon alone would leave the k3d nodes running and writing; the
  containers are stopped explicitly (`k3d cluster stop factory`, then `docker stop` on the rest), then
  docker, which is runtime-masked too. The destination must not exist beforehand. `rsync -aHAXS
  --numeric-ids` keeps owners, hard links, ACLs, xattrs (`trusted.overlay.*`), device nodes (overlay whiteouts)
  and sparse VM disks; a second `rsync -n -c --delete --itemize-changes` pass must exit 0 and print nothing.
- The bind mount is made by hand after the check and before the switch, so docker can never open the old
  directory again; the switch adopts the existing mount (Fable).
- The merge and the switch happen in one sitting, well before the nightly `nixos-upgrade` (04:00), which
  would otherwise apply the merged change on its own (Fable).
- After the deploy, docker starts on the mount; `k3d-cluster-bootstrap` (restarted) runs
  `k3d cluster start factory`, as on every reboot. Containers stopped by hand come back with
  `docker start` (restart policy `unless-stopped` keeps them down otherwise).

## Alternatives rejected

- **Move the whole data-root to NVMe** (168 GB): leaves nvme0 at 13 % free, under the kubelet's 15 %
  eviction line; images and build cache are not the hot path.
- **Move only the build cache**: frees space but not IO; every measured write came from pods inside the k3d
  server node.
- **nvme1 (`/`)**: same free space, but it also holds `/` and the Nix store, so builds and the cluster would
  compete. nvme0 holds `/home` only.
- **`/mnt/code` (sda, 786 GB free)**: also SATA; it already carries the profile PVs since earlier fsync
  stalls.
- **Remove ArgoCD or the cluster**: not the cause (see the ArgoCD review of 2026-11-19).

## Risks

- **A container writes during the copy** → an inconsistent k3s datastore. Mitigation: check `docker ps` is
  empty before the copy, docker stopped, and the `-c` dry-run pass is empty.
- **The mount is missing at boot** (nvme0 failure) → docker refuses to start (RequiresMountsFor); the cluster
  stays down rather than starting empty. Recovery: the rollback below.
- **Space**: 85 GB into 283 GB free; checked before the copy.
- **Other agents' jobs**: TFactory Jobs are killed by the stop. Announced; wait for running Jobs if any are
  near the end.
- **Kubelet thresholds** read the new filesystem: eviction at 5 % free, image GC from 85 % used. After the
  copy `/home` is about 78 % used. A follow-up alert at 150 GB free on `/home` is worth adding (not here).
- **Wear**: about 500 GiB/day of cluster writes moves onto nvme0, which holds `/home` (a mandatory mount).
  SMART baseline 2026-11-19: nvme0 0 % used, 3.67 TB written; check again after a week (Fable).
- **The move buys speed, not isolation**: the datastore still shares a filesystem with the pods' scratch
  writes and `k3d image import`. If IO pressure stays high on nvme0, those writers are the next step (Fable).
- **The old `volumes/` is not a full rollback once the cluster runs again**: the PVs on `/mnt/code` move on,
  so an old datastore with newer PVs is inconsistent. The rollback copies the current NVMe state back
  (Codex).

## Verification

- `just test-host p620` builds before anything is stopped.
- After: `findmnt /mnt/img_pool/docker/volumes` shows nvme0n1p1; `systemctl show docker -p RequiresMountsFor`
  lists it; `docker ps` shows the k3d nodes up; `kubectl get nodes` Ready; ArgoCD apps all Synced/Healthy
  (45); PVCs Bound; RFactory runner Ready.
- Load: during the next TFactory run, `sdd` is no longer at 100 % busy for the cluster, and an RFactory
  profile desktop boots within the runner's window (RFactory profiles.sh rollback rehearsal passes).
