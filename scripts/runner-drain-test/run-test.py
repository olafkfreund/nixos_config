#!/usr/bin/env python3
"""Disposable NixOS VM harness for github-runner drain (nixarchy#1967).

Builds and boots the isolated two-generation NixOS QEMU VM defined in vm.nix,
registers four patched runners under a unique label against a disposable GitHub
repository, executes scenarios (a) through (f) against the real
scripts/guarded_upgrade.py with environment overrides, and writes a structured
JSON recording of execution counters, invocation IDs, systemd condition skips,
running and boot generations, and canary contents.
"""

import argparse
import base64
import contextlib
import inspect
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
GUARDED_UPGRADE_SCRIPT = REPO_ROOT / "scripts" / "guarded_upgrade.py"
DEPLOY_HOLD_SCRIPT = REPO_ROOT / "scripts" / "deploy-hold.sh"
WORKFLOW_FILE = HERE / "workflow.yml"
VM_NIX_FILE = HERE / "vm.nix"

RUNNER_UNITS = (
    "github-runner-nixarchy.service",
    "github-runner-nixarchy-2.service",
    "github-runner-nixarchy-3.service",
    "github-runner-nixarchy-4.service",
)
RUNNER_DIRS = (
    "nixarchy",
    "nixarchy-2",
    "nixarchy-3",
    "nixarchy-4",
)
RUNNER_NAMES = (
    "p620-nixarchy",
    "p620-nixarchy-2",
    "p620-nixarchy-3",
    "p620-nixarchy-4",
)


def log(msg):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def normalize_repo(raw):
    """Normalize a repository reference into 'owner/name'."""
    value = raw.strip()
    for prefix in ("https://github.com/", "http://github.com/", "github:"):
        value = value.removeprefix(prefix)
    value = value.removesuffix(".git")
    value = value.strip("/")
    parts = value.split("/")
    if len(parts) != 2 or not parts[0] or not parts[1]:
        raise ValueError(f"expected repository in 'owner/name' form, got: {raw!r}")
    return f"{parts[0]}/{parts[1]}"


def resolve_repo_from_env(explicit=None):
    if explicit:
        return normalize_repo(explicit)
    for var in (
        "RUNNER_DRAIN_TEST_REPO",
        "DISPOSABLE_REPO",
        "DRAIN_TEST_REPO",
        "TEST_REPO",
        "GITHUB_REPOSITORY",
    ):
        val = os.environ.get(var, "").strip()
        if val:
            return normalize_repo(val)
    raise RuntimeError(
        "disposable repository not specified; pass --repo OWNER/REPO or set RUNNER_DRAIN_TEST_REPO"
    )


def resolve_token_from_env(token_file=None, allow_agenix=False):
    """Read the GitHub token from a file or environment variable without logging it."""
    candidates_files = []
    if token_file:
        candidates_files.append(token_file)
    for var in (
        "RUNNER_DRAIN_TEST_TOKEN_FILE",
        "DISPOSABLE_GITHUB_TOKEN_FILE",
        "DRAIN_TEST_TOKEN_FILE",
    ):
        val = os.environ.get(var, "").strip()
        if val:
            candidates_files.append(val)

    for path_str in candidates_files:
        path = Path(path_str)
        resolved = str(path.resolve()) if path.exists() else str(path)
        if not allow_agenix and (
            path_str.startswith("/run/agenix") or resolved.startswith("/run/agenix")
        ):
            raise RuntimeError(
                f"refusing to read decrypted agenix secret path: {path_str}"
            )
        token = path.read_text().strip()
        if not token:
            raise RuntimeError(f"token file is empty: {path_str}")
        return token

    # Only names that exist for this test: GH_TOKEN, GITHUB_TOKEN and
    # GITHUB_TOKEN_FILE usually hold the owner's real token, which must never
    # reach the disposable VM.
    for var in (
        "RUNNER_DRAIN_TEST_TOKEN",
        "DISPOSABLE_GITHUB_TOKEN",
        "DRAIN_TEST_TOKEN",
    ):
        val = os.environ.get(var, "").strip()
        if val:
            return val

    raise RuntimeError(
        "disposable GitHub token not found; set RUNNER_DRAIN_TEST_TOKEN or RUNNER_DRAIN_TEST_TOKEN_FILE"
    )


def discover_guarded_upgrade_env(
    repo,
    runner_name_prefix="p620-nixarchy",
    bus_room="#runner-drain-test:localhost",
    token_file="/run/runner-drain-test/github-token",
    drain_timeout=None,
    drain_poll=None,
):
    """The environment for guarded_upgrade.py: the GUARDED_* overrides it reads
    (scripts/guarded_upgrade.py, top of file), set for the disposable repository."""
    env = {
        "GITHUB_TOKEN_FILE": token_file,
        "GUARDED_REPO": f"github:{repo}",
        "GUARDED_GIT_URL": f"https://github.com/{repo}.git",
        "GUARDED_RUNNER_REPO": repo,
        "GUARDED_ISSUE_REPO": repo,
        # The module's unit attribute, so units are github-runner-nixarchy{,-2,...}.
        "GUARDED_RUNNER_UNIT": "nixarchy",
        "GUARDED_RUNNER_NAME": runner_name_prefix,
        # The scenarios run jobs on purpose; no CI workflow may block the gate.
        "GUARDED_CI_WORKFLOWS": "",
        "GUARDED_WINDOW": "0-24",
        "GUARDED_BUS_ROOM": bus_room,
    }
    if drain_timeout is not None:
        env["GUARDED_DRAIN_TIMEOUT"] = str(drain_timeout)
    if drain_poll is not None:
        env["GUARDED_POLL"] = str(drain_poll)
    return env


class RateLimited(Exception):
    def __init__(self, wait):
        super().__init__(f"rate limited for {wait:.0f}s")
        self.wait = wait


class GitHubClient:
    def __init__(self, repo, token):
        self.repo = repo
        self._token = token

    # The token shares the owner's 5000/hour REST budget with every other agent,
    # so calls are spaced and a rate-limit refusal waits for the reset.
    MIN_INTERVAL = 3.0
    _last_call = 0.0

    def request(self, path, method="GET", body=None, expected=(200, 201, 204)):
        for attempt in range(3):
            wait = GitHubClient._last_call + self.MIN_INTERVAL - time.time()
            if wait > 0:
                time.sleep(wait)
            GitHubClient._last_call = time.time()
            try:
                return self._request(path, method, body, expected)
            except RateLimited as limited:
                if attempt == 2:
                    raise RuntimeError(
                        f"GitHub {method} {path}: still rate limited"
                    ) from limited
                log(
                    f"GitHub rate limit reached; waiting {limited.wait:.0f}s for the reset"
                )
                time.sleep(limited.wait)
        raise AssertionError("unreachable")

    def _request(self, path, method="GET", body=None, expected=(200, 201, 204)):
        url = f"https://api.github.com/repos/{self.repo}{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={
                "Authorization": f"Bearer {self._token}",
                "Accept": "application/vnd.github+json",
                "Content-Type": "application/json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                status = resp.status
                raw = resp.read().decode()
                payload = json.loads(raw) if raw.strip() else None
                if status not in expected:
                    raise RuntimeError(f"GitHub {method} {path} returned {status}")
                return status, payload
        except urllib.error.HTTPError as err:
            if err.code in expected:
                raw = err.read().decode(errors="replace")
                return err.code, (json.loads(raw) if raw.strip() else None)
            detail = err.read().decode(errors="replace")[:300]
            if err.code in (403, 429) and (
                err.headers.get("X-RateLimit-Remaining") == "0"
                or "rate limit" in detail
            ):
                reset = int(err.headers.get("X-RateLimit-Reset") or 0)
                raise RateLimited(max(30.0, reset - time.time() + 5)) from err
            raise RuntimeError(
                f"GitHub {method} {path} failed with HTTP {err.code}: {detail}"
            ) from err

    def ensure_workflow_installed(
        self, workflow_path=".github/workflows/drain-test.yml"
    ):
        content_bytes = WORKFLOW_FILE.read_bytes()
        encoded = base64.b64encode(content_bytes).decode()
        status, existing = self.request(
            f"/contents/{workflow_path}", expected=(200, 404)
        )
        body = {
            "message": "ci: install runner-drain-test workflow (nixarchy#1967)",
            "content": encoded,
            "branch": "main",
        }
        if status == 200 and isinstance(existing, dict):
            remote_b64 = existing.get("content", "").replace("\n", "")
            if remote_b64 == encoded:
                return existing.get("commit", {}).get("sha")
            body["sha"] = existing["sha"]
        _, updated = self.request(
            f"/contents/{workflow_path}",
            method="PUT",
            body=body,
            expected=(200, 201),
        )
        deadline = time.time() + 30
        while time.time() < deadline:
            st, _ = self.request(
                "/actions/workflows/drain-test.yml", expected=(200, 404)
            )
            if st == 200:
                break
            time.sleep(2)
        return (updated or {}).get("commit", {}).get("sha")

    def list_runners(self):
        _, data = self.request("/actions/runners?per_page=100")
        return [
            r for r in (data or {}).get("runners", []) if r.get("name") in RUNNER_NAMES
        ]

    def dispatch_workflow(self, scenario, nonce, label, sleep_seconds):
        dispatched_at = time.time()
        self.request(
            "/actions/workflows/drain-test.yml/dispatches",
            method="POST",
            body={
                "ref": "main",
                "inputs": {
                    "scenario": str(scenario),
                    "nonce": str(nonce),
                    "runner_label": str(label),
                    "sleep_seconds": str(sleep_seconds),
                },
            },
            expected=(204,),
        )
        return dispatched_at

    def list_workflow_runs(self, created_after=None):
        _, data = self.request(
            "/actions/workflows/drain-test.yml/runs?per_page=30",
            expected=(200,),
        )
        runs = (data or {}).get("workflow_runs", [])
        if created_after is not None:
            filtered = []
            for r in runs:
                created_str = r.get("created_at") or ""
                try:
                    dt = datetime.fromisoformat(created_str)
                    if dt.timestamp() >= created_after - 5:
                        filtered.append(r)
                except ValueError:
                    filtered.append(r)
            return filtered
        return runs

    def list_run_jobs(self, run_id):
        _, data = self.request(
            f"/actions/runs/{run_id}/jobs?per_page=100",
            expected=(200,),
        )
        return (data or {}).get("jobs", [])


def parse_iso_ts(value):
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value).timestamp()
    except ValueError:
        return None


def read_drain_artifact(path, unreadable_value="ack unreadable"):
    """Read a drain request or ack JSON file, returning unreadable_value when the
    path exists but cannot be read as text (e.g. a directory at drain/ack)."""
    p = Path(path)
    if not p.exists():
        return None
    try:
        raw = p.read_text()
    except (OSError, UnicodeError):
        return unreadable_value
    try:
        return json.loads(raw)
    except ValueError:
        return {"raw": raw}


