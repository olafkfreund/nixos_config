---
status: draft
issue: 2441
intent: intent/2026-10-22-2441-k3d-agent-server-hosts.md
---

# Spec: pin k3d-<cluster>-server-0 in each agent's /etc/hosts

## Design

All in the bootstrap script in `modules/containers/k3d.nix`, and generated
only when `cfg.agents > 0`, so with `agents = 0` the script stays
byte-identical.

Three shell functions, defined after `export K3D_FIX_DNS=0`:

1. `hosts_rewrite IP NAME` is a pure filter (stdin to stdout). It drops every
   line that lists `NAME` as a hostname (a stale pin or the hand-added line
   from 2026-10-22), keeps all other lines, and appends
   `IP NAME # k3d-bootstrap #2441`. Running it twice gives the same output.
2. `pin_server_hosts` runs one pass. It reads server-0's IP on the
   `k3d-<cluster>` network (`docker inspect`) and returns quietly if that is
   empty. It lists the running agents with `docker ps --filter
   label=k3d.cluster=<cluster> --filter label=k3d.role=agent`. For each agent
   it reads `/etc/hosts` with `docker exec cat` and runs `hosts_rewrite`. If
   the result differs, it writes the file back in place with
   `docker exec -i <agent> sh -c 'cat > /etc/hosts'`. `/etc/hosts` is a Docker
   bind mount, so a rename (`sed -i`) would fail. A write is logged to stderr.
3. `hosts_pinned CMD...` starts a background subshell that calls
   `pin_server_hosts` every 2 s, bounded to 450 passes (15 min, the unit's
   `TimeoutStartSec`). It then runs `CMD`, kills and reaps the subshell, runs
   one final pass, and returns `CMD`'s exit status. If `CMD` fails, the helper
   is still reaped before the caller sees the failure. If systemd kills the
   unit, the helper goes with the cgroup, so no orphan is left.

Call sites are prefixed with `hosts_pinned` (a Nix string that is empty when
`agents = 0`):

- (a) `k3d cluster create … --wait`. Create blocks until the agent joins, and
  the helper pins the entry as soon as the agent container exists and
  server-0 has an IP.
- (b) both `k3d cluster start` calls on the reboot path: the first one, and the
  one in each self-heal attempt next to the #2431 serverlb reattach. Docker
  rebuilds `/etc/hosts` on container start, and `start` can block on the
  agent, so the pin has to run while `start` runs as well as after. When the
  cluster is already running, `start` returns at once and the final pass
  still repairs a missing or stale line.

Why this covers the "done when" cases: a fresh create pins during (a). After a
host reboot, the bootstrap timer runs (b). When the agent container alone is
restarted, it still has server-0's IP cached in
`k3s-agent-load-balancer.json`. If that IP is stale, the next bootstrap run
(b) pins the current one.

## Alternatives rejected

- **Drop the resolver mount on agents.** It breaks image pulls (#1497).
- **`--host-alias` at create.** It needs server-0's IP before create.
- **Fixed server IP through a pre-created network or `--subnet`.** k3d's IP
  assignment order is internal and not a contract. The agent would still need
  a hosts entry or a `--host-alias` with that IP. It also changes p620's
  network, so it needs a recreate. It adds risk without removing the pin.
- **`k3d node create` for the agent.** An imperative node gets none of the
  declared mounts.
- **A separate watcher unit that re-pins on Docker events.** It is a new
  long-running service for a case that the cached IP and the next bootstrap
  run already cover.
- **`sed -i` inside the container.** A rename over a bind-mounted file fails.

## Risks

- `cat > /etc/hosts` truncates first, so for a moment k3s could read an empty
  file. That lookup is retried, and a write happens only when the content
  differs.
- `docker exec` every 2 s per agent while create or start runs. This is cheap
  and bounded.
- The k3s image must have `sh` and `cat`. It does (busybox), and the manual
  unblock on 2026-10-22 used the same path.
- Host: p620 only. Nothing changes on a running cluster until the next
  bootstrap run, and that run only rewrites agent `/etc/hosts`.

## Verification

- `nix eval` and `nix build --dry-run` of the p620 toplevel.
- Build the p620 bootstrap script. `writeShellApplication` runs `bash -n` and
  shellcheck, and `bash -n` is also run by hand on the built script.
- With `agents = 0`, the built script is byte-identical to origin/main's
  (diff it with p620 overridden to `agents = 0`, on both trees).
- Unit test of `hosts_rewrite`, cut from the built script, against a temp
  file. It must be idempotent, replace a stale IP and a hand-added unmarked
  line, and keep other lines (including ones that only contain the name as a
  substring).
- Live (lead): restart the agent container and run the bootstrap; see the PR.
