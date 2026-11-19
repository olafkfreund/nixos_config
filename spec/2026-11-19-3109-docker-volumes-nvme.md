---
status: draft
issue: 3109
intent: intent/2026-11-19-3109-docker-volumes-nvme.md
---

# Spec: p620 docker volumes on NVMe through a bind mount

## Design

- New directory `/home/docker-volumes` on nvme0 (`/home` is nvme0n1p1, 283 GB free; after the copy about
  198 GB, 21 %, above the kubelet's 15 % line). Root-owned, the same mode as the original `volumes/`.
- `hosts/p620/nixos/hardware-configuration.nix`: a bind mount
  `fileSystems."/mnt/img_pool/docker/volumes" = { device = "/home/docker-volumes"; fsType = "none";
  options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/home" ]; }`. systemd orders it after
  `/mnt/img_pool` by path. `nofail` keeps boot going if `/home` is missing.
- `hosts/p620/configuration.nix`: `docker.unitConfig.RequiresMountsFor` gains
  `/mnt/img_pool/docker/volumes`, so docker never starts on the empty directory under the mount.
- Docker's data-root, containerd's root (images, build cache) and `/mnt/code/k3d/storage` (profile PVs) do
  not move. Docker sees the same path, so no volume, container or k3d metadata changes.
- The copy is offline: the k3d cluster and every other container are stopped first. Docker runs with
  `live-restore = true`, so stopping the daemon alone would leave the k3d nodes running and writing; the
  containers are stopped explicitly (`k3d cluster stop factory`, then `docker stop` on the rest), then
  docker. `rsync -aHAXS --numeric-ids` keeps owners, hard links, ACLs, xattrs and sparse VM disks; a second
  `rsync -n -c` pass must list nothing.
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
- **Kubelet eviction thresholds** read the new filesystem: 21 % free is above 15 %.

## Verification

- `just test-host p620` builds before anything is stopped.
- After: `findmnt /mnt/img_pool/docker/volumes` shows nvme0n1p1; `systemctl show docker -p RequiresMountsFor`
  lists it; `docker ps` shows the k3d nodes up; `kubectl get nodes` Ready; ArgoCD apps all Synced/Healthy
  (45); PVCs Bound; RFactory runner Ready.
- Load: during the next TFactory run, `sdd` is no longer at 100 % busy for the cluster, and an RFactory
  profile desktop boots within the runner's window (RFactory profiles.sh rollback rehearsal passes).
