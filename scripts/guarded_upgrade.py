#!/usr/bin/env python3
"""Conservative decision helpers for the guarded NixOS upgrade timer."""

import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time
import uuid
from datetime import datetime
import urllib.request


STATE = Path("/var/lib/guarded-upgrade")
PROFILE = Path("/nix/var/nix/profiles/system")

# The GUARDED_* variables exist for the disposable-VM drain test (nixarchy#1967);
# the unit sets none of them.
env = os.environ.get
# A flake ref that accepts "/<commit>", and the git URL of the same repository.
REPO = env("GUARDED_REPO", "github:olafkfreund/nixos_config")
GIT_URL = env("GUARDED_GIT_URL", "https://github.com/olafkfreund/nixos_config.git")
RUNNER_REPO = env("GUARDED_RUNNER_REPO", "olafkfreund/nixarchy")
ISSUE_REPO = env("GUARDED_ISSUE_REPO", "olafkfreund/nixos_config")
# The unit and state directory are github-runner[-/]<RUNNER_UNIT><suffix>;
# RUNNER_NAME<suffix> is the name GitHub knows.
RUNNER_UNIT = env("GUARDED_RUNNER_UNIT", "nixarchy")
RUNNER_NAME = env("GUARDED_RUNNER_NAME", "p620-nixarchy")
SUFFIXES = ("", "-2", "-3", "-4")
EXPECTED_RUNNERS = {RUNNER_NAME + suffix for suffix in SUFFIXES}
# "workflow:job" pairs, comma separated.
CI_WORKFLOWS = tuple(
    tuple(item.split(":", 1))
    for item in env(
        "GUARDED_CI_WORKFLOWS", "install-check.yml:install,omarchy-edge.yml:verify"
    ).split(",")
    if item
)
# Local hours, "start-end", end excluded.
WINDOW = env("GUARDED_WINDOW", "4-5")
BUS_ROOM = env("GUARDED_BUS_ROOM", "#agents:freundcloud.org.uk")

RUNNER_STATE = Path("/var/lib/github-runner")
CGROUP_ROOT = Path("/sys/fs/cgroup")
# Overridable only so the disposable drain test (scripts/runner-drain-test) need not wait 30 min.
DRAIN_TIMEOUT = int(env("GUARDED_DRAIN_TIMEOUT", str(30 * 60)))
READY_TIMEOUT = 10 * 60
START_TIMEOUT = 5 * 60
SETTLE_TIMEOUT = 60
POLL = int(env("GUARDED_POLL", "15"))
EXITED = ("exited-idle", "exited-after-job")


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


IDLE_DIR = Path("/run/guarded-upgrade-idle")


