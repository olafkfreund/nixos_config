---
status: approved
issue: 1497
author: olafkfreund
---

# Intent: k3d image pulls survive Docker's embedded resolver

## Problem

Image pulls on the p620 `factory` k3d cluster keep failing with
`lookup ghcr.io: Try again`, while pod DNS stays healthy. It has happened three
times (2026-08-28, 2026-09-18, and #1232 before that). Each time it was fixed by
hand, and each time it looked like something other than DNS:

- A deploy goes green and never rolls out, because the new pod sits `Pending`
  or in `ImagePullBackOff` while the old one keeps serving.
- A CronJob goes stale for days (fides-reporter, about 50h on 2026-09-18).

The cluster has two resolvers, and only one of them is declared:

| Resolver | Used by | Today |
| -------- | ------- | ----- |
| `/etc/rancher/k3s/resolv.conf` (`nodeResolvConf`, `modules/containers/k3d.nix:66`) | CoreDNS, so **pods** | declared: `1.1.1.1`, `9.9.9.9` |
| the node container's own `/etc/resolv.conf` | **containerd image pulls** | written by Docker: `nameserver 172.18.0.1` |

`172.18.0.1` is Docker 29's embedded resolver on the bridge gateway (p620 runs
Docker 29.8.0). It forwards to the host's upstream (`192.168.1.254`). On
2026-08-28 and 2026-09-18 it refused connections, and every pull failed. It
answers today (`nslookup ghcr.io` inside `k3d-factory-server-0` works), so
the failure comes and goes. It is not a misconfiguration that is always present.

Why the hand fix does not hold:

- `k3d cluster delete/create` regenerates the file.
- On 2026-09-18 it was back to `172.18.0.1` after a hand edit, so a container
  restart may regenerate it too (the node was restarted on 2026-09-15). That
  is not proven.
- Once it is repaired, pods already in `ImagePullBackOff` stay stuck until
  they are deleted.

The bootstrap's DNS smoke check (`k3d.nix:396`) tests only pod DNS, so it
passes while pulls are failing.

## Proposed outcome

- containerd on every k3d node resolves registries through a declared,
  pod-independent resolver, not whatever Docker picks this release.
- That holds after `k3d cluster delete/create`, a node container restart, a
  p620 reboot and a Docker upgrade, with no hand edits.
- The bootstrap checks the pull path as well as pod DNS, so a broken node
  resolver shows up as a warning in the journal instead of a silent stuck
  rollout.

## Affected users and systems

- p620 only: `modules.containers.k3d` in `hosts/p620/configuration.nix`.
  p510 no longer runs k3d (#1747).
- The `factory` cluster: ArgoCD, factory/fides workloads, and every image pull
  from ghcr.io.
- Possibly `modules/containers/docker.nix` (`daemon.settings`), depending on
  where the fix lands.

## Constraints

- If the fix needs the cluster recreated, that means downtime for ArgoCD and
  factory workloads. The bootstrap's create/rollback loop has cost a day
  before (#1551), so a recreate is planned and announced on the agent bus,
  never a side effect of a deploy.
- Must not break pod DNS: the #1232 fix stays.
- Resolvers must stay reachable from inside the node container. No loopback
  addresses, and no LAN-only names that fail when the host's DNS is down.
- A Docker-wide DNS change affects every container on p620, not only k3d.

## Open questions

1. **How wide the fix is.** Pin only the k3d nodes' `/etc/resolv.conf` (the
   issue's proposal), or set Docker's own upstream DNS on p620 so the embedded
   resolver itself is reliable for every container? The spec will compare
   them. The question for you now is whether a p620-wide Docker DNS change is
   acceptable in principle.
2. **Root cause of the refusals.** Is it worth finding out why `172.18.0.1`
   refused (dockerd restart, a host resolver outage, a netns race), or is
   declaring the resolver enough? Recommendation: enough. Record whatever the
   spec work turns up, but don't block on it.
