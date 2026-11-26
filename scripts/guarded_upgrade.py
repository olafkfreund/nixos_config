#!/usr/bin/env python3
"""Conservative decision helpers for the guarded NixOS upgrade timer."""

import contextlib
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


DEPLOY_PROGRAMS = {
    "nixos-rebuild",
    "nixos-rebuild-ng",
    "switch-to-configuration",
    "switch-to-configuration-ng",
    "nh",
}
INTERPRETERS = ("python", "bash", "sh", "perl", "env")


def program_name(path):
    """nixpkgs wraps programs as .<name>-wrapped; that is the same program."""
    name = os.path.basename(path)
    if name.startswith(".") and name.endswith("-wrapped"):
        name = name[1 : -len("-wrapped")]
    return name


def deploy_conflict(cmdlines, own_pids):
    """Another process is running a switch program.

    Matched on the program's own name (argv[0], or the script an interpreter runs,
    past its flags), never on other arguments, so `man nixos-rebuild` or an editor
    on a note does not block. A backstop: the deploy lock is what excludes a deploy
    started on another machine.
    """
    for pid, argv in cmdlines:
        if pid in own_pids or not argv:
            continue
        names = {program_name(argv[0])}
        if program_name(argv[0]).startswith(INTERPRETERS):
            script = next((a for a in argv[1:] if not a.startswith("-")), None)
            if script:
                names.add(program_name(script))
        if names & DEPLOY_PROGRAMS:
            return True
    return False


def user_sessions(props_by_id):
    """logind ids of active or online sessions that belong to a person.

    Class=user leaves out the display manager's greeter, which is its own Wayland
    session whenever nobody is logged in; any Type counts, so an SSH or console
    login blocks a switch just as a desktop does.
    """
    return {
        sid
        for sid, props in props_by_id.items()
        if props.get("Class") == "user" and props.get("State") in ("active", "online")
    }


def session_regressed(before, after):
    """Every graphical session open before the switch must still be open after it.

    Sessions are logind ids, so a session that crashed and was replaced by a new
    login counts as lost, which a "Hyprland is running" test could not tell.
    """
    return bool(set(before) - set(after))


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
            raw = (proc / "cmdline").read_bytes()
        except OSError:
            continue
        argv = [a.decode(errors="replace") for a in raw.split(b"\0") if a]
        lines.append((int(proc.name), argv))
    return lines


def own_pids():
    pids, pid = set(), os.getpid()
    while pid > 1:
        pids.add(pid)
        try:
            # comm can hold spaces and parentheses; the fields after the last ")" cannot.
            stat = (Path("/proc") / str(pid) / "stat").read_text()
            pid = int(stat.rpartition(")")[2].split()[1])
        except (OSError, ValueError, IndexError):
            break
    return pids