def extract_guest_transition_times(snapshot):
    """Extract guest-recorded transition timestamps (journal phase writes and
    runners-closed marker creation/removal) from a VM snapshot."""
    trans = (snapshot or {}).get("transitions")
    if not isinstance(trans, dict):
        trans = {}
    return {
        "draining_at": trans.get("phase:draining"),
        "boundary_released_at": trans.get("boundary_released"),
        "admission_closed_at": trans.get("runners_closed"),
        "switch_at": trans.get("phase:switching"),
        "settled_commit_at": trans.get("phase:settled-commit"),
        "settled_rollback_at": trans.get("phase:settled-rollback"),
        "cancelling_at": trans.get("phase:cancelling"),
        "reopened_at": trans.get("runners_reopened"),
        "drain_cleared_at": trans.get("drain_cleared"),
    }


def summarize_attempt_dir(cdir, scenario, nonce):
    """Aggregate independent per-attempt execution records for (scenario, nonce)."""
    cdir = Path(cdir)
    key = f"{scenario}-{nonce}"
    started_records = []
    completed_records = []
    in_progress_files = []

    for p in sorted(cdir.glob(f"{key}.attempt.*.started.json")):
        # An unreadable record is still an attempt: dropping it would hide a duplicate.
        try:
            started_records.append(json.loads(p.read_text()))
        except (OSError, ValueError):
            started_records.append({"file": p.name, "unreadable": True})
    for p in sorted(cdir.glob(f"{key}.attempt.*.completed.json")):
        # An unreadable record is still an attempt: dropping it would hide a duplicate.
        try:
            completed_records.append(json.loads(p.read_text()))
        except (OSError, ValueError):
            completed_records.append({"file": p.name, "unreadable": True})
    for p in sorted(cdir.glob(f"{key}.attempt.*.in_progress")):
        in_progress_files.append(p.name)

    events = sorted(
        [*started_records, *completed_records],
        key=lambda e: (e.get("ts", 0), 0 if e.get("event") == "started" else 1),
    )
    run_ids = sorted(
        {
            str(r.get("run_id"))
            for r in [*started_records, *completed_records]
            if r.get("run_id") and r.get("run_id") != "norun"
        }
    )
    return {
        "started": len(started_records),
        "completed": len(completed_records),
        "in_progress": bool(in_progress_files),
        "in_progress_files": in_progress_files,
        "started_attempts": started_records,
        "completed_attempts": completed_records,
        "run_ids": run_ids,
        "events": events,
    }


def record_job_transition(transitions, jobs, observed_at=None):
    """Append newly observed (job_id, status, conclusion) transitions with timestamps."""
    now = time.time() if observed_at is None else observed_at
    last_by_job = {}
    for entry in transitions:
        last_by_job[entry["job_id"]] = (entry["status"], entry.get("conclusion"))
    for j in jobs:
        jid = j.get("id")
        status = j.get("status")
        conclusion = j.get("conclusion")
        state_pair = (status, conclusion)
        if last_by_job.get(jid) != state_pair:
            transitions.append(
                {
                    "job_id": jid,
                    "run_id": j.get("run_id"),
                    "name": j.get("name"),
                    "status": status,
                    "conclusion": conclusion,
                    "runner_name": j.get("runner_name"),
                    "created_at": j.get("created_at"),
                    "started_at": j.get("started_at"),
                    "completed_at": j.get("completed_at"),
                    "observed_at": now,
                }
            )
            last_by_job[jid] = state_pair
    return transitions


def verify_queued_across_closed_window(
    transitions,
    runners_closed_at,
    runners_reopened_at,
    attempts=None,
):
    """Verify deterministically from GitHub timestamps that the job was created
    before admission closed, started at or after reopen, and ran exactly once."""
    if not transitions or runners_closed_at is None or runners_reopened_at is None:
        return False
    if attempts is not None and attempts != 1:
        return False
    all_completed = [t for t in transitions if t.get("status") == "completed"]
    completed_success = [
        t for t in all_completed if t.get("conclusion") == "success"
    ]
    distinct_job_ids = {
        t.get("job_id") for t in transitions if t.get("job_id") is not None
    }
    if (
        len(all_completed) != 1
        or len(completed_success) != 1
        or len(distinct_job_ids) > 1
    ):
        return False
    job = completed_success[0]
    jid = job.get("job_id")
    created_ts = parse_iso_ts(job.get("created_at"))
    if created_ts is None:
        for t in transitions:
            if t.get("job_id") == jid:
                created_ts = parse_iso_ts(t.get("created_at"))
                if created_ts is not None:
                    break
    started_ts = parse_iso_ts(job.get("started_at"))
    if started_ts is None:
        for t in transitions:
            if t.get("job_id") == jid and t.get("status") == "in_progress":
                started_ts = parse_iso_ts(t.get("started_at"))
                if started_ts is not None:
                    break
    if created_ts is None or started_ts is None:
        return False
    return created_ts < runners_closed_at and started_ts >= runners_reopened_at


def verify_queued_during_closed_window(transitions, admission_closed_at, reopened_at):
    """Verify a job was observed queued while admission was closed, never started
    before reopen, and completed with success exactly once after reopen."""
    if not transitions or admission_closed_at is None or reopened_at is None:
        return False
    queued_during_closed = any(
        t.get("status") == "queued"
        and admission_closed_at - 2 <= t.get("observed_at", 0) <= reopened_at + 2
        for t in transitions
    )
    started_before_reopen = False
    for t in transitions:
        if t.get("status") in ("in_progress", "completed"):
            if t.get("observed_at", 0) < reopened_at - 1:
                started_before_reopen = True
            gh_started = parse_iso_ts(t.get("started_at"))
            if gh_started is not None and gh_started < reopened_at - 2:
                started_before_reopen = True
    completed_jobs = {
        t["job_id"]: t for t in transitions if t.get("status") == "completed"
    }
    exactly_one_success = len(completed_jobs) == 1 and all(
        t.get("conclusion") == "success" for t in completed_jobs.values()
    )
    return queued_during_closed and not started_before_reopen and exactly_one_success


def classify_boundary_runs(
    pre_run_events,
    post_run_events,
    post_transitions,
    boundary_closed_at,
    switch_at,
    reopened_at,
):
    """Verify the pre-boundary offer ran before the switch and the post-boundary
    offer queued across the switch and ran only after reopen."""
    pre_started = [e for e in pre_run_events if e.get("event") == "started"]
    pre_completed = [e for e in pre_run_events if e.get("event") == "completed"]
    post_started = [e for e in post_run_events if e.get("event") == "started"]
    post_completed = [e for e in post_run_events if e.get("event") == "completed"]

    if len(pre_started) != 1 or len(pre_completed) != 1:
        return {"ok": False, "reason": "pre-boundary job did not run exactly once"}
    if len(post_started) != 1 or len(post_completed) != 1:
        return {"ok": False, "reason": "post-boundary job did not run exactly once"}

    pre_done_ts = pre_completed[0].get("ts")
    post_start_ts = post_started[0].get("ts")
    if pre_done_ts is None or switch_at is None or pre_done_ts > switch_at:
        return {
            "ok": False,
            "reason": "pre-boundary job did not complete before switch",
        }
    if post_start_ts is None or reopened_at is None or post_start_ts < reopened_at - 2:
        return {
            "ok": False,
            "reason": "post-boundary job started before reopen",
        }
    if not verify_queued_across_closed_window(
        post_transitions,
        boundary_closed_at,
        reopened_at,
        attempts=len(post_completed),
    ):
        return {
            "ok": False,
            "reason": "post-boundary job was not queued across closed window",
        }
    return {
        "ok": True,
        "pre_boundary_side": "before_switch",
        "post_boundary_side": "after_reopen",
        "pre_completed_at": pre_done_ts,
        "post_started_at": post_start_ts,
    }


def find_free_port():
    with contextlib.closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


GUEST_AGENT_BUS_MCP = """\
import json
from pathlib import Path
import time

LOG_PATH = Path("/var/lib/guarded-upgrade/bus-events.jsonl")

def read_new(room):
    LOG_PATH.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    with LOG_PATH.open("a") as f:
        f.write(json.dumps({"op": "read_new", "room": room, "at": time.time()}) + "\\n")
    return "[]"

def post(room, text):
    LOG_PATH.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    with LOG_PATH.open("a") as f:
        f.write(json.dumps({"op": "post", "room": room, "text": text, "at": time.time()}) + "\\n")
    return {"ok": True}
"""

GUEST_NIX_WRAPPER = """\
#!/usr/bin/env bash
set -euo pipefail
REAL_NIX="@REAL_NIX@"
if [[ "${1:-}" == "build" ]]; then
  out_link=""
  ref=""
  args=("$@")
  for ((i=0; i<${#args[@]}; i++)); do
    if [[ "${args[$i]}" == "--out-link" ]] && (( i + 1 < ${#args[@]} )); then
      out_link="${args[$((i+1))]}"
    fi
    ref="${args[$i]}"
  done
  if [[ -n "$out_link" && "$ref" == *"nixosConfigurations."*".config.system.build.toplevel" ]]; then
    candidate="$(cat /var/lib/runner-drain-test/candidate-path)"
    mkdir -p "$(dirname "$out_link")"
    ln -sfn "$candidate" "$out_link"
    exit 0
  fi
fi
exec "$REAL_NIX" "$@"
"""

GUEST_GIT_WRAPPER = """\
#!/usr/bin/env bash
set -euo pipefail
REAL_GIT="@REAL_GIT@"
DISPOSABLE_REPO="@DISPOSABLE_REPO@"
args=()
for arg in "$@"; do
  if [[ "$arg" == *"github.com/olafkfreund/nixos_config"* ]]; then
    args+=("https://github.com/${DISPOSABLE_REPO}.git")
  else
    args+=("$arg")
  fi
done
# The disposable repository is private: authenticate with its token, read from
# the guest file at each call and passed through git's environment config, so
# it never appears in an argument list.
token_file=/run/runner-drain-test/github-token
if [[ -r "$token_file" ]]; then
  auth=$(printf 'x-access-token:%s' "$(tr -d '\\n' < "$token_file")" | base64 -w0)
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=http.https://github.com/.extraheader
  export GIT_CONFIG_VALUE_0="Authorization: Basic $auth"
fi
exec "$REAL_GIT" "${args[@]}"
"""

GUEST_SYSTEMCTL_WRAPPER = """\
#!/usr/bin/env bash
set -euo pipefail
REAL_SYSTEMCTL="@REAL_SYSTEMCTL@"
if [[ "${1:-}" == "start" && "${2:-}" == github-runner-nixarchy* ]] \
  && [[ -f /var/lib/guarded-upgrade/runners-closed ]]; then
  printf '%s %s\\n' "$(date -Is)" "$*" >> /var/lib/runner-drain-test/closed-start-attempts.log
fi
exec "$REAL_SYSTEMCTL" "$@"
"""

