#!/usr/bin/env python3
"""Conservative decision helpers for the guarded NixOS upgrade timer."""

import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from datetime import datetime
import urllib.request


STATE = Path("/var/lib/guarded-upgrade")
PROFILE = Path("/nix/var/nix/profiles/system")
REPO = "github:olafkfreund/nixos_config"
EXPECTED_RUNNERS = {
    "p620-nixarchy",
    "p620-nixarchy-2",
    "p620-nixarchy-3",
    "p620-nixarchy-4",
}


def promotion_safe(
    edge, candidate, artifact, conclusion, branch, attempt, artifact_attempt
):
    return bool(
        edge
        and edge == candidate == artifact
        and conclusion == "success"
        and branch == "main"
        and attempt == artifact_attempt
    )


def runners_safe(runners, expected):
    return (
        isinstance(runners, list)
        and {r.get("name") for r in runners} == expected
        and all(r.get("status") == "online" and r.get("busy") is False for r in runners)
    )


def idle_safe(session, reported_session, status, reported_at, now):
    return bool(
        session
        and session == reported_session
        and status == "idle"
        and 0 <= now - reported_at <= 120
    )


def ac_safe(value):
    return value == "1"


def should_start(locked, paused):
    return not locked and not paused


def failed_units_regressed(before, after):
    return bool(after - before)


DEPLOY_COMMANDS = ("nixos-rebuild", "switch-to-configuration", "nh os ")


def deploy_conflict(cmdlines, own_pids):
    """A manual deploy is running if any other process runs a switch command."""
    return any(
        pid not in own_pids and any(c in cmd for c in DEPLOY_COMMANDS)
        for pid, cmd in cmdlines
    )


def session_regressed(before, after):
    """A Hyprland session that was up before the switch must still be up after it."""
    return bool(before) and not after


def rollback_target(closure, generation):
    if not re.fullmatch(
        r"/nix/store/[a-z0-9]{32}-[^/]+", str(closure)
    ) or not isinstance(generation, int):
        raise ValueError("invalid recorded rollback target")
    return str(closure), generation


def run(*args, check=True):
    result = subprocess.run(args, text=True, capture_output=True)
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} failed: {result.stderr.strip()[:300]}")
    return result.stdout.strip()


def log(message):
    print(message, flush=True)


def save(name, value):
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = STATE / (name + ".tmp")
    tmp.write_text(json.dumps(value) + "\n")
    os.replace(tmp, STATE / name)


def read(name):
    path = STATE / name
    return json.loads(path.read_text()) if path.exists() else None


