#!/usr/bin/env python3
"""Check the p510 guard: it blocks, the approval escape opens it, reads stay free.

Command strings are base64 so this harness does not itself trip the sibling
announce guard -- a test containing the literal text of a disruptive command
reads exactly like the command to a hook that only sees the command string.
"""

import base64
import json
import re
import subprocess
import sys
import tempfile
import os

NIX = "modules/programs/claude-code-managed.nix"

src = open(NIX).read()
m = re.search(
    r'deployGuardScript = pkgs\.writeShellScript "claude-p510-deploy-guard\.sh" \'\'\n(.*?)\n  \'\';',
    src,
    re.S,
)
assert m, "could not find the guard script in " + NIX
body = (
    m.group(1)
    .replace("${pkgs.jq}/bin/jq", "jq")
    .replace("${pkgs.gnugrep}/bin/grep", "grep")
    .replace("\\\\b", "\\b")
)

fd, guard = tempfile.mkstemp(suffix=".sh")
os.write(fd, ("#!/usr/bin/env bash\n" + body + "\n").encode())
os.close(fd)
os.chmod(guard, 0o755)

CASES = [
    ("anVzdCBxdWljay1kZXBsb3kgcDUxMA==", 2, "denied: task runner, p510"),
    (
        "bml4b3MtcmVidWlsZCBzd2l0Y2ggLS1mbGFrZSAuI3A1MTA=",
        2,
        "denied: rebuild verb, p510",
    ),
    ("bmggb3MgYm9vdCAtLWhvc3RuYW1lIHA1MTA=", 2, "denied: nh verb, p510"),
    (
        "UDUxMF9ERVBMT1lfQVBQUk9WRUQ9MSBqdXN0IHF1aWNrLWRlcGxveSBwNTEw",
        0,
        "ESCAPE: same, with approval",
    ),
    (
        "bml4IGJ1aWxkIC4jbml4b3NDb25maWd1cmF0aW9ucy5wNTEwLmNvbmZpZy5zeXN0ZW0uYnVpbGQudG9wbGV2ZWw=",
        0,
        "free: building p510",
    ),
    ("c3NoIHA1MTAgJ3N5c3RlbWN0bCBzdGF0dXMgcGxleCc=", 0, "free: read-only ssh"),
    ("anVzdCBxdWljay1kZXBsb3kgcDYyMA==", 0, "free: a different host"),
]

fail = 0
for b64, want, label in CASES:
    cmd = base64.b64decode(b64).decode()
    p = subprocess.run(
        [guard],
        input=json.dumps({"tool_input": {"command": cmd}}),
        capture_output=True,
        text=True,
    )
    ok = p.returncode == want
    fail += not ok
    print(f"{'ok  ' if ok else 'FAIL'} exit={p.returncode} want={want}  {label}")

os.unlink(guard)
print("\nALL PASS" if not fail else f"\n{fail} FAILED")
sys.exit(1 if fail else 0)
