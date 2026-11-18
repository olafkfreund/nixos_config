"""Usage: compare-guards.py MAIN_NIX MAIN_PREPARE BRANCH_NIX BRANCH_PREPARE (run from the branch checkout).
Every suite command through main's and the branch's guards, each with its own prepare; print where the branch is more permissive."""

import base64
import json
import os
import re
import subprocess
import sys
import tempfile

main_nix, main_prep, branch_nix, branch_prep = (
    sys.argv[1],
    os.path.abspath(sys.argv[2]),
    sys.argv[3],
    os.path.abspath(sys.argv[4]),
)


def guard(src, name, on_p510, prepare):
    m = re.search(
        name + r' = pkgs\.writeShellScript "[^"]+" \'\'\n(.*?)\n  \'\';', src, re.S
    )
    assert m
    body = (
        m.group(1)
        .replace("${pkgs.jq}/bin/jq", "jq")
        .replace("${pkgs.gnugrep}/bin/grep", "grep")
        .replace("${lib.makeBinPath [ pkgs.gnused pkgs.gawk pkgs.coreutils ]}:", "")
        .replace("${./claude-guard-prepare.sh}", prepare)
        .replace("\\\\b", "\\b")
    )
    if on_p510:
        body = body.replace("cat /proc/sys/kernel/hostname", "echo p510")
    fd, p = tempfile.mkstemp(suffix=".sh")
    os.write(fd, ("#!/usr/bin/env bash\n" + body + "\n").encode())
    os.close(fd)
    os.chmod(p, 0o755)
    return p


def run(g, c):
    return subprocess.run(
        [g],
        input=json.dumps({"tool_input": {"command": c}}),
        capture_output=True,
        text=True,
    ).returncode


cmds = set()
for f in ("scripts/test-bus-guard.py", "scripts/test-p510-deploy-guard.py"):
    for b in re.findall(r'"([A-Za-z0-9+/=]{4,})",\s*\n?\s*[02],', open(f).read()):
        try:
            cmds.add(base64.b64decode(b).decode())
        except Exception:
            pass
ctx = {}
for label, src, prepare in (
    ("main", open(main_nix).read(), main_prep),
    ("branch", open(branch_nix).read(), branch_prep),
):
    ctx[label] = {
        "bus": guard(src, "busAnnounceScript", False, prepare),
        "p510-off": guard(src, "deployGuardScript", False, prepare),
        "p510-on": guard(src, "deployGuardScript", True, prepare),
    }
print(len(cmds), "commands")
for c in sorted(cmds):
    for k in ("bus", "p510-off", "p510-on"):
        a, b = run(ctx["main"][k], c), run(ctx["branch"][k], c)
        if b < a:
            print(f"looser {k:9} main={a} branch={b}  {c!r}")