GUEST_RUNNER_LAUNCHER = """\
#!/usr/bin/env python3
import json
import os
from pathlib import Path
import signal
import sys
import time

script_path = Path(sys.argv[1]).resolve()
host = sys.argv[2]
auto_activate = sys.argv[3]
interrupt_at = os.environ.get("RUNNER_DRAIN_TEST_INTERRUPT_AT", "").strip()
state_dir = Path("/var/lib/guarded-upgrade")
rt_dir = Path("/run/runner-drain-test")
rt_dir.mkdir(mode=0o755, parents=True, exist_ok=True)
(rt_dir / "python.pid").write_text(f"{os.getpid()}\\n")
transitions_file = rt_dir / "transitions.json"

_orig_replace = os.replace
_orig_touch = Path.touch
_orig_unlink = Path.unlink


def _record_transition(name, ts=None):
    now = time.time() if ts is None else ts
    data = {}
    if transitions_file.exists():
        try:
            data = json.loads(transitions_file.read_text())
        except Exception:
            data = {}
    data[name] = now
    history = data.get("history", [])
    history.append({"transition": name, "at": now})
    data["history"] = history
    tmp = rt_dir / f"transitions.{os.getpid()}.tmp"
    tmp.write_text(json.dumps(data) + "\\n")
    _orig_replace(tmp, transitions_file)


def _read_drain_phase():
    drain_file = state_dir / "drain"
    if not drain_file.exists():
        return None
    try:
        return json.loads(drain_file.read_text()).get("phase")
    except Exception:
        return None


def _kill_self(tag):
    (rt_dir / f"interrupted-{tag}").write_text(f"{os.getpid()}\\n")
    os.kill(os.getpid(), signal.SIGKILL)


def _hooked_replace(src, dst, *args, **kwargs):
    res = _orig_replace(src, dst, *args, **kwargs)
    dst_str = os.fspath(dst)
    if isinstance(dst_str, bytes):
        dst_str = dst_str.decode(errors="replace")
    if dst_str == str(state_dir / "drain"):
        phase = _read_drain_phase()
        if phase:
            _record_transition(f"phase:{phase}")
        if phase == "draining" and (rt_dir / "hold-boundary").exists():
            (rt_dir / "boundary-reached").touch()
            while (rt_dir / "hold-boundary").exists():
                time.sleep(0.05)
            _record_transition("boundary_released")
        if interrupt_at == "before-marker" and phase == "draining":
            _kill_self("before-marker")
        elif interrupt_at == f"phase:{phase}":
            _kill_self(f"phase-{phase}")
    return res


def _hooked_touch(self, *args, **kwargs):
    res = _orig_touch(self, *args, **kwargs)
    if str(self) == str(state_dir / "runners-closed"):
        _record_transition("runners_closed")
        if interrupt_at == "after-marker":
            _kill_self("after-marker")
    return res


def _hooked_unlink(self, *args, **kwargs):
    target = str(self)
    is_marker = target == str(state_dir / "runners-closed")
    is_drain = target == str(state_dir / "drain")
    ts = time.time() if (is_marker or is_drain) else None
    res = _orig_unlink(self, *args, **kwargs)
    if is_marker:
        _record_transition("runners_reopened", ts=ts)
    elif is_drain:
        _record_transition("drain_cleared", ts=ts)
    return res


os.replace = _hooked_replace
Path.touch = _hooked_touch
Path.unlink = _hooked_unlink

sys.path.insert(0, str(script_path.parent))
sys.argv = [str(script_path), host, auto_activate]
source = script_path.read_text()
code = compile(source, str(script_path), "exec")
globs = {"__name__": "__main__", "__file__": str(script_path)}
exec(code, globs)
"""


