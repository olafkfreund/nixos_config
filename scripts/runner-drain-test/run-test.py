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
import ast
import base64
import contextlib
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid


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
        if value.startswith(prefix):
            value = value[len(prefix) :]
    if value.endswith(".git"):
        value = value[:-4]
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

    for var in (
        "RUNNER_DRAIN_TEST_TOKEN",
        "DISPOSABLE_GITHUB_TOKEN",
        "DRAIN_TEST_TOKEN",
        "GH_TOKEN",
        "GITHUB_TOKEN",
    ):
        val = os.environ.get(var, "").strip()
        if val:
            return val

    fallback_file = os.environ.get("GITHUB_TOKEN_FILE", "").strip()
    if fallback_file:
        path = Path(fallback_file)
        resolved = str(path.resolve()) if path.exists() else str(path)
        if not allow_agenix and (
            fallback_file.startswith("/run/agenix")
            or resolved.startswith("/run/agenix")
        ):
            raise RuntimeError(
                "GITHUB_TOKEN_FILE points to /run/agenix; provide a disposable token via "
                "RUNNER_DRAIN_TEST_TOKEN or RUNNER_DRAIN_TEST_TOKEN_FILE"
            )
        token = path.read_text().strip()
        if token:
            return token

    raise RuntimeError(
        "disposable GitHub token not found; set RUNNER_DRAIN_TEST_TOKEN or RUNNER_DRAIN_TEST_TOKEN_FILE"
    )


def _literal_value(node):
    if node is None:
        return None
    try:
        return ast.literal_eval(node)
    except Exception:
        return None


def _extract_env_lookups(source_text):
    """Return list of (env_key, default_value, uses_json) discovered in a Python script."""
    tree = ast.parse(source_text)
    parent_map = {}
    for parent in ast.walk(tree):
        for child in ast.iter_child_nodes(parent):
            parent_map[child] = parent

    def parent_uses_json(node):
        cur = node
        for _ in range(4):
            cur = parent_map.get(cur)
            if cur is None:
                break
            if isinstance(cur, ast.Call):
                func_src = ast.unparse(cur.func) if hasattr(ast, "unparse") else ""
                if "json.loads" in func_src:
                    return True
        return False

    discovered = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and node.args:
            func_str = ast.unparse(node.func) if hasattr(ast, "unparse") else ""
            if func_str in ("os.environ.get", "os.getenv", "environ.get", "getenv"):
                key = _literal_value(node.args[0])
                default = _literal_value(node.args[1]) if len(node.args) > 1 else None
                if isinstance(key, str):
                    discovered.append((key, default, parent_uses_json(node)))
        elif isinstance(node, ast.Subscript):
            val_str = ast.unparse(node.value) if hasattr(ast, "unparse") else ""
            if val_str in ("os.environ", "environ"):
                key = _literal_value(node.slice)
                if isinstance(key, str):
                    discovered.append((key, None, parent_uses_json(node)))
    return discovered


def _format_repo_for_default(repo, default_val, key_upper):
    _, name = repo.split("/", 1)
    if isinstance(default_val, str) and default_val:
        if default_val.startswith("github:"):
            return f"github:{repo}"
        if default_val.startswith("https://") or default_val.startswith("http://"):
            suffix = ".git" if default_val.endswith(".git") else ""
            return f"https://github.com/{repo}{suffix}"
        if "/" in default_val:
            return repo
        return name
    if "FLAK" in key_upper or key_upper.endswith("_REF"):
        return f"github:{repo}"
    if "URL" in key_upper or "GIT" in key_upper:
        return f"https://github.com/{repo}.git"
    return repo


def _format_workflows_for_default(workflow_file, job_name, default_val, uses_json):
    if uses_json:
        return json.dumps([[workflow_file, job_name]])
    if isinstance(default_val, str):
        if not default_val.strip():
            return f"{workflow_file}:{job_name}"
        if default_val.strip().startswith("["):
            return json.dumps([[workflow_file, job_name]])
        first_item = default_val.split(",")[0].strip()
        for sep in (":", "/", "="):
            if sep in first_item:
                return f"{workflow_file}{sep}{job_name}"
    return f"{workflow_file}:{job_name}"


