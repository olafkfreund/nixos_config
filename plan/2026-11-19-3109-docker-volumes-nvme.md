---
status: draft
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

Facts the steps rely on (checked 2026-11-19): `/mnt/img_pool/docker/volumes` is 85 GB, mode 701 root:root;
`/home` is nvme0n1p1 with 283 GB free; the k3d node containers restart `unless-stopped`;
`k3d-cluster-bootstrap.service` runs `k3d cluster start factory` on an existing cluster; the `p620`
recipe is `sudo nixos-rebuild switch --flake .#p620` and requires `main`.

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
   → verify: `just check-syntax`. Traps: `nofail` only keeps boot going; step 2 is what stops docker.
2. `hosts/p620/configuration.nix`, `docker.unitConfig.RequiresMountsFor`: add
   `"/mnt/img_pool/docker/volumes"` (the k3d module adds `/mnt/code/k3d/storage`; NixOS merges the lists).
   → verify: `just test-host p620`, then
   `nix eval .#nixosConfigurations.p620.config.systemd.services.docker.unitConfig.RequiresMountsFor` lists all
   three, and `...config.fileSystems."/mnt/img_pool/docker/volumes".device` is `/home/docker-volumes`.
3. PR, CI green, merge (from the shared checkout, not from this worktree: `gh pr merge --delete-branch`
   removes the worktree it runs in). Fast-forward `~/.config/nixos` to `origin/main`; build it once more:
   `just test-host p620`. Nothing is stopped before this build passes.
4. Pre-flight (no changes): `df /home` free ≥ 120 GB; `read_new` on the bus shows no deploy in flight;
   `kubectl get jobs -A` for running factory Jobs (wait up to 15 min if one is about to finish); RFactory has
   no desktops (`k14-env.sh status`). Post on the bus: stop window about 20 minutes, all k3d services down.
5. Stop: `k3d cluster stop factory`; `docker stop` every other running container (record the names in
   `/root/3109-containers.txt` to start them again); `docker ps -q` must be empty;
   `systemctl stop k3d-cluster-bootstrap.service docker.socket docker.service`.
6. Copy: `install -d -m 701 -o root -g root /home/docker-volumes`;
   `rsync -aHAXS --numeric-ids /mnt/img_pool/docker/volumes/ /home/docker-volumes/`;
   then `rsync -aHAXS --numeric-ids -n -c --itemize-changes ...` must print nothing.
   → verify: `du -s` of both within 1 %.
7. Deploy: in `~/.config/nixos`, `AGENT_BUS_ANNOUNCED=1 just p620`. The switch mounts the bind mount and
   (RequiresMountsFor) starts docker after it. Then `findmnt /mnt/img_pool/docker/volumes` must show
   `/dev/nvme0n1p1[/docker-volumes]` before anything else; if docker is not running, `systemctl start docker`.
8. Start: `systemctl restart k3d-cluster-bootstrap.service` (it runs `k3d cluster start factory`); `docker
   start` the names in `/root/3109-containers.txt`.
   → verify: `kubectl get nodes` both Ready; ArgoCD apps 45 Synced/Healthy (allow 10 minutes); PVCs Bound;
   `rfactory-runner` Ready; `docker volume ls` count unchanged.
9. Load check: `/proc/pressure/io` and `sdd` busy during the next factory Job; an RFactory profile desktop
   attach completes (RFactory profiles.sh rollback rehearsal). Post the result on the bus and in #3109.

## Tests

- `just check-syntax`, `just test-host p620` (steps 1 to 3).
- The step 6 dry-run pass prints nothing; the step 8 checks pass.

## Rollback

- Before step 7: `systemctl start docker`, `k3d cluster start factory`, start the recorded containers: the
  old data was never touched. Delete `/home/docker-volumes` afterwards.
- After step 7: stop as in step 5, revert this PR on `main` and `just p620` (the mount goes; docker sees the
  old directory on `sdd` as it was at the stop), start as in step 8. Changes made on NVMe after the switch
  are lost; copy them back first with the same rsync reversed if they matter.
- Never delete `sdd`'s old `volumes/` without the owner: it is the rollback.