class VMHarness:
    def __init__(self, repo, token, label, workdir, vm_script=None):
        self.repo = repo
        self._token = token
        self.label = label
        self.workdir = Path(workdir).resolve()
        self.shared_dir = self.workdir / "shared"
        self.ssh_key = self.workdir / "id_ed25519"
        self.ssh_port = find_free_port()
        self.vm_script = Path(vm_script).resolve() if vm_script else None
        self.vm_proc = None
        self.vm_log_handle = None
        self.gh = GitHubClient(repo, token)

    def build_vm(self):
        if self.vm_script and self.vm_script.exists():
            log(f"Using pre-built VM launcher: {self.vm_script}")
            return self.vm_script
        log(
            f"Building isolated NixOS VM from {VM_NIX_FILE} for {self.repo} (label={self.label})..."
        )
        out_link = self.workdir / "vm-result"
        cmd = [
            "nix-build",
            str(VM_NIX_FILE),
            "-A",
            "vm",
            "--argstr",
            "repo",
            self.repo,
            "--argstr",
            "label",
            self.label,
            "-o",
            str(out_link),
        ]
        res = subprocess.run(
            cmd, cwd=str(REPO_ROOT), text=True, capture_output=True, check=False
        )
        if res.returncode != 0:
            raise RuntimeError(f"nix-build vm.nix failed:\n{res.stderr[-1000:]}")
        launcher = out_link / "bin" / "run-p620-vm"
        if not launcher.exists():
            candidates = list((out_link / "bin").glob("run-*-vm"))
            if not candidates:
                raise RuntimeError(f"no run-*-vm binary found in {out_link}/bin")
            launcher = candidates[0]
        self.vm_script = launcher
        return launcher

    def prepare_shared_dir(self):
        self.shared_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        token_path = self.shared_dir / "github-token"
        token_path.write_text(self._token + "\n")
        os.chmod(token_path, 0o600)

        if not self.ssh_key.exists():
            subprocess.run(
                [
                    "ssh-keygen",
                    "-t",
                    "ed25519",
                    "-N",
                    "",
                    "-f",
                    str(self.ssh_key),
                    "-q",
                ],
                check=True,
            )
        shutil.copyfile(str(self.ssh_key) + ".pub", self.shared_dir / "authorized_keys")
        shutil.copyfile(GUARDED_UPGRADE_SCRIPT, self.shared_dir / "guarded_upgrade.py")
        shutil.copyfile(DEPLOY_HOLD_SCRIPT, self.shared_dir / "deploy-hold.sh")
        os.chmod(self.shared_dir / "deploy-hold.sh", 0o755)

    def start_vm(self):
        launcher = self.build_vm()
        self.prepare_shared_dir()
        disk_image = self.workdir / "p620-drain-test.qcow2"
        disk_image.unlink(missing_ok=True)

        vm_env = os.environ.copy()
        vm_env["NIX_DISK_IMAGE"] = str(disk_image)
        vm_env["SHARED_DIR"] = str(self.shared_dir)
        vm_env["TMPDIR"] = str(self.workdir)
        vm_env["USE_TMPDIR"] = "1"
        vm_env["QEMU_NET_OPTS"] = f"hostfwd=tcp:127.0.0.1:{self.ssh_port}-:22"

        vm_log_path = self.workdir / "qemu.log"
        self.vm_log_handle = vm_log_path.open("w")
        log(f"Starting QEMU VM on 127.0.0.1:{self.ssh_port}...")
        self.vm_proc = subprocess.Popen(
            [str(launcher)],
            cwd=str(self.workdir),
            env=vm_env,
            stdout=self.vm_log_handle,
            stderr=subprocess.STDOUT,
            text=True,
        )
        self._wait_for_ssh()
        self._provision_guest_helpers()

    def stop_vm(self):
        if self.vm_proc and self.vm_proc.poll() is None:
            with contextlib.suppress(Exception):
                self.ssh("poweroff || true", check=False, timeout=5)
            try:
                self.vm_proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.vm_proc.kill()
                self.vm_proc.wait(timeout=5)
        if self.vm_log_handle:
            self.vm_log_handle.close()
            self.vm_log_handle = None

    def ssh(self, command, check=True, timeout=120):
        cmd = [
            "ssh",
            "-T",
            "-i",
            str(self.ssh_key),
            "-p",
            str(self.ssh_port),
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=5",
            "-o",
            "LogLevel=ERROR",
            "root@127.0.0.1",
            command,
        ]
        res = subprocess.run(
            cmd, text=True, capture_output=True, timeout=timeout, check=False
        )
        if check and res.returncode != 0:
            raise RuntimeError(
                f"guest command failed (rc={res.returncode}): {command}\n"
                f"stdout: {res.stdout[-500:]}\nstderr: {res.stderr[-500:]}"
            )
        return res

    def _wait_for_ssh(self):
        deadline = time.time() + 180
        while time.time() < deadline:
            if self.vm_proc.poll() is not None:
                log_tail = (self.workdir / "qemu.log").read_text()[-1500:]
                raise RuntimeError(
                    f"QEMU exited early with code {self.vm_proc.returncode}:\n{log_tail}"
                )
            res = self.ssh(
                "systemctl is-system-running || true", check=False, timeout=10
            )
            if res.returncode == 0 and res.stdout.strip() in (
                "running",
                "degraded",
                "starting",
            ):
                log("VM SSH is reachable.")
                return
            time.sleep(2)
        raise RuntimeError("timed out waiting for VM SSH to become reachable")

    def _provision_guest_helpers(self):
        (self.shared_dir / "agent_bus_mcp.py").write_text(GUEST_AGENT_BUS_MCP)
        (self.shared_dir / "run_guarded_upgrade.py").write_text(GUEST_RUNNER_LAUNCHER)
        (self.shared_dir / "nix.wrapper").write_text(GUEST_NIX_WRAPPER)
        (self.shared_dir / "git.wrapper").write_text(GUEST_GIT_WRAPPER)
        (self.shared_dir / "systemctl.wrapper").write_text(GUEST_SYSTEMCTL_WRAPPER)

        setup_script = f"""\
set -euo pipefail
systemctl start register-nix-paths.service || true
baseline="$(cat /var/lib/runner-drain-test/baseline-path)"
nix-env -p /nix/var/nix/profiles/system --set "$baseline"

install -d -m 0755 /run/runner-drain-test/bin /run/runner-drain-test/py /etc/runner-drain-test
install -d -m 1777 /var/lib/runner-drain-test/counters
install -m 0644 /tmp/shared/agent_bus_mcp.py /run/runner-drain-test/py/agent_bus_mcp.py
install -m 0755 /tmp/shared/run_guarded_upgrade.py /run/runner-drain-test/run_guarded_upgrade.py
install -m 0755 /tmp/shared/guarded_upgrade.py /run/runner-drain-test/guarded_upgrade.py
install -m 0755 /tmp/shared/deploy-hold.sh /run/runner-drain-test/deploy-hold.sh

real_nix="$(command -v nix)"
real_git="$(command -v git)"
real_systemctl="$(command -v systemctl)"

sed "s|@REAL_NIX@|$real_nix|g" /tmp/shared/nix.wrapper > /run/runner-drain-test/bin/nix
sed -e "s|@REAL_GIT@|$real_git|g" -e "s|@DISPOSABLE_REPO@|{self.repo}|g" /tmp/shared/git.wrapper > /run/runner-drain-test/bin/git
sed "s|@REAL_SYSTEMCTL@|$real_systemctl|g" /tmp/shared/systemctl.wrapper > /run/runner-drain-test/bin/systemctl
chmod 0755 /run/runner-drain-test/bin/nix /run/runner-drain-test/bin/git /run/runner-drain-test/bin/systemctl
"""
        self.ssh(setup_script, timeout=60)

    def wait_for_runners_online(self, require_idle=True, timeout=180):
        deadline = time.time() + timeout
        while time.time() < deadline:
            runners = self.gh.list_runners()
            by_name = {r.get("name"): r for r in runners}
            if set(by_name) == set(RUNNER_NAMES) and all(
                r.get("status") == "online"
                and (not require_idle or r.get("busy") is False)
                for r in by_name.values()
            ):
                state = self.get_vm_snapshot()
                if all(
                    u.get("ActiveState") == "active" for u in state["units"].values()
                ):
                    return by_name
            time.sleep(3)
        raise RuntimeError(
            f"timed out waiting for 4 runners {RUNNER_NAMES} to be online (require_idle={require_idle})"
        )

    def reset_to_baseline(self):
        reset_cmd = """\
set -euo pipefail
rm -f /etc/runner-drain-test/force-verify-fail
rm -f /run/runner-drain-test/hold-boundary /run/runner-drain-test/boundary-reached
rm -f /run/runner-drain-test/interrupted-* /run/runner-drain-test/python.pid /run/runner-drain-test/transitions.json
rm -f /var/lib/guarded-upgrade/pause /var/lib/guarded-upgrade/drain /var/lib/guarded-upgrade/runners-closed
rm -f /var/lib/guarded-upgrade/transaction /var/lib/guarded-upgrade/rollback-root
rm -f /var/lib/guarded-upgrade/last-failure /var/lib/guarded-upgrade/verified /var/lib/guarded-upgrade/baseline
for u in github-runner-nixarchy.service github-runner-nixarchy-2.service github-runner-nixarchy-3.service github-runner-nixarchy-4.service; do
  pid=$(systemctl show -p MainPID --value "$u" || true)
  if [[ -n "$pid" && "$pid" -gt 0 ]]; then
    kill -CONT "$pid" 2>/dev/null || true
  fi
done
for d in nixarchy nixarchy-2 nixarchy-3 nixarchy-4; do
  rm -f "/var/lib/github-runner/$d/drain/request"
  if [[ -d "/var/lib/github-runner/$d/drain/ack" ]]; then
    rm -rf "/var/lib/github-runner/$d/drain/ack"
  fi
done
baseline="$(cat /var/lib/runner-drain-test/baseline-path)"
current="$(readlink -f /run/current-system)"
nix-env -p /nix/var/nix/profiles/system --switch-generation 1
for gen in $(nix-env -p /nix/var/nix/profiles/system --list-generations | awk '{print $1}' | grep -v '^1$' || true); do
  nix-env -p /nix/var/nix/profiles/system --delete-generations "$gen" || true
done
if [[ "$current" != "$baseline" ]]; then
  "$baseline/bin/switch-to-configuration" switch
fi
systemctl reset-failed || true
for u in github-runner-nixarchy.service github-runner-nixarchy-2.service github-runner-nixarchy-3.service github-runner-nixarchy-4.service; do
  if [[ "$(systemctl is-active "$u" || true)" != "active" ]]; then
    systemctl start "$u"
  fi
done
"""
        self.ssh(reset_cmd, timeout=120)
        self.wait_for_runners_online(require_idle=True, timeout=180)

    def get_vm_snapshot(self):
        artifact_helper_src = inspect.getsource(read_drain_artifact)
        probe = f"""\
python3 - <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess

{artifact_helper_src}

units = [
    "github-runner-nixarchy.service",
    "github-runner-nixarchy-2.service",
    "github-runner-nixarchy-3.service",
    "github-runner-nixarchy-4.service",
]
dirs = ["nixarchy", "nixarchy-2", "nixarchy-3", "nixarchy-4"]

unit_info = {{}}
for u in units:
    out = subprocess.run(
        [
            "systemctl",
            "show",
            u,
            "-p",
            "InvocationID",
            "-p",
            "MainPID",
            "-p",
            "ActiveState",
            "-p",
            "SubState",
            "-p",
            "Result",
            "-p",
            "ConditionResult",
            "-p",
            "ConditionTimestamp",
            "-p",
            "ConditionTimestampMonotonic",
            "-p",
            "AssertResult",
        ],
        text=True,
        capture_output=True,
    ).stdout
    props = dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
    unit_info[u] = props

acks = {{}}
requests = {{}}
for d in dirs:
    ack_p = Path(f"/var/lib/github-runner/{{d}}/drain/ack")
    req_p = Path(f"/var/lib/github-runner/{{d}}/drain/request")
    acks[d] = read_drain_artifact(ack_p, "ack unreadable")
    requests[d] = read_drain_artifact(req_p, "request unreadable")

profile = Path("/nix/var/nix/profiles/system")
gen_num = None
if profile.is_symlink():
    m = re.search(r"system-(\\d+)-link$", os.readlink(profile))
    if m:
        gen_num = int(m.group(1))

def read_json_or_text(path):
    p = Path(path)
    if not p.exists():
        return None
    try:
        txt = p.read_text().strip()
    except (OSError, UnicodeError):
        return None
    try:
        return json.loads(txt)
    except Exception:
        return txt

state_dir = Path("/var/lib/guarded-upgrade")
jctl = subprocess.run(
    [
        "journalctl",
        "-u",
        "github-runner-nixarchy.service",
        "-u",
        "github-runner-nixarchy-2.service",
        "-u",
        "github-runner-nixarchy-3.service",
        "-u",
        "github-runner-nixarchy-4.service",
        "--no-pager",
        "-o",
        "short-iso",
        "-n",
        "200",
    ],
    text=True,
    capture_output=True,
).stdout
skip_lines = [
    line
    for line in jctl.splitlines()
    if "condition" in line.lower() or "runners-closed" in line.lower() or "skipped" in line.lower()
]

snapshot = {{
    "units": unit_info,
    "acks": acks,
    "requests": requests,
    "generations": {{
        "running": str(Path("/run/current-system").resolve()),
        "boot": str(profile.resolve()) if profile.exists() else None,
        "generation": gen_num,
        "baseline": Path("/var/lib/runner-drain-test/baseline-path").read_text().strip(),
        "candidate": Path("/var/lib/runner-drain-test/candidate-path").read_text().strip(),
    }},
    "state": {{
        "runners_closed": (state_dir / "runners-closed").exists(),
        "verified": read_json_or_text(state_dir / "verified"),
        "drain": read_json_or_text(state_dir / "drain"),
        "pause": read_json_or_text(state_dir / "pause"),
        "last_failure": read_json_or_text(state_dir / "last-failure"),
        "transaction": read_json_or_text(state_dir / "transaction"),
    }},
    "transitions": read_json_or_text("/run/runner-drain-test/transitions.json") or {{}},
    "condition_skip_journal": skip_lines,
}}
print(json.dumps(snapshot))
PY
"""
        res = self.ssh(probe, timeout=30)
        return json.loads(res.stdout)

    def get_counter_state(
        self, scenario, nonce, counter_dir="/var/lib/runner-drain-test/counters"
    ):
        helper_src = inspect.getsource(summarize_attempt_dir)
        probe = f"""\
python3 - <<'PY'
import json
from pathlib import Path

{helper_src}

print(json.dumps(summarize_attempt_dir({counter_dir!r}, {scenario!r}, {nonce!r})))
PY
"""
        res = self.ssh(probe, timeout=20)
        return json.loads(res.stdout)

    def poll_github_jobs(self, transitions, created_after, run_id=None):
        """Poll GitHub workflow runs/jobs and record any status/conclusion transitions."""
        now = time.time()
        jobs = []
        if run_id is not None:
            jobs.extend(self.gh.list_run_jobs(run_id))
        else:
            for r in self.gh.list_workflow_runs(created_after=created_after):
                jobs.extend(self.gh.list_run_jobs(r["id"]))
        record_job_transition(transitions, jobs, observed_at=now)
        return jobs

    def build_guest_env_exports(
        self, drain_timeout=None, drain_poll=2, interrupt_at=None
    ):
        env_map = discover_guarded_upgrade_env(
            repo=self.repo,
            runner_name_prefix="p620-nixarchy",
            bus_room="#runner-drain-test:localhost",
            token_file="/run/runner-drain-test/github-token",
            drain_timeout=drain_timeout,
            drain_poll=drain_poll,
        )
        env_map["PYTHONPATH"] = "/run/runner-drain-test/py"
        if interrupt_at:
            env_map["RUNNER_DRAIN_TEST_INTERRUPT_AT"] = str(interrupt_at)
        exports = ['export PATH="/run/runner-drain-test/bin:$PATH"']
        for k, v in sorted(env_map.items()):
            quoted = "'" + str(v).replace("'", "'\\''") + "'"
            exports.append(f"export {k}={quoted}")
        return "\n".join(exports)

    def start_guarded_upgrade_async(
        self,
        run_tag,
        auto_activate=True,
        drain_timeout=300,
        drain_poll=2,
        interrupt_at=None,
    ):
        exports = self.build_guest_env_exports(
            drain_timeout=drain_timeout,
            drain_poll=drain_poll,
            interrupt_at=interrupt_at,
        )
        act_str = "true" if auto_activate else "false"
        script = f"""\
set -euo pipefail
{exports}
rm -f /run/runner-drain-test/{run_tag}.rc /run/runner-drain-test/{run_tag}.log /run/runner-drain-test/python.pid /run/runner-drain-test/transitions.json
(
  set +e
  python3 /run/runner-drain-test/run_guarded_upgrade.py /run/runner-drain-test/guarded_upgrade.py p620 {act_str} > /run/runner-drain-test/{run_tag}.log 2>&1
  echo $? > /run/runner-drain-test/{run_tag}.rc
) </dev/null >/dev/null 2>&1 &
echo $! > /run/runner-drain-test/{run_tag}.pid
cat /run/runner-drain-test/{run_tag}.pid
"""
        res = self.ssh(script, timeout=20)
        return int(res.stdout.strip())

    def wait_guarded_upgrade(self, run_tag, timeout=360, poll_callback=None):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if poll_callback is not None:
                poll_callback()
            res = self.ssh(
                f"if [ -f /run/runner-drain-test/{run_tag}.rc ]; then "
                f"cat /run/runner-drain-test/{run_tag}.rc; fi",
                timeout=20,
            )
            txt = res.stdout.strip()
            if txt:
                log_res = self.ssh(
                    f"cat /run/runner-drain-test/{run_tag}.log || true",
                    timeout=20,
                )
                return int(txt), log_res.stdout
            time.sleep(1.5)
        log_res = self.ssh(
            f"cat /run/runner-drain-test/{run_tag}.log || true",
            check=False,
            timeout=20,
        )
        raise RuntimeError(
            f"timed out waiting for guarded_upgrade ({run_tag}):\n{log_res.stdout}"
        )

    def collect_condition_skips(self, before_snap, samples):
        """Extract condition skip evidence across all snapshots where runners_closed was true.
        Requires an explicit failed ConditionResult ('no') while the marker exists."""
        skips = {}
        for unit in RUNNER_UNITS:
            before_ts = int(
                before_snap["units"][unit].get("ConditionTimestampMonotonic", "0")
                or "0"
            )
            observed = []
            for snap in samples:
                u = snap["units"][unit]
                cur_ts = int(u.get("ConditionTimestampMonotonic", "0") or "0")
                if (
                    snap["state"].get("runners_closed")
                    and u.get("ConditionResult") == "no"
                    and cur_ts >= before_ts
                ):
                    observed.append(
                        {
                            "ActiveState": u.get("ActiveState"),
                            "ConditionResult": u.get("ConditionResult"),
                            "ConditionTimestamp": u.get("ConditionTimestamp"),
                            "ConditionTimestampMonotonic": u.get(
                                "ConditionTimestampMonotonic"
                            ),
                        }
                    )
            skips[unit] = {
                "before_ConditionTimestampMonotonic": str(before_ts),
                "skipped": bool(observed),
                "observations": observed,
            }
        return skips

    def run_scenario_a(self):
        """(a) a job acquired at the boundary completes exactly once, before the switch,
        and an offer pending at the boundary is left unaccepted until reopen."""
        log(
            "Scenario (a): starting (boundary offer admission & pre/post boundary runs)..."
        )
        self.reset_to_baseline()
        before = self.get_vm_snapshot()
        nonce_pre = f"{uuid.uuid4().hex[:8]}-pre"
        nonce_post = f"{uuid.uuid4().hex[:8]}-post"

        # All 4 runners must be online and idle so both gate("p620") calls (including the
        # in-lock gate at guarded_upgrade.py ~907) pass. The launcher barrier holds right
        # after start_drain() writes STATE/drain (phase='draining'), before close_and_wait()
        # writes runners-closed or drain/request.
        self.ssh(
            "rm -f /run/runner-drain-test/boundary-reached && "
            "touch /run/runner-drain-test/hold-boundary"
        )
        self.start_guarded_upgrade_async(
            "scen-a", auto_activate=True, drain_timeout=300, drain_poll=2
        )

        deadline = time.time() + 120
        while time.time() < deadline:
            res = self.ssh(
                "test -f /run/runner-drain-test/boundary-reached && echo READY || true"
            )
            if "READY" in res.stdout:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("scenario (a): timed out waiting for boundary-reached")

        # Now that the in-lock gate has passed and start_drain() has recorded the 4
        # runner invocations in STATE/drain, pause listeners 2..4 with SIGSTOP so runner 1
        # alone receives the pre-boundary offer, while the post-boundary offer sits queued
        # at the broker when drain/request is written.
        for u in (
            "github-runner-nixarchy-2.service",
            "github-runner-nixarchy-3.service",
            "github-runner-nixarchy-4.service",
        ):
            self.ssh(
                f"pid=$(systemctl show -p MainPID --value {u}); "
                f'[ -n "$pid" ] && [ "$pid" -gt 0 ] && kill -STOP "$pid" || true'
            )

        pre_dispatched_at = self.gh.dispatch_workflow(
            "a", nonce_pre, self.label, sleep_seconds=18
        )
        pre_transitions = []
        post_transitions = []

        # Synchronise on the broker side (GitHub job status == in_progress / acquired),
        # not on the guest counter file, then dispatch the second offer so it sits
        # queued at the broker boundary when drain/request is written.
        pre_run_id = None
        deadline = time.time() + 120
        while time.time() < deadline:
            jobs = self.poll_github_jobs(
                pre_transitions, created_after=pre_dispatched_at
            )
            in_prog = [
                j for j in jobs if j.get("status") in ("in_progress", "completed")
            ]
            if in_prog:
                pre_run_id = in_prog[0].get("run_id")
                break
            time.sleep(1)
        else:
            raise RuntimeError(
                "scenario (a): timed out waiting for pre-boundary offer acquisition"
            )

        post_dispatched_at = self.gh.dispatch_workflow(
            "a", nonce_post, self.label, sleep_seconds=5
        )
        post_run_id = None
        deadline = time.time() + 120
        while time.time() < deadline:
            runs = [
                r
                for r in self.gh.list_workflow_runs(created_after=post_dispatched_at)
                if r.get("id") != pre_run_id
            ]
            if runs:
                post_run_id = runs[0]["id"]
                jobs = self.poll_github_jobs(
                    post_transitions,
                    created_after=post_dispatched_at,
                    run_id=post_run_id,
                )
                if any(j.get("status") == "queued" for j in jobs):
                    break
            time.sleep(1)
        else:
            raise RuntimeError(
                "scenario (a): timed out waiting for post-boundary offer to be queued at broker"
            )

        # Release the drain boundary while pre_run is acquired and post_run's offer is
        # pending at the broker, then resume runners 2..4 once drain/request is on disk.
        boundary_closed_at = None
        self.ssh("rm -f /run/runner-drain-test/hold-boundary")

        deadline = time.time() + 60
        while time.time() < deadline:
            snap = self.get_vm_snapshot()
            if snap["state"]["runners_closed"] and all(
                snap["requests"].get(d) is not None for d in RUNNER_DIRS
            ):
                boundary_closed_at = extract_guest_transition_times(snap)[
                    "admission_closed_at"
                ]
                break
            time.sleep(0.3)
        for u in (
            "github-runner-nixarchy-2.service",
            "github-runner-nixarchy-3.service",
            "github-runner-nixarchy-4.service",
        ):
            self.ssh(
                f"pid=$(systemctl show -p MainPID --value {u}); "
                f'[ -n "$pid" ] && [ "$pid" -gt 0 ] && kill -CONT "$pid" || true',
                check=False,
            )

        samples = []

        def _poll():
            snap = self.get_vm_snapshot()
            samples.append(snap)
            self.poll_github_jobs(
                pre_transitions, created_after=pre_dispatched_at, run_id=pre_run_id
            )
            self.poll_github_jobs(
                post_transitions, created_after=post_dispatched_at, run_id=post_run_id
            )

        rc, out_log = self.wait_guarded_upgrade(
            "scen-a", timeout=360, poll_callback=_poll
        )
        after = self.get_vm_snapshot()
        samples.append(after)
        t_times = extract_guest_transition_times(after)
        if t_times["admission_closed_at"] is not None:
            boundary_closed_at = t_times["admission_closed_at"]
        switch_at = t_times["switch_at"]
        reopened_at = t_times["reopened_at"]

        # Wait for the post-boundary offer to run and complete after reopen.
        deadline = time.time() + 180
        while time.time() < deadline:
            self.poll_github_jobs(
                pre_transitions, created_after=pre_dispatched_at, run_id=pre_run_id
            )
            self.poll_github_jobs(
                post_transitions, created_after=post_dispatched_at, run_id=post_run_id
            )
            post_counter = self.get_counter_state("a", nonce_post)
            if post_counter["completed"] >= 1:
                break
            time.sleep(2)
        else:
            raise RuntimeError(
                "scenario (a): timed out waiting for post-boundary offer to complete after reopen"
            )

        self.poll_github_jobs(
            pre_transitions, created_after=pre_dispatched_at, run_id=pre_run_id
        )
        self.poll_github_jobs(
            post_transitions, created_after=post_dispatched_at, run_id=post_run_id
        )
        pre_counter = self.get_counter_state("a", nonce_pre)
        post_counter = self.get_counter_state("a", nonce_post)
        self.wait_for_runners_online(require_idle=True, timeout=120)

        boundary_verdict = classify_boundary_runs(
            pre_run_events=pre_counter["events"],
            post_run_events=post_counter["events"],
            post_transitions=post_transitions,
            boundary_closed_at=boundary_closed_at,
            switch_at=switch_at,
            reopened_at=reopened_at,
        )
        pre_gh_completed = [
            t for t in pre_transitions if t.get("status") == "completed"
        ]
        post_gh_completed = [
            t for t in post_transitions if t.get("status") == "completed"
        ]
        exited_after_job_seen = any(
            any(
                isinstance(ack, dict) and ack.get("state") == "exited-after-job"
                for ack in s["acks"].values()
            )
            for s in samples
        )
        condition_skips = self.collect_condition_skips(before, samples)
        before_invs = {u: before["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        after_invs = {u: after["units"][u].get("InvocationID") for u in RUNNER_UNITS}

        passed = (
            rc == 0
            and switch_at is not None
            and reopened_at is not None
            and boundary_verdict["ok"]
            and pre_counter["started"] == 1
            and pre_counter["completed"] == 1
            and post_counter["started"] == 1
            and post_counter["completed"] == 1
            and len(pre_gh_completed) == 1
            and pre_gh_completed[0].get("conclusion") == "success"
            and len(post_gh_completed) == 1
            and post_gh_completed[0].get("conclusion") == "success"
            and exited_after_job_seen
            and all(
                before_invs[u] and after_invs[u] and before_invs[u] != after_invs[u]
                for u in RUNNER_UNITS
            )
            and all(condition_skips[u]["skipped"] for u in RUNNER_UNITS)
            and after["generations"]["running"] == after["generations"]["candidate"]
            and after["generations"]["boot"] == after["generations"]["candidate"]
            and after["generations"]["generation"] == 2
            and isinstance(after["state"]["verified"], dict)
            and after["state"]["verified"].get("candidate")
            == after["generations"]["candidate"]
            and after["state"]["drain"] is None
            and not after["state"]["runners_closed"]
        )
        return {
            "scenario": "a",
            "description": "Job acquired at the boundary completes once before the switch; pending offer at boundary queues until reopen",
            "passed": passed,
            "exit_code": rc,
            "log": out_log,
            "boundary_classification": boundary_verdict,
            "execution_counter": {
                "pre_boundary": pre_counter,
                "post_boundary": post_counter,
            },
            "github_transitions": {
                "pre_boundary": pre_transitions,
                "post_boundary": post_transitions,
            },
            "guest_transitions": after.get("transitions", {}),
            "switch_at": switch_at,
            "switch_observed_at": switch_at,
            "reopened_at": reopened_at,
            "exited_after_job_seen": exited_after_job_seen,
            "invocations": {
                "before": before_invs,
                "after": after_invs,
                "final_acks": after["acks"],
            },
            "condition_skips": condition_skips,
            "generations": {
                "before": before["generations"],
                "after": after["generations"],
            },
            "canary": after["state"]["verified"],
        }

    def run_scenario_b(self):
        """(b) a job dispatched after admission closes queues, and runs exactly once after the reopen."""
        log(
            "Scenario (b): starting (job dispatched after admission closes queues and runs once after reopen)..."
        )
        self.reset_to_baseline()
        # Seed a pre-existing verified canary so scenario (b) proves close_and_wait()
        # deletes STATE/verified even when run standalone (--scenarios b).
        self.ssh(
            'printf \'{"sha":"0000000000000000000000000000000000000000","candidate":"/nix/store/seeded"}\\n\' '
            "> /var/lib/guarded-upgrade/verified"
        )
        before = self.get_vm_snapshot()
        nonce = uuid.uuid4().hex[:10]

        self.start_guarded_upgrade_async(
            "scen-b", auto_activate=True, drain_timeout=300, drain_poll=2
        )

        samples = []
        deadline = time.time() + 120
        admission_closed_at = None
        canary_invalidated_during_drain = False
        while time.time() < deadline:
            snap = self.get_vm_snapshot()
            samples.append(snap)
            if snap["state"]["runners_closed"]:
                admission_closed_at = extract_guest_transition_times(snap)[
                    "admission_closed_at"
                ]
                canary_invalidated_during_drain = snap["state"]["verified"] is None
                break
            time.sleep(0.5)
        else:
            raise RuntimeError(
                "scenario (b): timed out waiting for runners-closed marker"
            )

        dispatched_at = self.gh.dispatch_workflow(
            "b", nonce, self.label, sleep_seconds=5
        )
        transitions = []
        started_while_closed = False

        def _poll():
            nonlocal started_while_closed
            snap = self.get_vm_snapshot()
            samples.append(snap)
            if snap["state"]["runners_closed"]:
                cstate = self.get_counter_state("b", nonce)
                if (
                    cstate["started"] > 0
                    and self.get_vm_snapshot()["state"]["runners_closed"]
                ):
                    started_while_closed = True
            self.poll_github_jobs(transitions, created_after=dispatched_at)

        rc, out_log = self.wait_guarded_upgrade(
            "scen-b", timeout=360, poll_callback=_poll
        )
        after_upgrade = self.get_vm_snapshot()
        samples.append(after_upgrade)
        t_times = extract_guest_transition_times(after_upgrade)
        if t_times["admission_closed_at"] is not None:
            admission_closed_at = t_times["admission_closed_at"]
        reopened_at = t_times["reopened_at"]

        deadline = time.time() + 180
        while time.time() < deadline:
            self.poll_github_jobs(transitions, created_after=dispatched_at)
            counter = self.get_counter_state("b", nonce)
            if counter["completed"] >= 1 and any(
                t.get("status") == "completed" for t in transitions
            ):
                break
            time.sleep(2)
        else:
            raise RuntimeError(
                "scenario (b): timed out waiting for queued job to complete after reopen"
            )

        self.poll_github_jobs(transitions, created_after=dispatched_at)
        self.wait_for_runners_online(require_idle=True, timeout=120)
        after = self.get_vm_snapshot()
        if reopened_at is not None and any(
            isinstance(a.get("ts"), (int, float)) and a["ts"] < reopened_at - 2
            for a in counter["started_attempts"]
        ):
            started_while_closed = True
        before_invs = {u: before["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        after_invs = {
            u: after_upgrade["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        condition_skips = self.collect_condition_skips(before, samples)
        gh_queued_ok = verify_queued_during_closed_window(
            transitions, admission_closed_at, reopened_at
        )

        passed = (
            rc == 0
            and admission_closed_at is not None
            and reopened_at is not None
            and canary_invalidated_during_drain
            and not started_while_closed
            and gh_queued_ok
            and counter["started"] == 1
            and counter["completed"] == 1
            and all(
                before_invs[u] and after_invs[u] and before_invs[u] != after_invs[u]
                for u in RUNNER_UNITS
            )
            and all(condition_skips[u]["skipped"] for u in RUNNER_UNITS)
            and after["generations"]["running"] == after["generations"]["candidate"]
            and after["generations"]["boot"] == after["generations"]["candidate"]
            and after["generations"]["generation"] == 2
            and isinstance(after["state"]["verified"], dict)
            and after["state"]["verified"].get("candidate")
            == after["generations"]["candidate"]
            and after["state"]["drain"] is None
            and not after["state"]["runners_closed"]
        )
        return {
            "scenario": "b",
            "description": "Job dispatched after admission closes queues and runs once after reopen",
            "passed": passed,
            "exit_code": rc,
            "log": out_log,
            "guest_transitions": after_upgrade.get("transitions", {}),
            "admission_closed_at": admission_closed_at,
            "dispatched_at": int(dispatched_at),
            "reopened_at": reopened_at,
            "canary_invalidated_during_drain": canary_invalidated_during_drain,
            "started_while_closed": started_while_closed,
            "github_queued_during_closed_verified": gh_queued_ok,
            "github_transitions": transitions,
            "execution_counter": counter,
            "invocations": {
                "before": before_invs,
                "after": after_invs,
                "final_acks": after["acks"],
            },
            "condition_skips": condition_skips,
            "generations": {
                "before": before["generations"],
                "after": after["generations"],
            },
            "canary": after["state"]["verified"],
        }

    def run_scenario_c(self):
        """(c) the same as (b), with a forced verification failure and a real rollback."""
        log(
            "Scenario (c): starting (queued job across forced verification failure and rollback)..."
        )
        self.reset_to_baseline()
        self.ssh("touch /etc/runner-drain-test/force-verify-fail")
        before = self.get_vm_snapshot()
        nonce = uuid.uuid4().hex[:10]

        self.start_guarded_upgrade_async(
            "scen-c", auto_activate=True, drain_timeout=300, drain_poll=2
        )

        samples = []
        deadline = time.time() + 120
        admission_closed_at = None
        while time.time() < deadline:
            snap = self.get_vm_snapshot()
            samples.append(snap)
            if snap["state"]["runners_closed"]:
                admission_closed_at = extract_guest_transition_times(snap)[
                    "admission_closed_at"
                ]
                break
            time.sleep(0.5)
        else:
            raise RuntimeError(
                "scenario (c): timed out waiting for runners-closed marker"
            )

        dispatched_at = self.gh.dispatch_workflow(
            "c", nonce, self.label, sleep_seconds=5
        )
        transitions = []
        started_while_closed = False

        def _poll():
            nonlocal started_while_closed
            snap = self.get_vm_snapshot()
            samples.append(snap)
            if snap["state"]["runners_closed"]:
                cstate = self.get_counter_state("c", nonce)
                if (
                    cstate["started"] > 0
                    and self.get_vm_snapshot()["state"]["runners_closed"]
                ):
                    started_while_closed = True
            self.poll_github_jobs(transitions, created_after=dispatched_at)

        rc, out_log = self.wait_guarded_upgrade(
            "scen-c", timeout=360, poll_callback=_poll
        )
        after_rollback = self.get_vm_snapshot()
        samples.append(after_rollback)
        t_times = extract_guest_transition_times(after_rollback)
        if t_times["admission_closed_at"] is not None:
            admission_closed_at = t_times["admission_closed_at"]
        reopened_at = t_times["reopened_at"]

        deadline = time.time() + 180
        while time.time() < deadline:
            self.poll_github_jobs(transitions, created_after=dispatched_at)
            counter = self.get_counter_state("c", nonce)
            if counter["completed"] >= 1 and any(
                t.get("status") == "completed" for t in transitions
            ):
                break
            time.sleep(2)
        else:
            raise RuntimeError(
                "scenario (c): timed out waiting for queued job to complete after rollback reopen"
            )

        self.poll_github_jobs(transitions, created_after=dispatched_at)
        self.ssh(
            "rm -f /etc/runner-drain-test/force-verify-fail /var/lib/guarded-upgrade/pause"
        )
        self.wait_for_runners_online(require_idle=True, timeout=120)
        if reopened_at is not None and any(
            isinstance(a.get("ts"), (int, float)) and a["ts"] < reopened_at - 2
            for a in counter["started_attempts"]
        ):
            started_while_closed = True

        before_invs = {u: before["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        after_invs = {
            u: after_rollback["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        condition_skips = self.collect_condition_skips(before, samples)
        gh_queued_ok = verify_queued_during_closed_window(
            transitions, admission_closed_at, reopened_at
        )

        passed = (
            rc != 0
            and admission_closed_at is not None
            and reopened_at is not None
            and not started_while_closed
            and gh_queued_ok
            and counter["started"] == 1
            and counter["completed"] == 1
            and all(
                before_invs[u] and after_invs[u] and before_invs[u] != after_invs[u]
                for u in RUNNER_UNITS
            )
            and all(condition_skips[u]["skipped"] for u in RUNNER_UNITS)
            and after_rollback["generations"]["running"]
            == after_rollback["generations"]["baseline"]
            and after_rollback["generations"]["boot"]
            == after_rollback["generations"]["baseline"]
            and after_rollback["generations"]["generation"] == 1
            and after_rollback["state"]["verified"] is None
            and isinstance(after_rollback["state"]["last_failure"], dict)
            and after_rollback["state"]["last_failure"].get("rollback") == "restored"
            and after_rollback["state"]["drain"] is None
            and not after_rollback["state"]["runners_closed"]
        )
        return {
            "scenario": "c",
            "description": "Job dispatched after admission closes queues through forced verification failure and rollback, then runs once after reopen",
            "passed": passed,
            "exit_code": rc,
            "log": out_log,
            "guest_transitions": after_rollback.get("transitions", {}),
            "admission_closed_at": admission_closed_at,
            "dispatched_at": int(dispatched_at),
            "reopened_at": reopened_at,
            "started_while_closed": started_while_closed,
            "github_queued_during_closed_verified": gh_queued_ok,
            "github_transitions": transitions,
            "execution_counter": counter,
            "invocations": {
                "before": before_invs,
                "after": after_invs,
                "final_acks": after_rollback["acks"],
            },
            "condition_skips": condition_skips,
            "generations": {
                "before": before["generations"],
                "after": after_rollback["generations"],
            },
            "canary": after_rollback["state"]["verified"],
            "last_failure": after_rollback["state"]["last_failure"],
        }

    def run_scenario_d(self):
        """(d) one runner withholds its acknowledgement (case 1: unresponsive/hidden request;
        case 2: request visible, ack path unwritable), and the switch defers without stopping it."""
        log(
            "Scenario (d): starting (case 1: hidden request; case 2: request visible, ack unwritable)..."
        )
        withholding_unit = "github-runner-nixarchy-4.service"
        other_units = [u for u in RUNNER_UNITS if u != withholding_unit]

        # Case 1: private mount hides drain/request (unresponsive listener).
        self.reset_to_baseline()
        before1 = self.get_vm_snapshot()
        pid4_1 = before1["units"][withholding_unit]["MainPID"]
        inv4_before1 = before1["units"][withholding_unit]["InvocationID"]

        self.ssh(
            f"mkdir -p /var/lib/github-runner/nixarchy-4/drain && "
            f"nsenter -t {pid4_1} -m -- mount -t tmpfs tmpfs /var/lib/github-runner/nixarchy-4/drain"
        )
        samples1 = []
        try:
            self.start_guarded_upgrade_async(
                "scen-d-case1", auto_activate=True, drain_timeout=25, drain_poll=2
            )

            def _poll1():
                samples1.append(self.get_vm_snapshot())

            rc1, out_log1 = self.wait_guarded_upgrade(
                "scen-d-case1", timeout=180, poll_callback=_poll1
            )
            after1 = self.get_vm_snapshot()
            samples1.append(after1)
        finally:
            self.ssh(
                f"nsenter -t {pid4_1} -m -- umount /var/lib/github-runner/nixarchy-4/drain || true",
                check=False,
            )

        self.wait_for_runners_online(require_idle=True, timeout=120)
        before_invs1 = {
            u: before1["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        after_invs1 = {u: after1["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        pid4_after1 = after1["units"][withholding_unit].get("MainPID")
        inv4_after1 = after1["units"][withholding_unit].get("InvocationID")

        case1_ok = (
            rc1 == 0
            and "drain incomplete" in out_log1
            and inv4_before1 == inv4_after1
            and pid4_1 == pid4_after1
            and after1["units"][withholding_unit].get("ActiveState") == "active"
            and all(
                before_invs1[u] != after_invs1[u]
                and after1["units"][u].get("ActiveState") == "active"
                for u in other_units
            )
            and after1["generations"]["running"] == after1["generations"]["baseline"]
            and after1["generations"]["boot"] == after1["generations"]["baseline"]
            and after1["generations"]["generation"] == 1
            and after1["state"]["verified"] is None
            and after1["state"]["drain"] is None
            and not after1["state"]["runners_closed"]
        )

        # Case 2: drain/request is visible to the listener, but the ack target is unwritable
        # (a non-empty directory at drain/ack so root can still write drain/request while
        # the listener's File.Move(tmp, drain/ack, true) cannot replace drain/ack).
        self.reset_to_baseline()
        before2 = self.get_vm_snapshot()
        pid4_2 = before2["units"][withholding_unit]["MainPID"]
        inv4_before2 = before2["units"][withholding_unit]["InvocationID"]
        self.ssh(
            "rm -rf /var/lib/github-runner/nixarchy-4/drain/ack && "
            "install -d -m 0555 /var/lib/github-runner/nixarchy-4/drain/ack && "
            "touch /var/lib/github-runner/nixarchy-4/drain/ack/keep && "
            "chmod 0444 /var/lib/github-runner/nixarchy-4/drain/ack/keep"
        )
        samples2 = []
        request_visible_during_drain = False
        try:
            self.start_guarded_upgrade_async(
                "scen-d-case2", auto_activate=True, drain_timeout=25, drain_poll=2
            )

            def _poll2():
                nonlocal request_visible_during_drain
                snap = self.get_vm_snapshot()
                samples2.append(snap)
                if (
                    isinstance(snap["requests"].get("nixarchy-4"), dict)
                    and snap["requests"]["nixarchy-4"].get("id")
                    and snap["acks"].get("nixarchy-4") in (None, "ack unreadable")
                ):
                    request_visible_during_drain = True

            rc2, out_log2 = self.wait_guarded_upgrade(
                "scen-d-case2", timeout=180, poll_callback=_poll2
            )
            after2 = self.get_vm_snapshot()
            samples2.append(after2)
        finally:
            self.ssh(
                "rm -rf /var/lib/github-runner/nixarchy-4/drain/ack && "
                "systemctl reset-failed github-runner-nixarchy-4.service || true && "
                "systemctl start github-runner-nixarchy-4.service || true",
                check=False,
            )

        self.wait_for_runners_online(require_idle=True, timeout=120)
        before_invs2 = {
            u: before2["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        after_invs2 = {u: after2["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        pid4_after2 = after2["units"][withholding_unit].get("MainPID")
        inv4_after2 = after2["units"][withholding_unit].get("InvocationID")

        case2_ok = (
            rc2 == 0
            and "drain incomplete" in out_log2
            and request_visible_during_drain
            and inv4_before2 == inv4_after2
            and pid4_2 == pid4_after2
            and after2["units"][withholding_unit].get("ActiveState") == "active"
            and all(
                before_invs2[u] != after_invs2[u]
                and after2["units"][u].get("ActiveState") == "active"
                for u in other_units
            )
            and after2["generations"]["running"] == after2["generations"]["baseline"]
            and after2["generations"]["boot"] == after2["generations"]["baseline"]
            and after2["generations"]["generation"] == 1
            and after2["state"]["verified"] is None
            and after2["state"]["drain"] is None
            and not after2["state"]["runners_closed"]
        )

        return {
            "scenario": "d",
            "description": "One runner withholds its acknowledgement (hidden request and unwritable ack), and the switch defers",
            "passed": case1_ok and case2_ok,
            "exit_code": rc1 if not case1_ok else rc2,
            "log": out_log1 + "\n---\n" + out_log2,
            "case1_hidden_request": {
                "passed": case1_ok,
                "exit_code": rc1,
                "log": out_log1,
                "withholding_unit": {
                    "unit": withholding_unit,
                    "before_invocation": inv4_before1,
                    "after_invocation": inv4_after1,
                    "before_pid": pid4_1,
                    "after_pid": pid4_after1,
                    "unstopped": inv4_before1 == inv4_after1 and pid4_1 == pid4_after1,
                },
                "invocations": {
                    "before": before_invs1,
                    "after": after_invs1,
                    "final_acks": after1["acks"],
                },
            },
            "case2_unwritable_ack": {
                "passed": case2_ok,
                "exit_code": rc2,
                "log": out_log2,
                "request_visible_during_drain": request_visible_during_drain,
                "withholding_unit": {
                    "unit": withholding_unit,
                    "before_invocation": inv4_before2,
                    "after_invocation": inv4_after2,
                    "before_pid": pid4_2,
                    "after_pid": pid4_after2,
                    "unstopped": inv4_before2 == inv4_after2 and pid4_2 == pid4_after2,
                },
                "invocations": {
                    "before": before_invs2,
                    "after": after_invs2,
                    "final_acks": after2["acks"],
                },
            },
            "condition_skips": self.collect_condition_skips(
                before1, [*samples1, *samples2]
            ),
            "generations": {
                "before": before1["generations"],
                "after_case1": after1["generations"],
                "after_case2": after2["generations"],
            },
            "canary": after2["state"]["verified"],
        }

    def run_scenario_e(self):
        """(e) the upgrade is interrupted at the actual state transitions:
        1. right after the journal phase 'draining' is written (before the marker),
        2. right after the marker is written (before any drain/request is written),
        3. right after the rollback settles (phase 'settled-rollback', before reopen),
        killing the python PID itself, and recovery reopens every time."""
        log(
            "Scenario (e): starting (interrupt before-marker, after-marker, and phase:settled-rollback)..."
        )
        # Boundary 0: right after start_drain writes STATE/drain (phase='draining'), before marker.
        self.reset_to_baseline()
        before_part0 = self.get_vm_snapshot()
        self.start_guarded_upgrade_async(
            "scen-e-int0",
            auto_activate=True,
            drain_timeout=300,
            drain_poll=2,
            interrupt_at="before-marker",
        )
        rc_int0, _ = self.wait_guarded_upgrade("scen-e-int0", timeout=90)
        interrupted_snap0 = self.get_vm_snapshot()

        self.start_guarded_upgrade_async(
            "scen-e-rec0", auto_activate=False, drain_timeout=120, drain_poll=2
        )
        rc_rec0, log_rec0 = self.wait_guarded_upgrade("scen-e-rec0", timeout=180)
        self.wait_for_runners_online(require_idle=True, timeout=180)
        after_rec0 = self.get_vm_snapshot()

        part0_ok = (
            rc_int0 != 0
            and not interrupted_snap0["state"]["runners_closed"]
            and isinstance(interrupted_snap0["state"]["drain"], dict)
            and interrupted_snap0["state"]["drain"].get("phase") == "draining"
            and all(interrupted_snap0["requests"].get(d) is None for d in RUNNER_DIRS)
            and rc_rec0 == 0
            and not after_rec0["state"]["runners_closed"]
            and after_rec0["state"]["drain"] is None
            and all(
                after_rec0["units"][u].get("ActiveState") == "active"
                for u in RUNNER_UNITS
            )
        )

        # Boundary 1: right after STATE/runners-closed is touched, before any drain/request is written.
        before_part1 = self.get_vm_snapshot()
        self.start_guarded_upgrade_async(
            "scen-e-int1",
            auto_activate=True,
            drain_timeout=300,
            drain_poll=2,
            interrupt_at="after-marker",
        )
        rc_int1, _ = self.wait_guarded_upgrade("scen-e-int1", timeout=90)
        interrupted_snap1 = self.get_vm_snapshot()

        hold_res = self.ssh(
            "/run/runner-drain-test/deploy-hold.sh p620 -- true",
            check=False,
            timeout=30,
        )

        self.start_guarded_upgrade_async(
            "scen-e-rec1", auto_activate=False, drain_timeout=120, drain_poll=2
        )
        rc_rec1, log_rec1 = self.wait_guarded_upgrade("scen-e-rec1", timeout=180)
        self.wait_for_runners_online(require_idle=True, timeout=180)
        after_rec1 = self.get_vm_snapshot()

        part1_ok = (
            rc_int1 != 0
            and interrupted_snap1["state"]["runners_closed"]
            and isinstance(interrupted_snap1["state"]["drain"], dict)
            and interrupted_snap1["state"]["drain"].get("phase") == "draining"
            and all(interrupted_snap1["requests"].get(d) is None for d in RUNNER_DIRS)
            and hold_res.returncode != 0
            and "drain" in (hold_res.stdout + hold_res.stderr).lower()
            and rc_rec1 == 0
            and not after_rec1["state"]["runners_closed"]
            and after_rec1["state"]["drain"] is None
            and all(
                after_rec1["units"][u].get("ActiveState") == "active"
                for u in RUNNER_UNITS
            )
        )

        # Boundary 2: right after set_phase(journal, 'settled-rollback') writes STATE/drain,
        # before reopen_and_clear removes the marker or requests.
        before_part2 = self.get_vm_snapshot()
        self.ssh("touch /etc/runner-drain-test/force-verify-fail")
        self.start_guarded_upgrade_async(
            "scen-e-int2",
            auto_activate=True,
            drain_timeout=300,
            drain_poll=2,
            interrupt_at="phase:settled-rollback",
        )
        samples_part2 = []

        def _poll2():
            samples_part2.append(self.get_vm_snapshot())

        rc_int2, log_int2 = self.wait_guarded_upgrade(
            "scen-e-int2", timeout=360, poll_callback=_poll2
        )
        interrupted_snap2 = self.get_vm_snapshot()
        samples_part2.append(interrupted_snap2)

        self.start_guarded_upgrade_async(
            "scen-e-rec2", auto_activate=False, drain_timeout=120, drain_poll=2
        )
        rc_rec2, log_rec2 = self.wait_guarded_upgrade("scen-e-rec2", timeout=180)
        self.ssh(
            "rm -f /etc/runner-drain-test/force-verify-fail /var/lib/guarded-upgrade/pause"
        )
        self.wait_for_runners_online(require_idle=True, timeout=180)
        after_rec2 = self.get_vm_snapshot()

        before2_invs = {
            u: before_part2["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        after2_invs = {
            u: after_rec2["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        part2_ok = (
            rc_int2 != 0
            and interrupted_snap2["state"]["runners_closed"]
            and isinstance(interrupted_snap2["state"]["drain"], dict)
            and interrupted_snap2["state"]["drain"].get("phase") == "settled-rollback"
            and all(
                interrupted_snap2["requests"].get(d) is not None for d in RUNNER_DIRS
            )
            and interrupted_snap2["generations"]["running"]
            == interrupted_snap2["generations"]["baseline"]
            and rc_rec2 == 0
            and not after_rec2["state"]["runners_closed"]
            and after_rec2["state"]["drain"] is None
            and after_rec2["state"]["verified"] is None
            and all(
                after_rec2["units"][u].get("ActiveState") == "active"
                and before2_invs[u] != after2_invs[u]
                for u in RUNNER_UNITS
            )
            and after_rec2["generations"]["running"]
            == after_rec2["generations"]["baseline"]
            and after_rec2["generations"]["generation"] == 1
        )
        return {
            "scenario": "e",
            "description": "Upgrade interrupted at journal-draining (before marker), right after marker, and right after settled-rollback; recovery reopens all times",
            "passed": part0_ok and part1_ok and part2_ok,
            "part0_before_marker_interrupt": {
                "passed": part0_ok,
                "interrupt_exit_code": rc_int0,
                "interrupted_state": interrupted_snap0["state"],
                "interrupted_requests": interrupted_snap0["requests"],
                "recovery_exit_code": rc_rec0,
                "recovery_log": log_rec0,
                "invocations_before": {
                    u: before_part0["units"][u].get("InvocationID")
                    for u in RUNNER_UNITS
                },
                "invocations_after": {
                    u: after_rec0["units"][u].get("InvocationID") for u in RUNNER_UNITS
                },
            },
            "part1_marker_interrupt": {
                "passed": part1_ok,
                "interrupt_exit_code": rc_int1,
                "interrupted_state": interrupted_snap1["state"],
                "interrupted_requests": interrupted_snap1["requests"],
                "deploy_hold_refused": {
                    "exit_code": hold_res.returncode,
                    "stderr": hold_res.stderr.strip(),
                },
                "recovery_exit_code": rc_rec1,
                "recovery_log": log_rec1,
                "invocations_before": {
                    u: before_part1["units"][u].get("InvocationID")
                    for u in RUNNER_UNITS
                },
                "invocations_after": {
                    u: after_rec1["units"][u].get("InvocationID") for u in RUNNER_UNITS
                },
            },
            "part2_rollback_interrupt": {
                "passed": part2_ok,
                "interrupt_exit_code": rc_int2,
                "interrupt_log": log_int2,
                "interrupted_state": interrupted_snap2["state"],
                "interrupted_requests": interrupted_snap2["requests"],
                "recovery_exit_code": rc_rec2,
                "recovery_log": log_rec2,
                "invocations_before": before2_invs,
                "invocations_after": after2_invs,
            },
            "condition_skips": self.collect_condition_skips(
                before_part2, samples_part2
            ),
            "generations": {
                "before": before_part0["generations"],
                "after_part0": after_rec0["generations"],
                "after_part1": after_rec1["generations"],
                "after_part2": after_rec2["generations"],
            },
            "canary": after_rec2["state"]["verified"],
        }

    def run_scenario_f(self):
        """(f) one runner stays busy past the deadline, the drain defers, and the job completes."""
        log(
            "Scenario (f): starting (one runner stays busy past deadline; drain defers; job completes)..."
        )
        self.reset_to_baseline()
        before = self.get_vm_snapshot()
        nonce = uuid.uuid4().hex[:10]

        self.ssh(
            "rm -f /run/runner-drain-test/boundary-reached && "
            "touch /run/runner-drain-test/hold-boundary"
        )
        self.start_guarded_upgrade_async(
            "scen-f", auto_activate=True, drain_timeout=25, drain_poll=2
        )

        deadline = time.time() + 120
        while time.time() < deadline:
            res = self.ssh(
                "test -f /run/runner-drain-test/boundary-reached && echo READY || true"
            )
            if "READY" in res.stdout:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("scenario (f): timed out waiting for boundary-reached")

        dispatched_at = self.gh.dispatch_workflow(
            "f", nonce, self.label, sleep_seconds=55
        )
        transitions = []

        deadline = time.time() + 120
        while time.time() < deadline:
            self.poll_github_jobs(transitions, created_after=dispatched_at)
            cstate = self.get_counter_state("f", nonce)
            if cstate["started"] >= 1 and cstate["in_progress"]:
                break
            time.sleep(1)
        else:
            raise RuntimeError("scenario (f): timed out waiting for busy job to start")

        self.ssh("rm -f /run/runner-drain-test/hold-boundary")

        samples = []

        def _poll():
            samples.append(self.get_vm_snapshot())
            self.poll_github_jobs(transitions, created_after=dispatched_at)

        rc, out_log = self.wait_guarded_upgrade(
            "scen-f", timeout=180, poll_callback=_poll
        )
        after_defer = self.get_vm_snapshot()
        samples.append(after_defer)
        defer_at = extract_guest_transition_times(after_defer)["cancelling_at"]

        deadline = time.time() + 120
        while time.time() < deadline:
            self.poll_github_jobs(transitions, created_after=dispatched_at)
            counter = self.get_counter_state("f", nonce)
            if counter["completed"] >= 1 and any(
                t.get("status") == "completed" for t in transitions
            ):
                break
            time.sleep(2)
        else:
            raise RuntimeError(
                "scenario (f): timed out waiting for busy job to finish after deferral"
            )

        self.poll_github_jobs(transitions, created_after=dispatched_at)
        after_job = self.get_vm_snapshot()
        self.wait_for_runners_online(require_idle=True, timeout=120)

        completed_events = [
            e for e in counter["events"] if e.get("event") == "completed"
        ]
        completed_at = completed_events[0]["ts"] if completed_events else None
        busy_runner_name = completed_events[0]["runner"] if completed_events else ""
        busy_suffix = busy_runner_name.removeprefix("p620-nixarchy")
        busy_unit = f"github-runner-nixarchy{busy_suffix}.service"
        busy_dir = f"nixarchy{busy_suffix}"
        idle_units = [u for u in RUNNER_UNITS if u != busy_unit]

        before_invs = {u: before["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        after_invs = {
            u: after_defer["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        draining_seen = any(
            isinstance(s["acks"].get(busy_dir), dict)
            and s["acks"][busy_dir].get("state") == "draining"
            for s in samples
        )
        cancelled_seen = any(
            isinstance(s["acks"].get(busy_dir), dict)
            and s["acks"][busy_dir].get("state") == "cancelled"
            for s in [*samples, after_job]
        )
        gh_completed = [t for t in transitions if t.get("status") == "completed"]

        passed = (
            rc == 0
            and "drain incomplete" in out_log
            and counter["started"] == 1
            and counter["completed"] == 1
            and len(gh_completed) == 1
            and gh_completed[0].get("conclusion") == "success"
            and completed_at is not None
            and defer_at is not None
            and completed_at >= defer_at
            and busy_unit in RUNNER_UNITS
            and before_invs[busy_unit] == after_invs[busy_unit]
            and all(before_invs[u] != after_invs[u] for u in idle_units)
            and draining_seen
            and cancelled_seen
            and after_defer["generations"]["running"]
            == after_defer["generations"]["baseline"]
            and after_defer["generations"]["boot"]
            == after_defer["generations"]["baseline"]
            and after_defer["generations"]["generation"] == 1
            and after_defer["state"]["verified"] is None
            and after_defer["state"]["drain"] is None
            and not after_defer["state"]["runners_closed"]
        )
        return {
            "scenario": "f",
            "description": "One runner stays busy past the deadline, the drain defers, and the job completes",
            "passed": passed,
            "exit_code": rc,
            "log": out_log,
            "busy_unit": busy_unit,
            "defer_at": defer_at,
            "completed_at": completed_at,
            "draining_ack_seen": draining_seen,
            "cancelled_ack_seen": cancelled_seen,
            "github_transitions": transitions,
            "execution_counter": counter,
            "invocations": {
                "before": before_invs,
                "after_defer": after_invs,
                "final_acks": after_job["acks"],
            },
            "condition_skips": self.collect_condition_skips(before, samples),
            "generations": {
                "before": before["generations"],
                "after": after_defer["generations"],
            },
            "canary": after_defer["state"]["verified"],
        }


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Run the six-scenario disposable NixOS VM harness for runner drain (nixarchy#1967)."
    )
    parser.add_argument(
        "--repo",
        help="Disposable GitHub repository in OWNER/REPO form (default: $RUNNER_DRAIN_TEST_REPO).",
    )
    parser.add_argument(
        "--token-file",
        help="Path to file containing the GitHub token for the disposable repository.",
    )
    parser.add_argument(
        "--allow-agenix-token-file",
        action="store_true",
        help="Allow reading a token file located under /run/agenix.",
    )
    parser.add_argument(
        "--label",
        default=os.environ.get(
            "RUNNER_DRAIN_TEST_LABEL", f"drain-test-{uuid.uuid4().hex[:8]}"
        ),
        help="Unique runner label for the VM's four runners.",
    )
    parser.add_argument(
        "--vm-script",
        help="Optional path to a pre-built run-p620-vm script.",
    )
    parser.add_argument(
        "--workdir",
        help="Working directory for the VM disk image and shared mount.",
    )
    parser.add_argument(
        "--scenarios",
        default="a,b,c,d,e,f",
        help="Comma-separated list of scenarios to run (default: a,b,c,d,e,f).",
    )
    parser.add_argument(
        "--output",
        default=os.environ.get(
            "RUNNER_DRAIN_TEST_OUTPUT", str(HERE / "recording.json")
        ),
        help="Path to write the JSON recording report.",
    )
    parser.add_argument(
        "--keep-workdir",
        action="store_true",
        help="Keep the temporary VM working directory after completion.",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    repo = resolve_repo_from_env(args.repo)
    token = resolve_token_from_env(
        token_file=args.token_file, allow_agenix=args.allow_agenix_token_file
    )
    scenarios = [s.strip().lower() for s in args.scenarios.split(",") if s.strip()]
    for s in scenarios:
        if s not in ("a", "b", "c", "d", "e", "f"):
            raise ValueError(f"unknown scenario {s!r}; expected a..f")

    base_tmp = (
        Path("/mnt/data/vmtest")
        if Path("/mnt/data/vmtest").is_dir() and os.access("/mnt/data/vmtest", os.W_OK)
        else None
    )
    created_temp = False
    if args.workdir:
        workdir = Path(args.workdir).resolve()
        workdir.mkdir(mode=0o700, parents=True, exist_ok=True)
    else:
        workdir = Path(
            tempfile.mkdtemp(
                prefix="runner-drain-test-",
                dir=str(base_tmp) if base_tmp else None,
            )
        )
        created_temp = True

    harness = VMHarness(
        repo=repo,
        token=token,
        label=args.label,
        workdir=workdir,
        vm_script=args.vm_script,
    )
    results = []
    try:
        log(f"Ensuring workflow is installed in disposable repository {repo}...")
        harness.gh.ensure_workflow_installed()
        harness.start_vm()
        log("Waiting for all 4 VM runners to register and report online...")
        harness.wait_for_runners_online(require_idle=True, timeout=180)

        dispatch_table = {
            "a": harness.run_scenario_a,
            "b": harness.run_scenario_b,
            "c": harness.run_scenario_c,
            "d": harness.run_scenario_d,
            "e": harness.run_scenario_e,
            "f": harness.run_scenario_f,
        }
        for s in scenarios:
            res = dispatch_table[s]()
            results.append(res)
            status = "PASS" if res["passed"] else "FAIL"
            log(f"Scenario ({s}): {status}")
    except Exception:
        # Guest logs live on the VM's tmpfs: copy them out before it stops, or a
        # failure leaves no evidence of what the script under test did.
        with contextlib.suppress(Exception):
            res = harness.ssh(
                "for f in /run/runner-drain-test/*.log /run/runner-drain-test/transitions.json; do "
                '[ -f "$f" ] && { echo "=== $f"; tail -n 80 "$f"; }; done; '
                "echo '=== guarded-upgrade state'; ls -la /var/lib/guarded-upgrade 2>&1; "
                "cat /var/lib/guarded-upgrade/drain 2>&1; "
                "echo '=== journal'; journalctl -n 60 --no-pager 2>&1 | tail -n 60",
                timeout=60,
                check=False,
            )
            (workdir / "guest-on-failure.log").write_text(res.stdout + res.stderr)
            log(f"Guest logs saved to {workdir / 'guest-on-failure.log'}")
        raise
    finally:
        harness.stop_vm()
        if created_temp and not args.keep_workdir:
            shutil.rmtree(workdir, ignore_errors=True)

    all_passed = bool(results) and all(r["passed"] for r in results)
    report = {
        "issue": "nixarchy#1967",
        "repository": repo,
        "runner_label": args.label,
        "recorded_at": datetime.now().isoformat(),
        "all_passed": all_passed,
        "scenarios": results,
    }
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(report, indent=2) + "\n")
    log(f"Wrote scenario recordings to {out_path} (all_passed={all_passed})")
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