def discover_guarded_upgrade_env(
    source_text,
    repo,
    runner_unit_prefix="github-runner-nixarchy",
    runner_name_prefix="p620-nixarchy",
    workflow_file="drain-test.yml",
    job_name="drain-test",
    window_hour=4,
    bus_room="#runner-drain-test:localhost",
    token_file="/run/runner-drain-test/github-token",
    drain_timeout=None,
    drain_poll=None,
):
    """Build the environment dictionary for guarded_upgrade.py from both standard
    variable names and AST analysis of scripts/guarded_upgrade.py."""
    _, repo_short = repo.split("/", 1)
    env = {
        "GITHUB_TOKEN_FILE": token_file,
        "GUARDED_UPGRADE_REPO": f"github:{repo}",
        "GUARDED_UPGRADE_CONFIG_REPO": repo,
        "GUARDED_UPGRADE_NIXOS_REPO": repo,
        "GUARDED_UPGRADE_RUNNER_REPO": repo,
        "GUARDED_UPGRADE_CI_REPO": repo,
        "GUARDED_UPGRADE_NIXARCHY_REPO": repo,
        "GUARDED_UPGRADE_GIT_REPO": f"https://github.com/{repo}.git",
        "GUARDED_UPGRADE_RUNNER_UNIT_PREFIX": runner_unit_prefix,
        "GUARDED_UPGRADE_RUNNER_NAME_PREFIX": runner_name_prefix,
        "GUARDED_UPGRADE_RUNNER_PREFIX": runner_name_prefix,
        "GUARDED_UPGRADE_UNIT_PREFIX": runner_unit_prefix,
        "GUARDED_UPGRADE_WORKFLOWS": f"{workflow_file}:{job_name}",
        "GUARDED_UPGRADE_CI_WORKFLOWS": f"{workflow_file}:{job_name}",
        "GUARDED_UPGRADE_WINDOW": str(window_hour),
        "GUARDED_UPGRADE_WINDOW_HOUR": str(window_hour),
        "GUARDED_UPGRADE_BUS_ROOM": bus_room,
        "AGENT_BUS_ROOM": bus_room,
    }
    if drain_timeout is not None:
        env["GUARDED_UPGRADE_DRAIN_TIMEOUT"] = str(drain_timeout)
        env["GUARDED_UPGRADE_DRAIN_SECONDS"] = str(drain_timeout)
    if drain_poll is not None:
        env["GUARDED_UPGRADE_DRAIN_POLL"] = str(drain_poll)
        env["GUARDED_UPGRADE_POLL_SECONDS"] = str(drain_poll)

    for key, default_val, uses_json in _extract_env_lookups(source_text):
        ku = key.upper()
        default_str = str(default_val) if default_val is not None else ""
        if key == "GITHUB_TOKEN_FILE":
            env[key] = token_file
        elif key == "STAGE_KEY_FILE":
            continue
        elif "WINDOW" in ku or "HOUR" in ku or default_val in (4, "4", "04"):
            env[key] = str(window_hour)
        elif "BUS" in ku or "ROOM" in ku or "#agents:" in default_str:
            env[key] = bus_room
        elif (
            "WORKFLOW" in ku
            or "install-check.yml" in default_str
            or "omarchy-edge.yml" in default_str
        ):
            env[key] = _format_workflows_for_default(
                workflow_file, job_name, default_val, uses_json
            )
        elif "UNIT" in ku or "SERVICE" in ku or default_val == "github-runner-nixarchy":
            if (
                isinstance(default_val, str)
                and default_val
                and not default_val.startswith("github-runner-")
            ):
                env[key] = runner_unit_prefix.removeprefix("github-runner-")
            else:
                env[key] = runner_unit_prefix
        elif (
            "RUNNER" in ku and ("NAME" in ku or "PREFIX" in ku)
        ) or default_val == "p620-nixarchy":
            env[key] = runner_name_prefix
        elif (
            "REPO" in ku
            or "nixos_config" in default_str
            or default_val in ("nixarchy", "olafkfreund/nixarchy")
        ):
            env[key] = _format_repo_for_default(repo, default_val, ku)
        elif drain_timeout is not None and (
            "TIMEOUT" in ku or "DEADLINE" in ku or default_val in (1800, "1800")
        ):
            env[key] = str(drain_timeout)
        elif drain_poll is not None and (
            "POLL" in ku or "INTERVAL" in ku or default_val in (15, "15")
        ):
            env[key] = str(drain_poll)
        elif default_val == "nixarchy":
            env[key] = repo_short

    return env


