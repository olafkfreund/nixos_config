---
status: approved
issue: 3109
spec: spec/2026-11-19-3109-docker-volumes-nvme.md
coders: {}   # two small Nix edits: the lead writes them (below the hand-off threshold)
reviewers:
  - codex   # the logic and the failure paths of the stop/copy/mount order
  - fable   # the goal, the measurements and the recovery path, read independently
---

# Plan: p620 docker volumes on NVMe through a bind mount

Approved decisions (spec): bind-mount only `/mnt/img_pool/docker/volumes` from `/home/docker-volumes` on
nvme0; docker's data-root, containerd's root and `/mnt/code/k3d/storage` stay; docker requires the new mount;
the copy is offline with every container stopped (docker has `live-restore = true`); the old data stays on
`sdd` under the mount until the owner agrees to delete it.

Facts the steps rely on (checked 2026-11-19): `/mnt/img_pool/docker/volumes` is 85 GB, mode 701 root:root,
no submounts; `/home` is nvme0n1p1 (a mandatory mount) with 303 GB free; the k3d node containers restart
`unless-stopped`; docker has `live-restore = true`; `k3d-cluster-bootstrap.service` runs `k3d cluster start
factory` on an existing cluster; `k3d-image-gc.service` and `k3d-cluster-bootstrap.service` require docker;
`nixos-upgrade.timer` switches p620 from GitHub `main` at 04:00 (+45 min); the kubelets evict at 5 % free and
run image GC from 85 % used; the `p620` recipe is `sudo nixos-rebuild switch --flake .#p620` and requires
`main`. Reviews: Codex (gpt-6.1-sol) and Fable, both read-only; their findings are folded in below.

## Steps

1. `hosts/p620/nixos/hardware-configuration.nix`, after `fileSystems."/mnt/img_pool"`: add

   ```nix
   # Docker's volumes (the whole k3d cluster) on nvme0: sdd saturated under factory Jobs (#3109).
   # Bound over the old directory, which stays on sdd untouched until it is deleted on purpose.
   fileSystems."/mnt/img_pool/docker/volumes" = {
     device = "/home/docker-volumes";
     fsType = "none";
     options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/home" ];
   };
   ```

   → verify: `just check-syntax`.
2. `hosts/p620/configuration.nix`, `docker.unitConfig.RequiresMountsFor`: add
   `"/mnt/img_pool/docker/volumes"` (NixOS merges it with the k3d module's `/mnt/code/k3d/storage`).
   → verify: `just test-host p620`; `nix eval` of `systemd.services.docker.unitConfig.RequiresMountsFor` lists
   all three; `fileSystems."/mnt/img_pool/docker/volumes".device` is `/home/docker-volumes`.
3. PR, CI green. **Steps 3 to 8 run in one sitting, finished well before 04:00** (the nightly
   `nixos-upgrade` would switch to a merged `main` on its own). Merge from the shared checkout, not from this
   worktree (`gh pr merge --delete-branch` removes the worktree it runs in). Fast-forward `~/.config/nixos`
   to `origin/main` and build: `just test-host p620`. Nothing is stopped before this build passes.
4. Pre-flight, no changes: `/home/docker-volumes` does not exist; `df -B1 /home` available ≥ the size of
   `volumes/` (`du -sb`) + 150 GB; `read_new` on the bus shows no deploy in flight; `kubectl get jobs -A` for
   running factory Jobs (wait up to 15 minutes if one is close to done); RFactory runs no desktops. Post on the
   bus: k3d cluster and all docker containers down for about 45 minutes.
5. Barrier, then stop (all as root; each command must succeed):
   1. `systemctl stop nixos-upgrade.timer k3d-image-gc.timer k3d-cluster-bootstrap.timer`, then
      `systemctl mask --runtime nixos-upgrade.service k3d-image-gc.service k3d-cluster-bootstrap.service`;
   2. `k3d cluster stop factory`; `docker ps -q` names of the other running containers into
      `/root/3109-containers.txt`, then `docker stop` them; `docker ps -q` must be empty;
   3. `systemctl stop docker.socket docker.service`; `systemctl mask --runtime docker.socket docker.service`;
      `systemctl is-active docker docker.socket` must both be inactive.
6. Copy, record the time (a throughput benchmark of nvme0: under about 150 MiB/s is a warning):
   `install -d -m 701 -o root -g root /home/docker-volumes`;
   `rsync -aHAXS --numeric-ids /mnt/img_pool/docker/volumes/ /home/docker-volumes/`;
   then `rsync -aHAXS --numeric-ids -n -c --delete --itemize-changes` (same paths) must exit 0 and print
   nothing. That pass is the gate (sizes from `du` may differ because of sparse files).
7. Mount and switch:
   1. `mount --bind /home/docker-volumes /mnt/img_pool/docker/volumes`; `findmnt` must show
      `/dev/nvme0n1p1[/docker-volumes]`. From here docker can only ever see the NVMe copy.
   2. `systemctl unmask --runtime docker.socket docker.service`.
   3. In `~/.config/nixos`: `AGENT_BUS_ANNOUNCED=1 just p620`. The switch adopts the mount and starts docker
      after it; if docker is not running, `systemctl start docker`.
8. Start and check:
   1. `systemctl unmask --runtime nixos-upgrade.service k3d-image-gc.service k3d-cluster-bootstrap.service`;
      `systemctl start nixos-upgrade.timer k3d-image-gc.timer`;
      `systemctl restart k3d-cluster-bootstrap.service` (it runs `k3d cluster start factory`); `docker start`
      the names in `/root/3109-containers.txt`.
   2. → verify: `kubectl get nodes` both Ready; ArgoCD apps all Synced/Healthy (allow 10 minutes); PVCs Bound;
      `rfactory-runner` Ready; `docker volume ls` count unchanged; kubelet `stats/summary` imagefs on NVMe.
9. Load check (pass criteria): during the next factory Job, IO pressure `full avg60` stays under 2 % and `sdd`
   is not busy on the cluster's behalf; an RFactory profile desktop attach completes (RFactory profiles.sh
   rollback rehearsal). Post the result on the bus and in #3109. After a week: SMART on nvme0 (baseline
   2026-11-19: 0 % used, 3.67 TB written).

## Tests

- `just check-syntax`, `just test-host p620` (steps 1 to 3).
- Step 6's checksum pass prints nothing; step 8's checks pass; step 9's criteria.

## Rollback

- **Before step 7** (nothing switched yet): unmask docker, start docker, `k3d cluster start factory`, start the
  recorded containers, unmask and start the timers; the old data was never touched. If the PR is already
  merged, revert it on `main` before 04:00. Then delete `/home/docker-volumes`.
- **After step 7, keeping the current state (default)**: do the barrier and stop of step 5; `umount
  /mnt/img_pool/docker/volumes` and confirm with `findmnt -T` that the path is on `/dev/sdd1`; check `sdd` has
  room; `rsync -aHAXS --numeric-ids --delete /home/docker-volumes/ /mnt/img_pool/docker/volumes/` and the
  same checksum pass; revert the PR on `main`, `just p620`, then start as in step 8. Never copy back while the
  bind is mounted: both paths would be the same directory.
- **Disaster recovery only**: the untouched old `volumes/` on `sdd` matches the moment of the stop. Using it
  after the cluster has run on NVMe pairs an older datastore with newer PVs on `/mnt/code`; only with the
  owner's explicit acceptance of that loss.
- The old directory stays on `sdd` until the owner agrees to delete it; to reach it later, bind-mount
  `/mnt/img_pool` non-recursively at a temporary path.
