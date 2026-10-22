---
status: approved
issue: 2441
spec: spec/2026-10-22-2441-k3d-agent-server-hosts.md
---

# Plan: pin k3d-<cluster>-server-0 in each agent's /etc/hosts

Approved decisions (from the spec):

- k3d agents mount the declared resolver over `/etc/resolv.conf` (#1497, which
  must stay), so the agent's K3S_URL host `k3d-<cluster>-server-0` does not
  resolve. The bootstrap pins it in each agent's `/etc/hosts`.
- `hosts_rewrite IP NAME` is a pure stdin-to-stdout filter. It drops every
  line that names `NAME` as a hostname and appends
  `IP NAME # k3d-bootstrap #2441`. It is idempotent.
- `pin_server_hosts` runs one pass: server-0's IP on network `k3d-<cluster>`,
  agents from `docker ps` by label `k3d.cluster=<cluster>` and
  `k3d.role=agent`, then read, filter and write in place with
  `docker exec -i … sh -c 'cat > /etc/hosts'` (a bind mount, so no `sed -i`),
  and only when the content changed.
- `hosts_pinned CMD…` runs a background pass loop every 2 s (at most 450
  passes) while CMD runs, kills and reaps it, runs one final pass, and
  returns CMD's status.
- It wraps `k3d cluster create` and both `k3d cluster start` calls.
- All of this is generated only when `cfg.agents > 0`. With `agents = 0` the
  script is byte-identical.
- Rejected: dropping the resolver mount, `--host-alias`, a fixed IP or
  pre-created network, `k3d node create`, a watcher unit, `sed -i`.

## Steps

1. `modules/containers/k3d.nix` `let` block (after `resolvStateFile`, about
   line 79): add `hostsPinFns`, which is `optionalString (cfg.agents > 0)` of
   the three functions, and `pinned = optionalString (cfg.agents > 0)
   "hosts_pinned "`.
   Traps: Nix `''` strings need `''${` for a literal bash `${`, so use plain
   `$var`. `writeShellApplication` runs shellcheck.
2. `modules/containers/k3d.nix` bootstrap text: put `${hostsPinFns}` on the
   blank line after `export K3D_FIX_DNS=0`. Prefix `${pinned}` to
   `k3d cluster create` and to both `k3d cluster start` calls (the
   `>/dev/null 2>&1 || true` one, and `start_err=$(k3d cluster start …)`).
   → verify: build the p620 bootstrap script, run `bash -n` on it, and diff
   it against origin/main with `agents = 0` (no diff).
   Traps: never run docker, k3d, kubectl or nixos-rebuild against the live
   cluster.

## Tests

- `nix eval .#nixosConfigurations.p620.config.modules.containers.k3d.agents`
  gives `1`.
- `nix build --dry-run .#nixosConfigurations.p620.config.system.build.toplevel`
  succeeds.
- Build the bootstrap script for p620 (succeeds, which means shellcheck
  passed), then run `bash -n` on it.
- `agents = 0` (via `extendModules`) on this tree and on origin/main: the
  script texts are identical.
- `hosts_rewrite`, cut from the built script, run against a temp hosts file:
  it appends the pin, a second run changes nothing, a stale IP is replaced,
  a hand-added unmarked line is replaced, and other lines (localhost, the
  agent's own name, `k3d-<cluster>-server-0x`) are kept.

## Rollback

Revert the commit. The next bootstrap run stops pinning. Lines already
written stay in agent `/etc/hosts` until Docker rebuilds the file on the next
container start, and they do no harm.
