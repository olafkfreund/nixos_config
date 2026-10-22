---
status: draft
issue: 2441
author: olafkfreund
---

# Intent: k3d agents must always reach k3d-<cluster>-server-0

## Problem

Since #2440 p620's k3d-factory cluster has one agent. The agent joins through
`K3S_URL=https://k3d-factory-server-0:6443`, but it mounts the declared
resolver over `/etc/resolv.conf` (#1497, needed for image pulls), so Docker's
embedded DNS is bypassed and the server's container name does not resolve.
`k3d cluster create` hung at "Starting agents" on 2026-10-22 until
`<server-0 IP> k3d-factory-server-0` was appended to the agent's `/etc/hosts`
by hand.

That fix does not last. Server-0 has no static IP, and Docker rebuilds a
container's `/etc/hosts` when it starts the container, so the entry is gone
after an agent restart or a host reboot.

## Proposed outcome

- A fresh `k3d cluster create` with `agents = 1` finishes without manual help.
- After an agent container restart or a host reboot, a bootstrap run leaves
  the agent's `/etc/hosts` pointing at server-0's current IP, and the agent
  rejoins.

## Affected users and systems

p620 only (`agents = 1`): `k3d-cluster-bootstrap`, module
`modules/containers/k3d.nix`. Hosts with `agents = 0` are unaffected.

## Constraints

- Keep the resolver mount on agents (#1497).
- No `k3d node create`: an imperative agent has none of the declared mounts.
- With `agents = 0` the generated bootstrap script is byte-identical to today's.
- No destructive action and no deploy as part of this change. The lead
  verifies live.

## Open questions

None.
