"""Reap Claude Code swarm tmux servers that outlived their lead or went idle.

Only sockets named claude-swarm-<pid> in the user's tmux directory are touched.
`hook idle|active` (Claude Code hooks) records or clears a teammate's idle
timestamp; `reap` (a timer) kills orphaned servers and long-idle teammate panes.
The hook never writes stdout, never raises and always exits 0.
"""

import argparse
import contextlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

SOCKET_RE = re.compile(r"^claude-swarm-(\d+)$")


def log(msg):
    print(f"claude-swarm-reaper: {msg}", file=sys.stderr, flush=True)


def record_root():
    return (
        Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
        / "claude-swarm-reaper"
    )


def socket_dir():
    return Path(f"/run/user/{os.getuid()}/tmux-{os.getuid()}")


def decide(sockets, alive, panes, records, now, idle_seconds):
    """Return [(action, socket, pane, reason)]; action is kill-server or kill-pane.

    sockets: socket names; alive: {pid: bool}; panes: {socket: [pane ids] or None
    when the server could not be queried}; records: {socket: {pane: idle ts}}.
    """
    out = []
    for sock in sorted(sockets):
        m = SOCKET_RE.match(sock)
        if not m:
            continue
        if not alive.get(int(m.group(1)), False):
            out.append(("kill-server", sock, None, "lead dead"))
            continue
        live = panes.get(sock)
        if live is None:
            continue
        stale = [
            p
            for p in live
            if p in records.get(sock, {}) and now - records[sock][p] >= idle_seconds
        ]
        for p in stale:
            out.append(("kill-pane", sock, p, "idle past window"))
        if len(stale) == len(live):
            out.append(("kill-server", sock, None, "no panes left"))
    return out


def hook(kind):
    try:
        with contextlib.suppress(OSError, ValueError):
            sys.stdin.read()  # drain the payload; nothing in it is needed
        tmux = os.environ.get("TMUX", "")
        pane = os.environ.get("TMUX_PANE", "")
        if "/claude-swarm-" not in tmux or not pane:
            return
        f = record_root() / os.path.basename(tmux.split(",")[0]) / f"{pane}.json"
        if kind == "idle":
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(json.dumps({"ts": time.time()}))
        else:
            f.unlink(missing_ok=True)
    except Exception:  # noqa: BLE001 -- a hook must never fail the agent
        return


def tmux(sock_path, *args):
    return subprocess.run(
        ["tmux", "-S", str(sock_path), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def gather(sdir, rroot):
    sockets = [p.name for p in sdir.glob("claude-swarm-*") if SOCKET_RE.match(p.name)]
    alive = {}
    for s in sockets:
        pid = int(SOCKET_RE.match(s).group(1))
        alive[pid] = Path(f"/proc/{pid}").exists()
    panes = {}
    for s in sockets:
        r = tmux(sdir / s, "list-panes", "-a", "-F", "#{pane_id}")
        panes[s] = r.stdout.split() if r.returncode == 0 else None
    records = {}
    for s in sockets:
        for f in (rroot / s).glob("*.json") if (rroot / s).is_dir() else []:
            try:
                records.setdefault(s, {})[f.stem] = float(
                    json.loads(f.read_text())["ts"]
                )
            except (OSError, ValueError, KeyError, TypeError):
                continue
    return sockets, alive, panes, records


def reap(dry_run, idle_minutes):
    sdir, rroot = socket_dir(), record_root()
    sockets, alive, panes, records = gather(sdir, rroot)
    actions = decide(sockets, alive, panes, records, time.time(), idle_minutes * 60)
    log(
        f"{len(sockets)} swarm socket(s), {len(actions)} action(s){' (dry run)' if dry_run else ''}"
    )
    for action, sock, pane, reason in actions:
        target = f"{sock} {pane}" if pane else sock
        if dry_run:
            log(f"would {action} {target} ({reason})")
            continue
        log(f"{action} {target} ({reason})")
        if action == "kill-pane":
            tmux(sdir / sock, "kill-pane", "-t", pane)
            (rroot / sock / f"{pane}.json").unlink(missing_ok=True)
        else:
            tmux(sdir / sock, "kill-server")
            (sdir / sock).unlink(missing_ok=True)
            shutil.rmtree(rroot / sock, ignore_errors=True)


def main(argv=None):
    ap = argparse.ArgumentParser(prog="claude-swarm-reaper")
    sub = ap.add_subparsers(dest="cmd", required=True)
    h = sub.add_parser("hook")
    h.add_argument("kind", choices=["idle", "active"])
    r = sub.add_parser("reap")
    r.add_argument("--dry-run", action="store_true")
    r.add_argument("--idle-minutes", type=float, default=10)
    try:
        a = ap.parse_args(argv)
    except SystemExit as e:
        # the hook must exit 0 even on a bad command line
        if argv and argv[0] == "hook":
            return 0
        return e.code
    if a.cmd == "hook":
        hook(a.kind)
        return 0
    reap(a.dry_run, a.idle_minutes)
    return 0


if __name__ == "__main__":
    sys.exit(main())
