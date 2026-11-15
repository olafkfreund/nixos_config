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

# The same guard as it behaves when the hook runs on p510 itself.
fd, guard_p510 = tempfile.mkstemp(suffix=".sh")
os.write(
    fd,
    (
        "#!/usr/bin/env bash\n"
        + body.replace("cat /proc/sys/kernel/hostname", "echo p510")
        + "\n"
    ).encode(),
)
os.close(fd)
os.chmod(guard_p510, 0o755)

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
    ("anVzdCBwNTEwLWNsZWFyLXNlc3Npb25z", 2, "denied: p510 session clearing"),
    ("anVzdCBib290LXNwYWNlLWNsZWFuIHA1MTA=", 2, "denied: boot pruning on p510"),
    ("anVzdCBmaXgtYWdlbml4LXJlbW90ZSBwNTEw", 2, "denied: agenix reset on p510"),
    (
        "anVzdCAtZiBKdXN0ZmlsZSBHRU5FUkFUSU9OUz0xIGJvb3Qtc3BhY2UtY2xlYW4gcDUxMA==",
        2,
        "denied: same behind options",
    ),
    (
        "UDUxMF9ERVBMT1lfQVBQUk9WRUQ9MSBqdXN0IGJvb3Qtc3BhY2UtY2xlYW4gcDUxMA==",
        0,
        "ESCAPE: boot pruning with approval",
    ),
    ("anVzdCBib290LXNwYWNlLWNsZWFuIHJhemVy", 0, "free: boot pruning on another host"),
    ("anVzdCBib290LXNwYWNlIHA1MTA=", 0, "free: read-only boot-space on p510"),
    (
        "anVzdCBmaXgtYWdlbml4LXJlbW90ZSBvbGFma2ZyZXVuZEBwNTEw",
        2,
        "denied: agenix reset, user@p510",
    ),
    (
        "anVzdCBib290LXNwYWNlLWNsZWFuICJwNTEwIg==",
        2,
        "denied: boot pruning, quoted p510",
    ),
    ("anVzdCBwNTEwLWNsZWFyLXNlc3Npb25zOyB0cnVl", 2, "denied: session clearing then ;"),
    ("anVzdCAtLWp1c3RmaWxlPUp1c3RmaWxlIHA1MTA=", 2, "denied: --justfile=X then p510"),
    ("anVzdCAtZCAuIHF1aWNrLWRlcGxveSBwNTEw", 2, "denied: -d X then deploy p510"),
]

CASES += [
    ("anVzdCB1cGRhdGU=", 0, "off p510: local update not a p510 deploy"),
]

LOCAL_P510 = [
    ("anVzdCB1cGRhdGU=", 2, "on p510: local update denied"),
    (
        "QUdFTlRfQlVTX0FOTk9VTkNFRD0xIGp1c3QgdXBkYXRl",
        2,
        "on p510: announcing is not approval",
    ),
    ("anVzdCBkZXBsb3k=", 2, "on p510: local deploy denied"),
    ("anVzdCBnYw==", 2, "on p510: local GC denied"),
    ("bmggb3Mgc3dpdGNoIC4=", 2, "on p510: nh switch with no host denied"),
    (
        "UDUxMF9ERVBMT1lfQVBQUk9WRUQ9MSBqdXN0IHVwZGF0ZQ==",
        0,
        "on p510: ESCAPE with approval",
    ),
    ("anVzdCBzdGF0dXM=", 0, "on p510: status free"),
    ("anVzdCB0ZXN0LWhvc3QgcDYyMA==", 0, "on p510: building another host free"),
]

fail = 0
for g, b64, want, label in [(guard, *c) for c in CASES] + [
    (guard_p510, *c) for c in LOCAL_P510
]:
    cmd = base64.b64decode(b64).decode()
    p = subprocess.run(
        [g],
        input=json.dumps({"tool_input": {"command": cmd}}),
        capture_output=True,
        text=True,
    )
    ok = p.returncode == want
    fail += not ok
    print(f"{'ok  ' if ok else 'FAIL'} exit={p.returncode} want={want}  {label}")

os.unlink(guard)
os.unlink(guard_p510)
print("\nALL PASS" if not fail else f"\n{fail} FAILED")
sys.exit(1 if fail else 0)