def load_idle_report(path, session_uid):
    """The session's idle report, trusted only when its own user wrote it: the
    directory is sticky and writable by everyone (a session's hypridle writes it)."""
    try:
        if path.stat().st_uid != session_uid:
            return {}
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


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
    session whenever nobody is logged in. A console login or an interactive SSH
    login blocks a switch just as a desktop does. An SSH session with no TTY does
    not: it is a program (another host's herdr or editor server) holding a
    connection, not a person at a prompt (owner, 2026-11-27).
    """
    return {
        sid
        for sid, props in props_by_id.items()
        if props.get("Class") == "user"
        and props.get("State") in ("active", "online")
        and not (props.get("Service") == "sshd" and not props.get("TTY"))
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


def run(*args, check=True, timeout=None):
    try:
        result = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"{args[0]} timed out after {timeout}s")
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} failed: {result.stderr.strip()[:300]}")
    return result.stdout.strip()


def log(message):
    print(message, flush=True)


def save(name, value):
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = STATE / (name + ".tmp")
    with tmp.open("w") as out:
        out.write(json.dumps(value) + "\n")
        out.flush()
        os.fsync(out.fileno())
    os.replace(tmp, STATE / name)
    # The rename itself must survive a power cut.
    directory = os.open(STATE, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


def read(name):
    path = STATE / name
    return json.loads(path.read_text()) if path.exists() else None


def github(path, method="GET", body=None):
    token = Path(os.environ["GITHUB_TOKEN_FILE"]).read_text().strip()
    repo = ISSUE_REPO if path.startswith("/issues") else RUNNER_REPO
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repo}" + path,
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


def our_runners():
    runners = github("/actions/runners?per_page=100")
    return [r for r in runners["runners"] if r.get("name", "").startswith(RUNNER_NAME)]


def runner_gate():
    if not runners_safe(our_runners(), EXPECTED_RUNNERS):
        raise RuntimeError("runners busy, missing or offline")
    for workflow, job in CI_WORKFLOWS:
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
                "-p",
                "Service",
                "-p",
                "TTY",
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


def gate(host, runners=True):
    """runners=False is the recheck after a drain, when ours are offline on purpose."""
    if (STATE / "pause").exists():
        raise RuntimeError("automatic activation paused")
    if deploy_conflict(process_cmdlines(), own_pids()):
        raise RuntimeError("a manual deploy is running")
    if host == "razer" and not ac_safe(ac_power()):
        raise RuntimeError("external power unavailable")
    if host == "p620" and runners:
        runner_gate()
    # Both hosts: a window, and either nobody logged in or a fresh idle report,
    # which guarded-idle-report (modules/nix/guarded-upgrade.nix) writes per session.
    start, end = map(int, WINDOW.split("-"))
    if not start <= datetime.now().hour < end:
        raise RuntimeError(f"outside {start:02}:00–{end:02}:00 activation window")
    live = graphical_sessions()
    if live:
        signal = {}
        if len(live) == 1:
            (sid,) = live
            uid = run("loginctl", "show-session", sid, "-p", "User", "--value").strip()
            if uid.isdigit():
                signal = load_idle_report(IDLE_DIR / uid, int(uid))
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

    messages = read_new(BUS_ROOM)
    if messages.startswith("["):
        for item in json.loads(messages):
            if time.time() * 1000 - item.get("at", 0) < 30 * 60 * 1000 and re.search(
                r"\b(starting|about to|in flight|mid-flight|running a build|running a VM)\b",
                item.get("text", ""),
                re.I,
            ):
                raise RuntimeError("agent bus reports work in flight")
    took = (
        "drain, activation and checks may take an hour"
        if host == "p620"
        else "activation and checks may take 20 minutes"
    )
    post(BUS_ROOM, f"Guarded upgrade: {host} candidate {sha}, {took}")
    return post


def resolve_main():
    line = run("git", "ls-remote", GIT_URL, "refs/heads/main")
    sha = line.split()[0] if line else ""
    if not re.fullmatch("[0-9a-f]{40}", sha):
        raise RuntimeError("cannot resolve main")
    return sha


def build_candidate(sha, host):
    link = STATE / ("stage-" + host)
    ref = f"{REPO}/{sha}#nixosConfigurations.{host}.config.system.build.toplevel"
    run("nix", "build", "--no-update-lock-file", "--out-link", str(link), ref)
    return str(link.resolve())


def runner_unit(suffix):
    return f"github-runner-{RUNNER_UNIT}{suffix}.service"


def verify_local(host, old_failed, runners=True):
    """runners=False verifies the host while its runners are still closed."""
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
    if host == "p620" and runners:
        runner_gate()
        for suffix in SUFFIXES:
            if (
                run("systemctl", "is-active", runner_unit(suffix), check=False)
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


def end_transaction():
    (STATE / "transaction").unlink(missing_ok=True)
    # Only a GC root, replaced by the next switch: failing to drop it must not
    # turn a recorded verdict into an error.
    try:
        (STATE / "rollback-root").unlink(missing_ok=True)
    except OSError as error:
        log(f"rollback root left behind: {error}")


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
        # p620 only switches drained; the reopen checks its runners.
        verify_local(host, set(record["failed"]), runners=False)
        if session_regressed(record["sessions"], graphical_sessions()):
            raise RuntimeError("a session open before the switch is gone")
    except Exception as error:
        rollback(record, str(error))
        raise RolledBack(str(error)) from error
    # The verdict reaches the journal before the transaction goes, so a kill in
    # between cannot lose it. Only p620 has a drain journal.
    journal = read("drain")
    if journal:
        set_phase(journal, "settled-commit")
    end_transaction()
    # p620's canary is published only after its runners are back (reopen_and_clear).
    if host != "p620":
        save("verified", {"sha": sha, "candidate": candidate})


class RolledBack(RuntimeError):
    """Activation failed and the old system was restored: a failure, not a deferral."""


class ReopenFailed(RuntimeError):
    """The runners are not all seen back: the journal stays for the next run."""


# The runner drain (nixarchy#1967, spec/2026-11-27-1967-runner-drain.md). STATE/drain
# is the journal, STATE/runners-closed the marker each runner unit's condition reads.


@contextlib.contextmanager
def drain_dir(suffix, create=False):
    """A descriptor on a runner's drain directory.

    The runner's user, which runs CI jobs, owns this tree and root writes into it,
    so nothing here follows a symlink at or below drain/.
    """
    state = RUNNER_STATE / (RUNNER_UNIT + suffix)
    if create:
        (state / "drain").mkdir(mode=0o755, exist_ok=True)
    fd = os.open(state / "drain", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        if create:
            # The listener writes its acknowledgement here.
            owner = state.stat()
            os.fchown(fd, owner.st_uid, owner.st_gid)
            os.fchmod(fd, 0o755)
        yield fd
    finally:
        os.close(fd)


def write_request(suffix, request):
    with drain_dir(suffix, create=True) as fd:
        tmp = f".request.{uuid.uuid4().hex}"
        handle = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644, dir_fd=fd)
        with os.fdopen(handle, "w") as out:
            os.fchmod(handle, 0o644)
            out.write(json.dumps({"id": request}) + "\n")
        os.replace(tmp, "request", src_dir_fd=fd, dst_dir_fd=fd)


def remove_request(suffix):
    with contextlib.suppress(FileNotFoundError), drain_dir(suffix) as fd:
        os.unlink("request", dir_fd=fd)


def read_ack(suffix):
    """The listener's acknowledgement, or {} for anything missing or malformed."""
    try:
        with drain_dir(suffix) as fd:
            # O_NONBLOCK: a FIFO planted here must not hang root.
            flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
            handle = os.open("ack", flags, dir_fd=fd)
            try:
                if not stat.S_ISREG(os.fstat(handle).st_mode):
                    return {}
                ack = json.loads(os.read(handle, 4096))
            finally:
                os.close(handle)
    except (OSError, ValueError):
        return {}
    return ack if isinstance(ack, dict) else {}


def unit_props(suffix):
    shown = run(
        "systemctl",
        "show",
        runner_unit(suffix),
        "-p",
        "InvocationID",
        "-p",
        "ActiveState",
        "-p",
        "ControlGroup",
    )
    return dict(line.split("=", 1) for line in shown.splitlines() if "=" in line)


def cgroup_empty(group):
    if not group:
        return True
    try:
        events = (CGROUP_ROOT / group.lstrip("/") / "cgroup.events").read_text()
    except FileNotFoundError:
        return True
    return "populated 0" in events.splitlines()


def runner_drained(suffix, request, invocation):
    # The unit is read before the ack: the listener writes the ack, then exits.
    props = unit_props(suffix)
    ack = read_ack(suffix)
    return bool(
        invocation
        and ack.get("id") == request
        and ack.get("invocation") == invocation
        and ack.get("state") in EXITED
        and props.get("ActiveState") == "inactive"
        and cgroup_empty(props.get("ControlGroup"))
    )


def set_phase(journal, phase):
    journal = {**journal, "phase": phase}
    # The outcome outlives "reopen-failed", so a retried reopen can still publish.
    if phase.startswith("settled-"):
        journal["settled"] = phase
    save("drain", journal)
    return journal


def start_drain(sha, candidate):
    """Write the journal, before anything is closed."""
    journal = {
        "phase": "draining",
        "sha": sha,
        "candidate": candidate,
        "request": str(uuid.uuid4()),
        "deadline": time.time() + DRAIN_TIMEOUT,
        # What an acknowledgement must name, and the reopen must see replaced.
        "invocations": {s: unit_props(s).get("InvocationID", "") for s in SUFFIXES},
    }
    save("drain", journal)
    return journal


def close_and_wait(journal):
    # The canary must not outlive the drain.
    (STATE / "verified").unlink(missing_ok=True)
    (STATE / "runners-closed").touch(mode=0o644)
    for suffix in SUFFIXES:
        try:
            write_request(suffix, journal["request"])
        except OSError as error:
            raise RuntimeError(
                f"{runner_unit(suffix)}: cannot write the drain request: {error}"
            ) from error
        journal.setdefault("requested", []).append(suffix)
        save("drain", journal)
    while True:
        # A new invocation can never match the recorded one: defer now.
        restarted = [
            runner_unit(s)
            for s in SUFFIXES
            if unit_props(s).get("InvocationID", "")
            not in ("", journal["invocations"][s])
        ]
        if restarted:
            raise RuntimeError(f"restarted during the drain: {', '.join(restarted)}")
        waiting = [
            runner_unit(s)
            for s in SUFFIXES
            if not runner_drained(s, journal["request"], journal["invocations"][s])
        ]
        if not waiting:
            return
        if time.time() >= journal["deadline"]:
            raise RuntimeError(f"deadline passed waiting for {', '.join(waiting)}")
        time.sleep(POLL)


def start_units(suffixes):
    run("systemctl", "start", *map(runner_unit, suffixes), timeout=START_TIMEOUT)


def open_admission():
    """Remove every request, then the marker; returns the runners whose request stayed.

    One runner's unusable drain path must not keep the others closed.
    """
    stuck = []
    for suffix in SUFFIXES:
        try:
            remove_request(suffix)
        except OSError as error:
            stuck.append(suffix)
            log(f"drain: {runner_unit(suffix)}: cannot remove the request: {error}")
    (STATE / "runners-closed").unlink(missing_ok=True)
    return stuck


def may_hold_request(journal, suffix):
    """False for a drain path that is not a directory and never took our request."""
    if suffix in journal.get("requested", []):
        return True
    try:
        mode = os.lstat(RUNNER_STATE / (RUNNER_UNIT + suffix) / "drain").st_mode
    except OSError:
        return True
    return stat.S_ISDIR(mode)


def resumed(suffix, journal, props):
    """Up at the end of the settle window: active, and not itself draining this request."""
    invocation = props.get("InvocationID")
    if props.get("ActiveState") != "active" or not invocation:
        return False
    ack = read_ack(suffix)
    return not (
        ack.get("id") == journal.get("request")
        and ack.get("invocation") == invocation
        and ack.get("state") != "cancelled"
    )


def defer(journal, why):
    """Give up on a drain. No unit is stopped or restarted: a job may be running.

    A listener that already decided to exit still reads as active, and one that
    cancelled can still die restarting its session, so the runners are judged only
    at the end of the settle window.
    """
    journal = set_phase(journal, "cancelling")
    log(f"deferred: drain incomplete: {why}")
    stuck = [s for s in open_admission() if may_hold_request(journal, s)]
    until = time.time() + SETTLE_TIMEOUT
    while True:
        expired = time.time() >= until
        props = {s: unit_props(s) for s in SUFFIXES}
        stopped = [
            s for s in SUFFIXES if props[s].get("ActiveState") in ("inactive", "failed")
        ]
        if stopped:
            try:
                start_units(stopped)
            except RuntimeError as error:
                log(f"drain: {error}")
            props = {s: unit_props(s) for s in SUFFIXES}
        if expired:
            break
        time.sleep(POLL)
    waiting = [s for s in SUFFIXES if s in stuck or not resumed(s, journal, props[s])]
    if not waiting:
        (STATE / "drain").unlink(missing_ok=True)
        return
    units = [runner_unit(s) for s in waiting]
    save("drain", {**journal, "unresolved": units})
    raise ReopenFailed(
        f"drain not cancelled for {', '.join(units)}; the next run retries"
    )


def wait_ready(previous):
    """Wait for four new invocations that GitHub reports online. Busy is fine."""
    until = time.time() + READY_TIMEOUT
    while True:
        try:
            props = {s: unit_props(s) for s in SUFFIXES}
            online = {
                r.get("name") for r in our_runners() if r.get("status") == "online"
            }
            # A runner can exit while GitHub is being asked.
            after = {s: unit_props(s) for s in SUFFIXES}
            if online == EXPECTED_RUNNERS and all(
                p.get("ActiveState") == "active"
                and p.get("InvocationID")
                and p.get("InvocationID") != previous.get(s)
                and after[s].get("ActiveState") == "active"
                and after[s].get("InvocationID") == p.get("InvocationID")
                for s, p in props.items()
            ):
                return
            why = "not all new and online"
        # systemctl and GitHub failures (URLError is an OSError) are retried.
        except (RuntimeError, OSError, ValueError, KeyError) as error:
            why = str(error)
        if time.time() >= until:
            raise RuntimeError(why)
        time.sleep(POLL)


def reopen_and_clear(journal):
    """Open admission, see the runners back, publish a committed SHA, end the journal."""
    try:
        # A request left in place would make each new listener exit at once.
        stuck = [
            runner_unit(s) for s in open_admission() if may_hold_request(journal, s)
        ]
        journal = {**journal, "unresolved": stuck}
        start_units(SUFFIXES)
        if stuck:
            raise RuntimeError(f"drain request left for {', '.join(stuck)}")
        wait_ready(journal.get("invocations", {}))
    except Exception as error:
        set_phase(journal, "reopen-failed")
        raise ReopenFailed(f"reopen failed: {error}") from error
    candidate = journal.get("candidate")
    if journal.get("settled") == "settled-commit" and is_current(candidate):
        save("verified", {"sha": journal["sha"], "candidate": candidate})
    (STATE / "drain").unlink(missing_ok=True)


def drained_activate(sha, candidate):
    """p620's switch, under the deploy lock. False means deferred."""
    journal = start_drain(sha, candidate)
    try:
        close_and_wait(journal)
        # The drain takes minutes and an idle report is stale after two.
        gate("p620", runners=False)
        if resolve_main() != sha:
            raise RuntimeError("main advanced during the drain")
        journal = set_phase(journal, "switching")
        activate("p620", sha, candidate)
    except RolledBack:
        reopen_and_clear(set_phase(journal, "settled-rollback"))
        raise
    except Exception as error:
        # An open transaction is an unfinished switch or rollback: stay closed.
        if (STATE / "transaction").exists():
            raise
        defer(journal, str(error))
        return False
    reopen_and_clear(set_phase(journal, "settled-commit"))
    return True


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


def require_canary(sha):
    canary = stage_ssh("cat /var/lib/guarded-upgrade/verified")
    if json.loads(canary).get("sha") != sha:
        raise RuntimeError("p620 canary has not verified this SHA")


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


def is_current(candidate):
    return current_closure() == candidate and str(PROFILE.resolve()) == candidate


def valid_journal(journal):
    """Every field recovery reads has the type it expects; absent is allowed,
    because a failed orphan reopen records only a phase."""
    if not isinstance(journal, dict):
        return False
    settled = ("settled-commit", "settled-rollback")
    phase = journal.get("phase")
    if phase not in ("draining", "cancelling", "switching", "reopen-failed", *settled):
        return False
    if "settled" in journal and not (
        journal["settled"] in settled and phase in ("reopen-failed", *settled)
    ):
        return False
    if journal.get("settled") == "settled-commit" and not (
        "sha" in journal and "candidate" in journal
    ):
        return False
    if not all(
        isinstance(journal.get(key, ""), str) for key in ("sha", "candidate", "request")
    ):
        return False
    invocations = journal.get("invocations", {})
    requested = journal.get("requested", [])
    return (
        isinstance(invocations, dict)
        and all(isinstance(value, str) for value in invocations.values())
        and isinstance(requested, list)
        and all(isinstance(value, str) for value in requested)
    )


def recover(host, boot=False):
    """Finish what an interrupted run left behind.

    Returns this run's exit status, or None when there was nothing to recover.
    """
    unreadable = False
    try:
        journal = read("drain")
        # A file holding "null" is a bad journal, not a missing one.
        if (STATE / "drain").exists() and not valid_journal(journal):
            raise ValueError("not a drain journal")
    except ValueError as error:
        log(f"ERROR: unreadable drain journal, treated as an orphan: {error}")
        journal, unreadable = None, True
    # Never switch during boot. Closed runners are the safe state until the timer
    # run; a recorded commit needs only cleanup, so boot may finish that.
    committed = bool(journal) and journal.get("settled") == "settled-commit"
    if boot and (STATE / "transaction").exists() and not committed:
        log(
            "ERROR: unfinished transaction: the rollback is left for the next "
            "nixos-upgrade timer run; runners left as they are"
        )
        return 1
    transaction = read("transaction")
    orphan = unreadable or (not journal and (STATE / "runners-closed").exists())
    if not (journal or transaction or orphan):
        return None
    with deploy_lock():
        if journal and journal["phase"] in ("draining", "cancelling"):
            defer(journal, "recovering an interrupted drain")
            return 0
        if transaction and journal and journal.get("settled") == "settled-commit":
            # Verified before the interruption: only the cleanup was left.
            end_transaction()
            transaction = None
        if transaction:
            rollback(transaction, "interrupted activation")
            if journal:
                journal = set_phase(journal, "settled-rollback")
        if host == "p620":
            if orphan:
                log("ERROR: orphan drain: no usable journal; reopening")
            reopen_and_clear(journal or {"phase": "orphan"})
    return 1 if transaction else 0


def main(host, auto_activate, recover_only=False):
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (STATE / "lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            log("deferred: another deployment is running")
            return 0
        # Before the pause and runner gates: either would strand closed runners.
        recovered = recover(host, boot=recover_only)
        if recovered is not None:
            return recovered
        if recover_only:
            return 0
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
            if is_current(candidate):
                with deploy_lock():
                    if not is_current(candidate):
                        raise RuntimeError("generation changed before verification")
                    verify_local(host, set(baseline["failed"]))
                    save("verified", {"sha": sha, "candidate": candidate})
                log("verified manually activated p620 canary")
                return 0
            if not auto_activate:
                log("staged: p620 unattended activation is disabled")
                return 0
            gate(host)
            with deploy_lock():
                gate(host)
                post = bus_announce(host, sha)
                if not drained_activate(sha, candidate):
                    return 0
            post(BUS_ROOM, f"Guarded upgrade: {host} {sha} verified")
            return 0
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
        require_canary(sha)
        gate(host)
        with deploy_lock():
            gate(host)
            # Announced only once nothing on this host can stop the switch.
            post = bus_announce(host, sha)
            # p620 may have started a drain, and withdrawn its canary, meanwhile.
            require_canary(sha)
            activate(host, sha, candidate)
        post(BUS_ROOM, f"Guarded upgrade: {host} {sha} verified")
        return 0


def failure_status(error):
    """The unit's exit status for an error that escaped main()."""
    # A transaction, journal or marker left behind means a switch, rollback or
    # reopen did not finish, so the unit must show as failed.
    left = [
        n for n in ("transaction", "drain", "runners-closed") if (STATE / n).exists()
    ]
    if left:
        log(f"failed with {', '.join(left)} left open: {error}")
        return 1
    if isinstance(error, RolledBack):
        log(f"failed and rolled back: {error}")
        return 1
    log(f"deferred: {error}")
    return 0


def cli(host, mode):
    """mode is the unit's autoActivate ("true"/"false"), or "recover" at boot."""
    return main(host, mode == "true", recover_only=mode == "recover")


if __name__ == "__main__":
    try:
        sys.exit(cli(sys.argv[1], sys.argv[2]))
    except Exception as error:
        sys.exit(failure_status(error))