def github(path, method="GET", body=None):
    token = Path(os.environ["GITHUB_TOKEN_FILE"]).read_text().strip()
    repo = "nixos_config" if path.startswith("/issues") else "nixarchy"
    request = urllib.request.Request(
        f"https://api.github.com/repos/olafkfreund/{repo}" + path,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={
            "Authorization": "Bearer " + token,
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def runner_gate():
    runners = github("/actions/runners?per_page=100")
    ours = [
        r for r in runners["runners"] if r.get("name", "").startswith("p620-nixarchy")
    ]
    if not runners_safe(ours, EXPECTED_RUNNERS):
        raise RuntimeError("runners busy, missing or offline")
    for workflow, job in (
        ("install-check.yml", "install"),
        ("omarchy-edge.yml", "verify"),
    ):
        runs = github(
            f"/actions/workflows/{workflow}/runs?status=in_progress&per_page=100"
        )
        for item in runs["workflow_runs"]:
            jobs = github(f"/actions/runs/{item['id']}/jobs?per_page=100")
            if any(
                j.get("name") == job and j.get("status") in ("queued", "in_progress")
                for j in jobs["jobs"]
            ):
                raise RuntimeError(f"{workflow} {job} is running")
    if Path("/run/lock/nixarchy-vm-maintenance.lock").exists():
        raise RuntimeError("manual VM maintenance lock exists")


def failed_units():
    return {
        line.split()[0]
        for line in run(
            "systemctl",
            "list-units",
            "--state=failed",
            "--no-legend",
            "--plain",
            "--no-pager",
        ).splitlines()
        if line.split()
    }


def active_generation():
    target = os.readlink(PROFILE)
    match = re.search(r"system-(\d+)-link$", target)
    if not match:
        raise RuntimeError("cannot identify active generation")
    return int(match.group(1))


def current_closure():
    return str(Path("/run/current-system").resolve())


def process_cmdlines():
    lines = []
    for proc in Path("/proc").glob("[0-9]*"):
        try:
            cmd = (
                (proc / "cmdline")
                .read_bytes()
                .replace(b"\0", b" ")
                .decode(errors="replace")
            )
        except OSError:
            continue
        lines.append((int(proc.name), cmd))
    return lines


def own_pids():
    pids, pid = set(), os.getpid()
    while pid > 1:
        pids.add(pid)
        try:
            pid = int((Path("/proc") / str(pid) / "stat").read_text().split()[3])
        except (OSError, ValueError, IndexError):
            break
    return pids


def hyprland_running():
    return bool(run("pgrep", "-x", "Hyprland", check=False))


def ac_power():
    values = [
        p.read_text().strip()
        for p in Path("/sys/class/power_supply").glob("*/online")
        if p.parent.joinpath("type").read_text().strip() in ("Mains", "USB")
    ]
    return "1" if "1" in values else "0" if values else None


def gate(host):
    if (STATE / "pause").exists():
        raise RuntimeError("automatic activation paused")
    if deploy_conflict(process_cmdlines(), own_pids()):
        raise RuntimeError("a manual deploy is running")
    if host == "razer" and not ac_safe(ac_power()):
        raise RuntimeError("external power unavailable")
    if host == "p620":
        runner_gate()
        now = datetime.now()
        if now.hour != 4:
            raise RuntimeError("outside 04:00–05:00 activation window")
        signal = read("idle")
        sessions = run("loginctl", "list-sessions", "--no-legend")
        if sessions:
            if not signal or not idle_safe(
                signal.get("session"),
                signal.get("reported_session"),
                signal.get("status"),
                signal.get("at", 0),
                time.time(),
            ):
                raise RuntimeError("desktop idle status unavailable")
    return True


def bus_announce(host, sha):
    from agent_bus_mcp import post, read_new

    messages = read_new("#agents:freundcloud.org.uk")
    if messages.startswith("["):
        for item in json.loads(messages):
            if time.time() * 1000 - item.get("at", 0) < 30 * 60 * 1000 and re.search(
                r"\b(starting|about to|in flight|mid-flight|running a build|running a VM)\b",
                item.get("text", ""),
                re.I,
            ):
                raise RuntimeError("agent bus reports work in flight")
    post(
        "#agents:freundcloud.org.uk",
        f"Guarded upgrade: {host} candidate {sha}, activation and checks may take 20 minutes",
    )
    return post


def resolve_main():
    line = run(
        "git",
        "ls-remote",
        "https://github.com/olafkfreund/nixos_config.git",
        "refs/heads/main",
    )
    sha = line.split()[0] if line else ""
    if not re.fullmatch("[0-9a-f]{40}", sha):
        raise RuntimeError("cannot resolve main")
    return sha


def build_candidate(sha, host):
    link = STATE / ("stage-" + host)
    ref = f"{REPO}/{sha}#nixosConfigurations.{host}.config.system.build.toplevel"
    run("nix", "build", "--no-update-lock-file", "--out-link", str(link), ref)
    return str(link.resolve())


def verify_local(host, old_failed):
    if failed_units_regressed(old_failed, failed_units()):
        raise RuntimeError("new failed systemd units")
    hm = run(
        "systemctl",
        "show",
        "home-manager-olafkfreund.service",
        "-p",
        "Result",
        "-p",
        "ExecMainStatus",
    )
    if "Result=success" not in hm or "ExecMainStatus=0" not in hm:
        raise RuntimeError("Home Manager activation failed")
    if host == "p620":
        runner_gate()
        for suffix in ("", "-2", "-3", "-4"):
            if (
                run(
                    "systemctl",
                    "is-active",
                    f"github-runner-nixarchy{suffix}.service",
                    check=False,
                )
                != "active"
            ):
                raise RuntimeError("runner service unavailable")


def rollback(record, why):
    old, generation = rollback_target(record["old"], record["generation"])
    run("nix-env", "-p", str(PROFILE), "--switch-generation", str(generation))
    run(str(Path(old) / "bin/switch-to-configuration"), "switch", check=False)
    if current_closure() != old or str(PROFILE.resolve()) != old:
        raise RuntimeError("rollback failed to restore running and boot default")
    (STATE / "pause").write_text(record["sha"] + "\n")
    save("last-failure", {"sha": record["sha"], "reason": why, "rollback": "restored"})
    try:
        title = f"guarded upgrade failed on {os.uname().nodename}: {record['sha']}"
        issues = github("/issues?state=all&per_page=100")
        match = next((issue for issue in issues if issue.get("title") == title), None)
        body = {
            "title": title,
            "body": f"Failed checks: {why}\nRollback: restored recorded generation {generation}.\n",
        }
        if match:
            github(f"/issues/{match['number']}", "PATCH", body)
        else:
            github("/issues", "POST", body)
    except Exception as error:
        log(f"failure issue unavailable: {error}")
    (STATE / "transaction").unlink(missing_ok=True)


def activate(host, sha, candidate):
    old = current_closure()
    if str(PROFILE.resolve()) != old:
        raise RuntimeError("running and boot default generations differ")
    record = {
        "sha": sha,
        "candidate": candidate,
        "old": old,
        "generation": active_generation(),
        "failed": sorted(failed_units()),
        "session": hyprland_running(),
    }
    save("transaction", record)
    try:
        run("nix-env", "-p", str(PROFILE), "--set", candidate)
        run(str(Path(candidate) / "bin/switch-to-configuration"), "switch", check=False)
        time.sleep(30)
        if current_closure() != candidate or str(PROFILE.resolve()) != candidate:
            raise RuntimeError("activation did not select candidate")
        verify_local(host, set(record["failed"]))
        if session_regressed(record["session"], hyprland_running()):
            raise RuntimeError("the Hyprland session did not survive the switch")
    except Exception as error:
        rollback(record, str(error))
        raise
    (STATE / "transaction").unlink(missing_ok=True)
    save("verified", {"sha": sha, "candidate": candidate})


def may_activate(auto_activate):
    # Every host's switch is gated on its own flag; razer's path once ignored it.
    return auto_activate is True


def main(host, auto_activate):
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (STATE / "lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            log("deferred: another deployment is running")
            return 0
        transaction = read("transaction")
        if transaction:
            rollback(transaction, "interrupted activation")
            return 1
        if not should_start(False, (STATE / "pause").exists()):
            log("deferred: pause flag")
            return 0
        sha = resolve_main()
        if host == "p620":
            baseline = read("baseline")
            if not baseline or baseline.get("sha") != sha:
                baseline = {"sha": sha, "failed": sorted(failed_units())}
                save("baseline", baseline)
            candidate = build_candidate(sha, "p620")
            build_candidate(sha, "razer")
            if resolve_main() != sha:
                raise RuntimeError("main advanced during staging")
            if current_closure() == candidate and str(PROFILE.resolve()) == candidate:
                verify_local(host, set(baseline["failed"]))
                save("verified", {"sha": sha, "candidate": candidate})
                log("verified manually activated p620 canary")
                return 0
            if not auto_activate:
                log("staged: p620 unattended activation is disabled")
                return 0
            gate(host)
            raise RuntimeError("runner listener drain acknowledgement is not available")
        if not may_activate(auto_activate):
            log(f"staged nothing: {host} unattended activation is disabled")
            return 0
        gate(host)
        expected = run(
            "nix",
            "eval",
            "--raw",
            f"{REPO}/{sha}#nixosConfigurations.razer.config.system.build.toplevel.outPath",
        )
        candidate = run(
            "ssh", "p620", "readlink", "-f", "/var/lib/guarded-upgrade/stage-razer"
        )
        if candidate != expected:
            raise RuntimeError("p620 staged a different razer closure")
        run("nix", "copy", "--from", "ssh://p620", candidate)
        link = STATE / "stage-razer"
        link.unlink(missing_ok=True)
        link.symlink_to(candidate)
        if resolve_main() != sha:
            raise RuntimeError("main advanced during staging")
        canary = run("ssh", "p620", "cat", "/var/lib/guarded-upgrade/verified")
        if json.loads(canary).get("sha") != sha:
            raise RuntimeError("p620 canary has not verified this SHA")
        gate(host)
        post = bus_announce(host, sha)
        gate(host)
        activate(host, sha, candidate)
        post("#agents:freundcloud.org.uk", f"Guarded upgrade: {host} {sha} verified")
        return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1], sys.argv[2] == "true"))
    except Exception as error:
        log(f"deferred: {error}")
        sys.exit(0)