def graphical_sessions():
    """Ids of people's open sessions, from logind (the compositor's own process
    name is .Hyprland-wrapped on NixOS, so a process-name test does not see it)."""
    props_by_id = {}
    for line in run("loginctl", "list-sessions", "--no-legend").splitlines():
        sid = line.split()[0] if line.split() else ""
        if not sid:
            continue
        # A session can close between the listing and this read; that is not a failure.
        shown = subprocess.run(
            [
                "loginctl",
                "show-session",
                sid,
                "-p",
                "Class",
                "-p",
                "State",
                "-p",
                "Type",
            ],
            text=True,
            capture_output=True,
        )
        if shown.returncode:
            continue
        props_by_id[sid] = dict(
            line.split("=", 1) for line in shown.stdout.splitlines() if "=" in line
        )
    return user_sessions(props_by_id)


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
    # Both hosts: a window, and either nobody logged in or a fresh idle report.
    # Nothing writes the idle report yet, so a host with an open session waits.
    if datetime.now().hour != 4:
        raise RuntimeError("outside 04:00–05:00 activation window")
    live = graphical_sessions()
    if live:
        signal = read("idle") or {}
        # The report must be about a session that is open now, and every open
        # session must be the one it vouches for.
        if live != {signal.get("session")} or not idle_safe(
            signal.get("session"),
            signal.get("reported_session"),
            signal.get("status"),
            signal.get("at", 0),
            time.time(),
        ):
            raise RuntimeError(
                "a session is open and no fresh idle report says it is idle"
            )
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
        "-p",
        "ActiveState",
    )
    # A oneshot still running reports the last run's Result; it must have finished.
    if "ActiveState=activating" in hm or "ActiveState=deactivating" in hm:
        raise RuntimeError("Home Manager activation has not finished")
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
    switched = subprocess.run(
        [str(Path(old) / "bin/switch-to-configuration"), "switch"],
        text=True,
        capture_output=True,
    )
    # Raising keeps the transaction file, so the next run retries the rollback
    # under the lock, and __main__ exits non-zero so the unit shows as failed.
    if switched.returncode:
        raise RuntimeError(
            f"rollback switch exited {switched.returncode}: {switched.stderr.strip()[:300]}"
        )
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
        "sessions": sorted(graphical_sessions()),
    }
    # A GC root for the rollback target, so pruning generations mid-transaction
    # cannot delete the system this would roll back to.
    run("nix-store", "--realise", old, "--add-root", str(STATE / "rollback-root"))
    save("transaction", record)
    try:
        run("nix-env", "-p", str(PROFILE), "--set", candidate)
        switched = subprocess.run(
            [str(Path(candidate) / "bin/switch-to-configuration"), "switch"],
            text=True,
            capture_output=True,
        )
        if switched.returncode:
            raise RuntimeError(
                f"switch-to-configuration exited {switched.returncode}: "
                f"{switched.stderr.strip()[:300]}"
            )
        time.sleep(30)
        if current_closure() != candidate or str(PROFILE.resolve()) != candidate:
            raise RuntimeError("activation did not select candidate")
        verify_local(host, set(record["failed"]))
        if session_regressed(record["sessions"], graphical_sessions()):
            raise RuntimeError("a session open before the switch is gone")
    except Exception as error:
        rollback(record, str(error))
        raise RolledBack(str(error)) from error
    (STATE / "transaction").unlink(missing_ok=True)
    (STATE / "rollback-root").unlink(missing_ok=True)
    save("verified", {"sha": sha, "candidate": candidate})


class RolledBack(RuntimeError):
    """Activation failed and the old system was restored: a failure, not a deferral."""


STAGE_HOST = "guarded-stage@p620"


def stage_ssh(command):
    """One of the forced command's three allowed operations on p620, with the
    agenix key, so razer's root needs no general login there."""
    return run(
        "ssh",
        "-i",
        os.environ["STAGE_KEY_FILE"],
        "-o",
        "IdentitiesOnly=yes",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=10",
        STAGE_HOST,
        command,
    )


def may_activate(auto_activate):
    # Every host's switch is gated on its own flag; razer's path once ignored it.
    return auto_activate is True


DEPLOY_LOCK = Path("/run/lock/nixos-deploy.lock")


@contextlib.contextmanager
def deploy_lock():
    """The lock scripts/deploy-hold.sh takes for a manual deploy, on this host.

    Held from the last gate through verify or rollback, and around reconciling an
    interrupted transaction, so a manual deploy and this can never switch at once.
    """
    with DEPLOY_LOCK.open("a") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("the deploy lock is held: a manual deploy is running")
        yield


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
            with deploy_lock():
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
            # Staging builds two whole systems; not while CI's VM jobs share the box.
            runner_gate()
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
        candidate = stage_ssh("readlink -f /var/lib/guarded-upgrade/stage-razer")
        if candidate != expected:
            raise RuntimeError("p620 staged a different razer closure")
        key = os.environ["STAGE_KEY_FILE"]
        run("nix", "copy", "--from", f"ssh://{STAGE_HOST}?ssh-key={key}", candidate)
        link = STATE / "stage-razer"
        link.unlink(missing_ok=True)
        link.symlink_to(candidate)
        if resolve_main() != sha:
            raise RuntimeError("main advanced during staging")
        canary = stage_ssh("cat /var/lib/guarded-upgrade/verified")
        if json.loads(canary).get("sha") != sha:
            raise RuntimeError("p620 canary has not verified this SHA")
        gate(host)
        with deploy_lock():
            gate(host)
            # Announced only once nothing else can stop the switch.
            post = bus_announce(host, sha)
            activate(host, sha, candidate)
        post("#agents:freundcloud.org.uk", f"Guarded upgrade: {host} {sha} verified")
        return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1], sys.argv[2] == "true"))
    except Exception as error:
        # A transaction left open means a switch or rollback did not finish: the
        # host may be between generations, so the unit must show as failed.
        if (STATE / "transaction").exists():
            log(f"failed with a transaction open: {error}")
            sys.exit(1)
        if isinstance(error, RolledBack):
            log(f"failed and rolled back: {error}")
            sys.exit(1)
        log(f"deferred: {error}")
        sys.exit(0)
