"""Reap Claude Code swarm tmux servers that outlived their lead or went idle.

Only sockets named claude-swarm-<pid> in the user's tmux directory are touched,
plus herdr panes listed in herdr-claude-teams' .owned files.
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
import socket
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


IDLE_STATES = ("idle", "done")


class HerdrError(Exception):
    pass


def herdr_call(sock_path, method, params=None):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5)
    try:
        s.connect(sock_path)
        req = {"id": "reaper", "method": method, "params": params or {}}
        s.sendall((json.dumps(req) + "\n").encode())
        buf = b""
        while not buf.endswith(b"\n"):
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk
    finally:
        s.close()
    resp = json.loads(buf.decode())
    if resp.get("error"):
        raise HerdrError(resp["error"].get("code", "error"))
    return resp.get("result", {})


def owned_root():
    return record_root().parent / "herdr-claude-teams"


def read_owned():
    """Return [(file, socket, pane_id, terminal_id)] from every .owned file."""
    rows = []
    for f in sorted(owned_root().glob("*.owned")):
        with contextlib.suppress(OSError):
            for line in f.read_text().splitlines():
                parts = line.split("\t")
                if len(parts) == 3 and parts[2]:
                    rows.append((f, *parts))
    return rows


def drop_owned(file, sock, term):
    with contextlib.suppress(OSError):
        keep = [
            line
            for line in file.read_text().splitlines()
            if line.split("\t")[::2] != [sock, term]
        ]
        file.write_text("".join(line + "\n" for line in keep))


def decide_herdr(owned, agents, clocks, now, idle_seconds):
    """Return (closes, new_clocks); closes is [(socket, terminal_id)].

    owned: [(socket, terminal_id)]; agents: {socket: {terminal_id: status}}, a
    socket missing there could not be queried and keeps its clocks;
    clocks: {"socket<TAB>terminal_id": first-seen-idle ts}.
    """
    closes, new = [], {}
    for sock, term in owned:
        key = f"{sock}\t{term}"
        if sock not in agents:
            if key in clocks:
                new[key] = clocks[key]
            continue
        if agents[sock].get(term) not in IDLE_STATES:
            continue
        ts = clocks.get(key, now)
        if now - ts >= idle_seconds:
            closes.append((sock, term))
        else:
            new[key] = ts
    return closes, new


def reap_herdr(dry_run, idle_seconds):
    rows = read_owned()
    state = record_root() / "herdr-idle.json"
    try:
        clocks = {k: float(v) for k, v in json.loads(state.read_text()).items()}
    except (OSError, ValueError, AttributeError):
        clocks = {}
    agents = {}
    for sock in sorted({r[1] for r in rows}):
        if not os.path.exists(sock):
            for f, s, _pane, term in rows:
                if s == sock and not dry_run:
                    drop_owned(f, s, term)
            continue
        try:
            listed = herdr_call(sock, "agent.list")["agents"]
            agents[sock] = {a["terminal_id"]: a.get("agent_status") for a in listed}
        except (OSError, ValueError, KeyError, HerdrError) as e:
            log(f"herdr {sock}: agent.list failed ({e})")
    closes, new = decide_herdr(
        [(r[1], r[3]) for r in rows], agents, clocks, time.time(), idle_seconds
    )
    for sock, term in closes:
        if dry_run:
            log(f"would close herdr pane {term} on {sock} (idle past window)")
            continue
        try:
            panes = herdr_call(sock, "pane.list")["panes"]
            pane = next(
                (p["pane_id"] for p in panes if p.get("terminal_id") == term), None
            )
            if pane:
                herdr_call(sock, "pane.close", {"pane_id": pane})
        except HerdrError as e:
            if str(e) != "pane_not_found":
                log(f"herdr close {term} failed ({e})")
                new[f"{sock}\t{term}"] = clocks.get(f"{sock}\t{term}", time.time())
                continue
        except (OSError, ValueError, KeyError) as e:
            log(f"herdr close {term} failed ({e})")
            new[f"{sock}\t{term}"] = clocks.get(f"{sock}\t{term}", time.time())
            continue
        log(f"closed herdr pane {term} on {sock} (idle past window)")
        for f, s, _pane, t in rows:
            if (s, t) == (sock, term):
                drop_owned(f, s, t)
    if not dry_run:
        with contextlib.suppress(OSError):
            state.parent.mkdir(parents=True, exist_ok=True)
            state.write_text(json.dumps(new))


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
    reap_herdr(dry_run, idle_minutes * 60)


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