class GitHubClient:
    def __init__(self, repo, token):
        self.repo = repo
        self._token = token

    def request(self, path, method="GET", body=None, expected=(200, 201, 204)):
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
exec "$REAL_GIT" "${args[@]}"
"""

GUEST_LOGINCTL_WRAPPER = """\
#!/usr/bin/env bash
set -euo pipefail
REAL_LOGINCTL="@REAL_LOGINCTL@"
if [[ "${1:-}" == "list-sessions" ]] \
  && [[ -f /run/runner-drain-test/hold-boundary ]] \
  && [[ -L /var/lib/guarded-upgrade/stage-razer ]] \
  && [[ ! -f /var/lib/guarded-upgrade/runners-closed ]]; then
  touch /run/runner-drain-test/boundary-reached
  while [[ -f /run/runner-drain-test/hold-boundary ]]; do
    sleep 0.05
  done
fi
exec "$REAL_LOGINCTL" "$@"
"""

GUEST_SYSTEMCTL_WRAPPER = """\
#!/usr/bin/env bash
set -euo pipefail
REAL_SYSTEMCTL="@REAL_SYSTEMCTL@"
if [[ -f /run/runner-drain-test/interrupt-after-marker ]] \
  && [[ -f /var/lib/guarded-upgrade/runners-closed ]]; then
  rm -f /run/runner-drain-test/interrupt-after-marker
  touch /run/runner-drain-test/interrupted-after-marker
  kill -9 "$PPID" 2>/dev/null || true
  exit 137
fi
if [[ -f /run/runner-drain-test/interrupt-after-rollback ]] \
  && [[ "${1:-}" == "start" ]] \
  && [[ -f /var/lib/guarded-upgrade/last-failure ]]; then
  rm -f /run/runner-drain-test/interrupt-after-rollback
  touch /var/lib/guarded-upgrade/runners-closed
  touch /run/runner-drain-test/interrupted-after-rollback
  kill -9 "$PPID" 2>/dev/null || true
  exit 137
fi
if [[ "${1:-}" == "start" && "${2:-}" == github-runner-nixarchy* ]] \
  && [[ -f /var/lib/guarded-upgrade/runners-closed ]]; then
  printf '%s %s\\n' "$(date -Is)" "$*" >> /var/lib/runner-drain-test/closed-start-attempts.log
fi
exec "$REAL_SYSTEMCTL" "$@"
"""

GUEST_RUNNER_LAUNCHER = """\
#!/usr/bin/env python3
import ast
import os
from pathlib import Path
import sys

script_path = Path(sys.argv[1]).resolve()
host = sys.argv[2]
auto_activate = sys.argv[3]
deadline_override = os.environ.get("RUNNER_DRAIN_TEST_DEADLINE_OVERRIDE")
poll_override = os.environ.get("RUNNER_DRAIN_TEST_POLL_OVERRIDE")

source = script_path.read_text()
tree = ast.parse(source, filename=str(script_path))

if deadline_override or poll_override:
    d_val = int(deadline_override) if deadline_override else None
    p_val = int(poll_override) if poll_override else None

    class _TimingTransformer(ast.NodeTransformer):
        def visit_BinOp(self, node):
            self.generic_visit(node)
            if (
                d_val is not None
                and isinstance(node.op, ast.Mult)
                and isinstance(node.left, ast.Constant)
                and isinstance(node.right, ast.Constant)
                and {node.left.value, node.right.value} == {30, 60}
            ):
                return ast.copy_location(ast.Constant(value=d_val), node)
            return node

        def visit_Constant(self, node):
            if d_val is not None and node.value == 1800:
                return ast.copy_location(ast.Constant(value=d_val), node)
            if p_val is not None and node.value == 15:
                return ast.copy_location(ast.Constant(value=p_val), node)
            return node

    tree = ast.fix_missing_locations(_TimingTransformer().visit(tree))

