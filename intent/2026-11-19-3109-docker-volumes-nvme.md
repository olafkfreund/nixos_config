---
status: approved
issue: 3109
author: olafkfreund
---

# Intent: p620 docker volumes (the k3d cluster) off the saturated SATA disk

## Problem

Docker's data-root on p620 is `/mnt/img_pool/docker` on `sdd`, a Micron 256 GB SATA SSD (76 % full). Its
`volumes/` directory (85 GB) holds the whole k3d `factory` cluster: each node's `/var/lib/rancher/k3s` (the
k3s datastore, the node's containerd and images, pod and VM disks; server 75 GB, agent 8.4 GB). During factory
Jobs `sdd` writes about 60 MiB/s at 100 % busy while both NVMe drives idle. Measured on 2026-11-19:

- IO pressure "full" about 14 % over 5 minutes, load average 21 on 128 idle cores;
- Kubernetes API calls time out ("unable to return a response in the time allotted"); virt-template-controller
  lost leader election 26 times in 21 h;
- local-path volumes wait about 60 s to provision; RFactory desktop VMs miss the runner's 60 s window
  (`no-control`, `launcher pod did not become ready`, `VMI did not reach Paused`), which blocks RFactory #3's
  verification.

## Proposed outcome

- The k3d nodes' volumes live on NVMe; `sdd` keeps only docker images (containerd root) and build cache, which
  are idle outside builds.
- The cluster comes back with the same data: all ArgoCD apps Synced/Healthy, PVCs Bound, the RFactory runner up.
- Under a TFactory run the cluster disk is no longer saturated, and an RFactory profile desktop boots in time.

## Affected users and systems

- p620 only. Every Factory service on the k3d cluster, and every other docker container, stops during the copy
  (about 15 minutes). Other agents' jobs on the cluster (TFactory runs) are interrupted.
- `hosts/p620/nixos/hardware-configuration.nix`, `hosts/p620/configuration.nix`.

## Constraints

- Announce on the agent bus before stopping the cluster and before the deploy; no deploy while another agent's
  deploy is in flight.
- No data loss: the old `volumes/` stays on `sdd` untouched (hidden under the bind mount) until the owner
  agrees to delete it.
- Docker must refuse to start without the new mount, as it already does for `/mnt/img_pool` (no fresh empty
  volumes).
- nvme0 must stay above the kubelet's 15 % image-filesystem eviction line.
- p510 and razer are not touched.

## Open questions

None: the owner chose nvme0 and approved the change and its execution on 2026-11-19.