sys.path.insert(0, str(script_path.parent))
sys.argv = [str(script_path), host, auto_activate]
code = compile(tree, str(script_path), "exec")
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
        res = subprocess.run(cmd, cwd=str(REPO_ROOT), text=True, capture_output=True)
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
        res = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
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
        (self.shared_dir / "loginctl.wrapper").write_text(GUEST_LOGINCTL_WRAPPER)
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
real_loginctl="$(command -v loginctl)"
real_systemctl="$(command -v systemctl)"

sed "s|@REAL_NIX@|$real_nix|g" /tmp/shared/nix.wrapper > /run/runner-drain-test/bin/nix
sed -e "s|@REAL_GIT@|$real_git|g" -e "s|@DISPOSABLE_REPO@|{self.repo}|g" /tmp/shared/git.wrapper > /run/runner-drain-test/bin/git
sed "s|@REAL_LOGINCTL@|$real_loginctl|g" /tmp/shared/loginctl.wrapper > /run/runner-drain-test/bin/loginctl
sed "s|@REAL_SYSTEMCTL@|$real_systemctl|g" /tmp/shared/systemctl.wrapper > /run/runner-drain-test/bin/systemctl
chmod 0755 /run/runner-drain-test/bin/nix /run/runner-drain-test/bin/git /run/runner-drain-test/bin/loginctl /run/runner-drain-test/bin/systemctl
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
rm -f /run/runner-drain-test/interrupt-after-marker /run/runner-drain-test/interrupt-after-rollback
rm -f /var/lib/guarded-upgrade/pause /var/lib/guarded-upgrade/drain /var/lib/guarded-upgrade/runners-closed
rm -f /var/lib/guarded-upgrade/transaction /var/lib/guarded-upgrade/rollback-root
for d in nixarchy nixarchy-2 nixarchy-3 nixarchy-4; do
  rm -f "/var/lib/github-runner/$d/drain/request"
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
        probe = """\
python3 - <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess

units = [
    "github-runner-nixarchy.service",
    "github-runner-nixarchy-2.service",
    "github-runner-nixarchy-3.service",
    "github-runner-nixarchy-4.service",
]
dirs = ["nixarchy", "nixarchy-2", "nixarchy-3", "nixarchy-4"]

unit_info = {}
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

acks = {}
requests = {}
for d in dirs:
    ack_p = Path(f"/var/lib/github-runner/{d}/drain/ack")
    req_p = Path(f"/var/lib/github-runner/{d}/drain/request")
    if ack_p.exists():
        try:
            acks[d] = json.loads(ack_p.read_text())
        except Exception:
            acks[d] = {"raw": ack_p.read_text()}
    else:
        acks[d] = None
    if req_p.exists():
        try:
            requests[d] = json.loads(req_p.read_text())
        except Exception:
            requests[d] = {"raw": req_p.read_text()}
    else:
        requests[d] = None

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
    txt = p.read_text().strip()
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

snapshot = {
    "units": unit_info,
    "acks": acks,
    "requests": requests,
    "generations": {
        "running": str(Path("/run/current-system").resolve()),
        "boot": str(profile.resolve()) if profile.exists() else None,
        "generation": gen_num,
        "baseline": Path("/var/lib/runner-drain-test/baseline-path").read_text().strip(),
        "candidate": Path("/var/lib/runner-drain-test/candidate-path").read_text().strip(),
    },
    "state": {
        "runners_closed": (state_dir / "runners-closed").exists(),
        "verified": read_json_or_text(state_dir / "verified"),
        "drain": read_json_or_text(state_dir / "drain"),
        "pause": read_json_or_text(state_dir / "pause"),
        "last_failure": read_json_or_text(state_dir / "last-failure"),
        "transaction": read_json_or_text(state_dir / "transaction"),
    },
    "condition_skip_journal": skip_lines,
}
print(json.dumps(snapshot))
PY
"""
        res = self.ssh(probe, timeout=30)
        return json.loads(res.stdout)

    def get_counter_state(self, scenario, nonce):
        key = f"{scenario}-{nonce}"
        probe = f"""\
python3 - <<'PY'
import json
from pathlib import Path

cdir = Path("/var/lib/runner-drain-test/counters")
key = {key!r}
s_file = cdir / f"{{key}}.started.count"
d_file = cdir / f"{{key}}.completed.count"
e_file = cdir / f"{{key}}.events.jsonl"
ip_file = cdir / f"{{key}}.in_progress"

events = []
if e_file.exists():
    for line in e_file.read_text().splitlines():
        if line.strip():
            events.append(json.loads(line))

print(json.dumps({{
    "started": int(s_file.read_text().strip()) if s_file.exists() else 0,
    "completed": int(d_file.read_text().strip()) if d_file.exists() else 0,
    "in_progress": ip_file.exists(),
    "events": events,
}}))
PY
"""
        res = self.ssh(probe, timeout=20)
        return json.loads(res.stdout)

    def build_guest_env_exports(self, drain_timeout=None, drain_poll=2):
        hour_res = self.ssh("date +%-H", timeout=10)
        guest_hour = int(hour_res.stdout.strip())
        source_text = GUARDED_UPGRADE_SCRIPT.read_text()
        env_map = discover_guarded_upgrade_env(
            source_text=source_text,
            repo=self.repo,
            runner_unit_prefix="github-runner-nixarchy",
            runner_name_prefix="p620-nixarchy",
            workflow_file="drain-test.yml",
            job_name="drain-test",
            window_hour=guest_hour,
            bus_room="#runner-drain-test:localhost",
            token_file="/run/runner-drain-test/github-token",
            drain_timeout=drain_timeout,
            drain_poll=drain_poll,
        )
        env_map["PYTHONPATH"] = "/run/runner-drain-test/py"
        if drain_timeout is not None:
            env_map["RUNNER_DRAIN_TEST_DEADLINE_OVERRIDE"] = str(drain_timeout)
        if drain_poll is not None:
            env_map["RUNNER_DRAIN_TEST_POLL_OVERRIDE"] = str(drain_poll)
        exports = ['export PATH="/run/runner-drain-test/bin:$PATH"']
        for k, v in sorted(env_map.items()):
            quoted = "'" + str(v).replace("'", "'\\''") + "'"
            exports.append(f"export {k}={quoted}")
        return "\n".join(exports)

    def start_guarded_upgrade_async(
        self, run_tag, auto_activate=True, drain_timeout=300, drain_poll=2
    ):
        exports = self.build_guest_env_exports(
            drain_timeout=drain_timeout, drain_poll=drain_poll
        )
        act_str = "true" if auto_activate else "false"
        script = f"""\
set -euo pipefail
{exports}
rm -f /run/runner-drain-test/{run_tag}.rc /run/runner-drain-test/{run_tag}.log
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
        """Extract condition skip evidence across all snapshots where runners_closed was true."""
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
                if u.get("ConditionResult") == "no" or (
                    snap["state"]["runners_closed"] and cur_ts > before_ts
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
        """(a) a job acquired at the boundary completes exactly once, before the switch."""
        log("Scenario (a): starting (boundary job completes once before switch)...")
        self.reset_to_baseline()
        before = self.get_vm_snapshot()
        nonce = uuid.uuid4().hex[:10]

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

        self.gh.dispatch_workflow("a", nonce, self.label, sleep_seconds=15)

        deadline = time.time() + 120
        while time.time() < deadline:
            cstate = self.get_counter_state("a", nonce)
            if cstate["started"] >= 1 and cstate["in_progress"]:
                break
            time.sleep(1)
        else:
            raise RuntimeError(
                "scenario (a): timed out waiting for boundary job to start"
            )

        self.ssh("rm -f /run/runner-drain-test/hold-boundary")

        samples = []
        switch_observed_at = None

        def _poll():
            nonlocal switch_observed_at
            snap = self.get_vm_snapshot()
            samples.append(snap)
            drain_state = snap["state"]["drain"]
            if (
                switch_observed_at is None
                and isinstance(drain_state, dict)
                and drain_state.get("phase") in ("switching", "settled-commit")
            ) or (
                switch_observed_at is None
                and snap["generations"]["running"] == snap["generations"]["candidate"]
            ):
                switch_observed_at = int(time.time())

        rc, out_log = self.wait_guarded_upgrade(
            "scen-a", timeout=360, poll_callback=_poll
        )
        after = self.get_vm_snapshot()
        samples.append(after)
        counter = self.get_counter_state("a", nonce)
        self.wait_for_runners_online(require_idle=True, timeout=120)

        completed_events = [
            e for e in counter["events"] if e.get("event") == "completed"
        ]
        completed_at = completed_events[0]["ts"] if completed_events else None
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
            and counter["started"] == 1
            and counter["completed"] == 1
            and completed_at is not None
            and (switch_observed_at is None or completed_at <= switch_observed_at)
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
            "description": "Job acquired at the boundary completes exactly once, before the switch",
            "passed": passed,
            "exit_code": rc,
            "log": out_log,
            "execution_counter": counter,
            "completed_at": completed_at,
            "switch_observed_at": switch_observed_at,
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
                admission_closed_at = int(time.time())
                canary_invalidated_during_drain = snap["state"]["verified"] is None
                break
            time.sleep(0.5)
        else:
            raise RuntimeError(
                "scenario (b): timed out waiting for runners-closed marker"
            )

        dispatched_at = int(
            self.gh.dispatch_workflow("b", nonce, self.label, sleep_seconds=5)
        )
        started_while_closed = False

        def _poll():
            nonlocal started_while_closed
            snap = self.get_vm_snapshot()
            samples.append(snap)
            if snap["state"]["runners_closed"]:
                cstate = self.get_counter_state("b", nonce)
                if cstate["started"] > 0:
                    started_while_closed = True

        rc, out_log = self.wait_guarded_upgrade(
            "scen-b", timeout=360, poll_callback=_poll
        )
        reopened_at = int(time.time())
        after_upgrade = self.get_vm_snapshot()
        samples.append(after_upgrade)

        deadline = time.time() + 180
        while time.time() < deadline:
            counter = self.get_counter_state("b", nonce)
            if counter["completed"] >= 1:
                break
            time.sleep(2)
        else:
            raise RuntimeError(
                "scenario (b): timed out waiting for queued job to complete after reopen"
            )

        self.wait_for_runners_online(require_idle=True, timeout=120)
        after = self.get_vm_snapshot()
        before_invs = {u: before["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        after_invs = {
            u: after_upgrade["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        condition_skips = self.collect_condition_skips(before, samples)

        passed = (
            rc == 0
            and admission_closed_at is not None
            and canary_invalidated_during_drain
            and not started_while_closed
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
            "admission_closed_at": admission_closed_at,
            "dispatched_at": dispatched_at,
            "reopened_at": reopened_at,
            "canary_invalidated_during_drain": canary_invalidated_during_drain,
            "started_while_closed": started_while_closed,
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
                admission_closed_at = int(time.time())
                break
            time.sleep(0.5)
        else:
            raise RuntimeError(
                "scenario (c): timed out waiting for runners-closed marker"
            )

        dispatched_at = int(
            self.gh.dispatch_workflow("c", nonce, self.label, sleep_seconds=5)
        )
        started_while_closed = False

        def _poll():
            nonlocal started_while_closed
            snap = self.get_vm_snapshot()
            samples.append(snap)
            if snap["state"]["runners_closed"]:
                cstate = self.get_counter_state("c", nonce)
                if cstate["started"] > 0:
                    started_while_closed = True

        rc, out_log = self.wait_guarded_upgrade(
            "scen-c", timeout=360, poll_callback=_poll
        )
        after_rollback = self.get_vm_snapshot()
        samples.append(after_rollback)

        deadline = time.time() + 180
        while time.time() < deadline:
            counter = self.get_counter_state("c", nonce)
            if counter["completed"] >= 1:
                break
            time.sleep(2)
        else:
            raise RuntimeError(
                "scenario (c): timed out waiting for queued job to complete after rollback reopen"
            )

        self.ssh(
            "rm -f /etc/runner-drain-test/force-verify-fail /var/lib/guarded-upgrade/pause"
        )
        self.wait_for_runners_online(require_idle=True, timeout=120)

        before_invs = {u: before["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        after_invs = {
            u: after_rollback["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        condition_skips = self.collect_condition_skips(before, samples)

        passed = (
            rc != 0
            and admission_closed_at is not None
            and not started_while_closed
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
            "admission_closed_at": admission_closed_at,
            "dispatched_at": dispatched_at,
            "started_while_closed": started_while_closed,
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
        """(d) one runner withholds its acknowledgement, and the switch defers without stopping it."""
        log(
            "Scenario (d): starting (one runner withholds ack; switch defers without stopping it)..."
        )
        self.reset_to_baseline()
        before = self.get_vm_snapshot()
        withholding_unit = "github-runner-nixarchy-4.service"
        other_units = [u for u in RUNNER_UNITS if u != withholding_unit]
        pid4 = before["units"][withholding_unit]["MainPID"]
        inv4_before = before["units"][withholding_unit]["InvocationID"]

        self.ssh(
            f"mkdir -p /var/lib/github-runner/nixarchy-4/drain && "
            f"nsenter -t {pid4} -m -- mount -t tmpfs tmpfs /var/lib/github-runner/nixarchy-4/drain"
        )
        samples = []
        try:
            self.start_guarded_upgrade_async(
                "scen-d", auto_activate=True, drain_timeout=25, drain_poll=2
            )

            def _poll():
                samples.append(self.get_vm_snapshot())

            rc, out_log = self.wait_guarded_upgrade(
                "scen-d", timeout=180, poll_callback=_poll
            )
            after = self.get_vm_snapshot()
            samples.append(after)
        finally:
            self.ssh(
                f"nsenter -t {pid4} -m -- umount /var/lib/github-runner/nixarchy-4/drain || true",
                check=False,
            )

        self.wait_for_runners_online(require_idle=True, timeout=120)
        before_invs = {u: before["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        after_invs = {u: after["units"][u].get("InvocationID") for u in RUNNER_UNITS}
        pid4_after = after["units"][withholding_unit].get("MainPID")
        inv4_after = after["units"][withholding_unit].get("InvocationID")

        passed = (
            rc == 0
            and "drain incomplete" in out_log
            and inv4_before == inv4_after
            and pid4 == pid4_after
            and after["units"][withholding_unit].get("ActiveState") == "active"
            and all(
                before_invs[u] != after_invs[u]
                and after["units"][u].get("ActiveState") == "active"
                for u in other_units
            )
            and after["generations"]["running"] == after["generations"]["baseline"]
            and after["generations"]["boot"] == after["generations"]["baseline"]
            and after["generations"]["generation"] == 1
            and after["state"]["verified"] is None
            and after["state"]["drain"] is None
            and not after["state"]["runners_closed"]
        )
        return {
            "scenario": "d",
            "description": "One runner withholds its acknowledgement, and the switch defers without stopping it",
            "passed": passed,
            "exit_code": rc,
            "log": out_log,
            "withholding_unit": {
                "unit": withholding_unit,
                "before_invocation": inv4_before,
                "after_invocation": inv4_after,
                "before_pid": pid4,
                "after_pid": pid4_after,
                "unstopped": inv4_before == inv4_after and pid4 == pid4_after,
            },
            "invocations": {
                "before": before_invs,
                "after": after_invs,
                "final_acks": after["acks"],
            },
            "condition_skips": self.collect_condition_skips(before, samples),
            "generations": {
                "before": before["generations"],
                "after": after["generations"],
            },
            "canary": after["state"]["verified"],
        }

    def run_scenario_e(self):
        """(e) the upgrade is interrupted right after the marker is written, then again
        after the rollback, and recovery reopens both times."""
        log(
            "Scenario (e): starting (interrupt after marker -> recovery reopens; interrupt after rollback -> recovery reopens)..."
        )
        self.reset_to_baseline()
        before_part1 = self.get_vm_snapshot()

        self.ssh(
            "rm -f /run/runner-drain-test/interrupted-after-marker && "
            "touch /run/runner-drain-test/interrupt-after-marker"
        )
        pid1 = self.start_guarded_upgrade_async(
            "scen-e-int1", auto_activate=True, drain_timeout=300, drain_poll=2
        )
        self.ssh(
            f"for _ in $(seq 1 600); do "
            f"  if [ -f /var/lib/guarded-upgrade/runners-closed ]; then "
            f"    rm -f /run/runner-drain-test/interrupt-after-marker; "
            f"    touch /run/runner-drain-test/interrupted-after-marker; "
            f"    kill -9 {pid1} 2>/dev/null || true; "
            f"    break; "
            f"  fi; "
            f"  sleep 0.1; "
            f"done",
            timeout=90,
        )
        rc_int1, _ = self.wait_guarded_upgrade("scen-e-int1", timeout=60)
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

        before_part2 = self.get_vm_snapshot()
        self.ssh(
            "rm -f /run/runner-drain-test/interrupted-after-rollback && "
            "touch /etc/runner-drain-test/force-verify-fail /run/runner-drain-test/interrupt-after-rollback"
        )
        self.start_guarded_upgrade_async(
            "scen-e-int2", auto_activate=True, drain_timeout=300, drain_poll=2
        )
        samples_part2 = []

        def _poll2():
            samples_part2.append(self.get_vm_snapshot())

        rc_int2, log_int2 = self.wait_guarded_upgrade(
            "scen-e-int2", timeout=360, poll_callback=_poll2
        )
        interrupted_snap2 = self.get_vm_snapshot()

        self.start_guarded_upgrade_async(
            "scen-e-rec2", auto_activate=False, drain_timeout=120, drain_poll=2
        )
        rc_rec2, log_rec2 = self.wait_guarded_upgrade("scen-e-rec2", timeout=180)
        self.ssh(
            "rm -f /etc/runner-drain-test/force-verify-fail /var/lib/guarded-upgrade/pause"
        )
        self.wait_for_runners_online(require_idle=True, timeout=180)
        after_rec2 = self.get_vm_snapshot()

        part1_ok = (
            interrupted_snap1["state"]["runners_closed"]
            and isinstance(interrupted_snap1["state"]["drain"], dict)
            and interrupted_snap1["state"]["drain"].get("phase") == "draining"
            and hold_res.returncode != 0
            and "drain" in (hold_res.stdout + hold_res.stderr).lower()
            and not after_rec1["state"]["runners_closed"]
            and after_rec1["state"]["drain"] is None
            and all(
                after_rec1["units"][u].get("ActiveState") == "active"
                for u in RUNNER_UNITS
            )
        )
        before2_invs = {
            u: before_part2["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        after2_invs = {
            u: after_rec2["units"][u].get("InvocationID") for u in RUNNER_UNITS
        }
        part2_ok = (
            interrupted_snap2["state"]["runners_closed"]
            and isinstance(interrupted_snap2["state"]["drain"], dict)
            and interrupted_snap2["state"]["drain"].get("phase") == "settled-rollback"
            and interrupted_snap2["generations"]["running"]
            == interrupted_snap2["generations"]["baseline"]
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
            "description": "Upgrade interrupted right after marker is written, then again after rollback, and recovery reopens both times",
            "passed": part1_ok and part2_ok,
            "part1_marker_interrupt": {
                "passed": part1_ok,
                "interrupt_exit_code": rc_int1,
                "interrupted_state": interrupted_snap1["state"],
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
                "recovery_exit_code": rc_rec2,
                "recovery_log": log_rec2,
                "invocations_before": before2_invs,
                "invocations_after": after2_invs,
            },
            "condition_skips": self.collect_condition_skips(
                before_part2, samples_part2
            ),
            "generations": {
                "before": before_part1["generations"],
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

        self.gh.dispatch_workflow("f", nonce, self.label, sleep_seconds=55)

        deadline = time.time() + 120
        while time.time() < deadline:
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

        rc, out_log = self.wait_guarded_upgrade(
            "scen-f", timeout=180, poll_callback=_poll
        )
        defer_at = int(time.time())
        after_defer = self.get_vm_snapshot()
        samples.append(after_defer)

        deadline = time.time() + 120
        while time.time() < deadline:
            counter = self.get_counter_state("f", nonce)
            if counter["completed"] >= 1:
                break
            time.sleep(2)
        else:
            raise RuntimeError(
                "scenario (f): timed out waiting for busy job to finish after deferral"
            )

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

        passed = (
            rc == 0
            and "drain incomplete" in out_log
            and counter["started"] == 1
            and counter["completed"] == 1
            and completed_at is not None
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
