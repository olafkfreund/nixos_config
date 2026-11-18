#!/usr/bin/env python3
"""Check the bus-announce hook: disruptive commands need the announcement, reads stay free (#2951).

Command strings are base64 so this harness does not itself trip the live hook it tests.
"""

import base64
import json
import os
import re
import subprocess
import sys
import tempfile

NIX = "modules/programs/claude-code-managed.nix"
PREPARE = os.path.abspath("modules/programs/claude-guard-prepare.sh")

src = open(NIX).read()
m = re.search(
    r'busAnnounceScript = pkgs\.writeShellScript "claude-bus-announce-guard\.sh" \'\'\n(.*?)\n  \'\';',
    src,
    re.S,
)
assert m, "could not find the bus hook in " + NIX
body = (
    m.group(1)
    .replace("${pkgs.jq}/bin/jq", "jq")
    .replace("${pkgs.gnugrep}/bin/grep", "grep")
    .replace("${lib.makeBinPath [ pkgs.gnused pkgs.gawk pkgs.coreutils ]}:", "")
    .replace("${./claude-guard-prepare.sh}", PREPARE)
)

fd, guard = tempfile.mkstemp(suffix=".sh")
os.write(fd, ("#!/usr/bin/env bash\n" + body + "\n").encode())
os.close(fd)
os.chmod(guard, 0o755)

CASES = [
    ("anVzdCBnYw==", 2, "denied: gc"),
    ("anVzdCAtLWp1c3RmaWxlIEp1c3RmaWxlIGdj", 2, "denied: --justfile then gc"),
    ("anVzdCBHRU5FUkFUSU9OUz0zIGdj", 2, "denied: NAME=value then gc"),
    ("QUdFTlRfQlVTX0FOTk9VTkNFRD0xIGp1c3QgZ2M=", 0, "ESCAPE: gc announced"),
    ("anVzdCBjbGVhbnVw", 2, "denied: cleanup"),
    (
        "anVzdCAtLWp1c3RmaWxlIEp1c3RmaWxlIGNsZWFudXA=",
        2,
        "denied: --justfile then cleanup",
    ),
    ("anVzdCBHRU5FUkFUSU9OUz0zIGNsZWFudXA=", 2, "denied: NAME=value then cleanup"),
    (
        "QUdFTlRfQlVTX0FOTk9VTkNFRD0xIGp1c3QgY2xlYW51cA==",
        0,
        "ESCAPE: cleanup announced",
    ),
    ("anVzdCBib290LXNwYWNlLWNsZWFu", 2, "denied: boot-space-clean"),
    (
        "anVzdCAtLWp1c3RmaWxlIEp1c3RmaWxlIGJvb3Qtc3BhY2UtY2xlYW4=",
        2,
        "denied: --justfile then boot-space-clean",
    ),
    (
        "anVzdCBHRU5FUkFUSU9OUz0zIGJvb3Qtc3BhY2UtY2xlYW4=",
        2,
        "denied: NAME=value then boot-space-clean",
    ),
    (
        "QUdFTlRfQlVTX0FOTk9VTkNFRD0xIGp1c3QgYm9vdC1zcGFjZS1jbGVhbg==",
        0,
        "ESCAPE: boot-space-clean announced",
    ),
    ("anVzdCBmaXgtYWdlbml4LXJlbW90ZQ==", 2, "denied: fix-agenix-remote"),
    (
        "anVzdCAtLWp1c3RmaWxlIEp1c3RmaWxlIGZpeC1hZ2VuaXgtcmVtb3Rl",
        2,
        "denied: --justfile then fix-agenix-remote",
    ),
    (
        "anVzdCBHRU5FUkFUSU9OUz0zIGZpeC1hZ2VuaXgtcmVtb3Rl",
        2,
        "denied: NAME=value then fix-agenix-remote",
    ),
    (
        "QUdFTlRfQlVTX0FOTk9VTkNFRD0xIGp1c3QgZml4LWFnZW5peC1yZW1vdGU=",
        0,
        "ESCAPE: fix-agenix-remote announced",
    ),
    ("anVzdCBwNTEwLWNsZWFyLXNlc3Npb25z", 2, "denied: p510-clear-sessions"),
    (
        "anVzdCAtLWp1c3RmaWxlIEp1c3RmaWxlIHA1MTAtY2xlYXItc2Vzc2lvbnM=",
        2,
        "denied: --justfile then p510-clear-sessions",
    ),
    (
        "anVzdCBHRU5FUkFUSU9OUz0zIHA1MTAtY2xlYXItc2Vzc2lvbnM=",
        2,
        "denied: NAME=value then p510-clear-sessions",
    ),
    (
        "QUdFTlRfQlVTX0FOTk9VTkNFRD0xIGp1c3QgcDUxMC1jbGVhci1zZXNzaW9ucw==",
        0,
        "ESCAPE: p510-clear-sessions announced",
    ),
    ("anVzdCB1cGRhdGU=", 2, "denied: update"),
    (
        "anVzdCAtLWp1c3RmaWxlIEp1c3RmaWxlIHVwZGF0ZQ==",
        2,
        "denied: --justfile then update",
    ),
    ("anVzdCBHRU5FUkFUSU9OUz0zIHVwZGF0ZQ==", 2, "denied: NAME=value then update"),
    ("QUdFTlRfQlVTX0FOTk9VTkNFRD0xIGp1c3QgdXBkYXRl", 0, "ESCAPE: update announced"),
    (
        "anVzdCBxdWljay1kZXBsb3kgcDYyMA==",
        2,
        "denied: existing deploy recipe still caught",
    ),
    ("anVzdCBwNjIw", 2, "denied: existing host recipe still caught"),
    ("anVzdCBib290LXNwYWNl", 0, "free: boot-space (prefix of a guarded name)"),
    ("anVzdCB1cGRhdGUtY29tbWl0", 0, "free: update-commit (guarded name is its prefix)"),
    ("anVzdCBjaGVjay11cGRhdGVz", 0, "free: check-updates"),
    ("anVzdCBzdGF0dXM=", 0, "free: status"),
    ("anVzdCB0ZXN0LWhvc3QgcDYyMA==", 0, "free: test-host"),
    ("anVzdCAtLWxpc3Q=", 0, "free: --list"),
    ("anVzdCBnYzsgZWNobyBvaw==", 2, "denied: name then ;"),
    ("KGp1c3QgdXBkYXRlKQ==", 2, "denied: in a subshell"),
    ("anVzdCBnY3x0ZWUgeA==", 2, "denied: name then |"),
    ("anVzdCAtLWp1c3RmaWxlPUp1c3RmaWxlIGdj", 2, "denied: --justfile=X"),
    ("anVzdCAtcSBnYw==", 2, "denied: -q flag"),
    ("anVzdCAtZCAuIGdj", 2, "denied: -d X"),
    ("anVzdCBwNjIwOyB0cnVl", 2, "denied: host recipe then ;"),
    ("anVzdCB1cGRhdGUtY29tbWl0OyB0cnVl", 0, "free: update-commit then ;"),
]

CASES += [
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHA1MTA=",
        2,
        "#3047 blocked: script by bash path",
    ),
    (
        "Li9zY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHJhemVy",
        2,
        "#3047 blocked: script by ./ path, razer",
    ),
    (
        "L2hvbWUvdS8uY29uZmlnL25peG9zL3NjcmlwdHMvdXBkYXRlLWNvbW1pdC1kZXBsb3kuc2ggcDUxMA==",
        2,
        "#3047 blocked: script by absolute path",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIC0tbm8tZGVwbG95IHA1MTA=",
        2,
        "#3047 blocked: script --no-deploy before host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHA1MTAgLS1uby1kZXBsb3k=",
        2,
        "#3047 blocked: script --no-deploy after host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNo",
        2,
        "#3047 blocked: script with no host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIDI+JjEgcDUxMA==",
        2,
        "#3047 blocked: script 2>&1 before host",
    ),
    ("bmhzIDI+JjEgcDUxMA==", 2, "#3047 blocked: nhs 2>&1 before host"),
    ("J25ocycgcDUxMA==", 2, "#3047 blocked: single-quoted nhs"),
    ("Im5ocyIgcDUxMA==", 2, "#3047 blocked: double-quoted nhs"),
    ("YmFzaCAtYyAnbmhzIHA1MTAn", 2, "#3047 blocked: bash -c nhs"),
    ("KG5ocyBwNTEwKQ==", 2, "#3047 blocked: nhs in a subshell"),
    ("JChuaHMgcDUxMCk=", 2, "#3047 blocked: nhs in $()"),
    ("anVzdCAncDUxMCc=", 2, "#3047 blocked: quoted host recipe"),
    (
        "anVzdCAtbiAiJChzdWRvIG5ocyBwNTEwKSI=",
        2,
        "#3047 still blocked: dry run wrapping $()",
    ),
    ("anVzdCAtbiBgbmhzIHA1MTBg", 2, "#3047 still blocked: dry run wrapping backticks"),
    ("anVzdCAtZiAtbiBwNTEw", 2, "#3047 still blocked: -f eats -n"),
    ("c3VkbyBqdXN0IC1uIHA1MTA=", 2, "#3047 still blocked: sudo before just"),
    ("ZW52IFg9MSBqdXN0IC1uIHA1MTA=", 2, "#3047 still blocked: env before just"),
    (
        "anVzdCAtbiByYXplciAmIGp1c3QgcDUxMA==",
        2,
        "#3047 still blocked: dry run & real run",
    ),
    (
        "anVzdCAtbiBwNTEwCmp1c3QgcDUxMA==",
        2,
        "#3047 still blocked: dry run newline real run",
    ),
    (
        "anVzdCAtbiBwNTEwICYmIGp1c3QgcDUxMA==",
        2,
        "#3047 still blocked: dry run && real run",
    ),
    (
        "anVzdCAtbiBwNTEwIHx8IGp1c3QgcDUxMA==",
        2,
        "#3047 still blocked: dry run || real run",
    ),
    ("anVzdCAtbiBwNTEwOyBqdXN0IHA1MTA=", 2, "#3047 still blocked: dry run ; real run"),
    ("anVzdCAtbiBwNTEwIHwganVzdCBwNTEw", 2, "#3047 still blocked: dry run | real run"),
    ("anVzdCAtbiByYXplcg==", 0, "#3047 allowed: -n razer"),
    ("anVzdCAtLWRyeS1ydW4gcDUxMA==", 0, "#3047 allowed: --dry-run p510"),
    ("anVzdCAtLXNob3cgcDUxMA==", 0, "#3047 allowed: --show p510"),
    ("anVzdCAtcyByYXplcg==", 0, "#3047 allowed: -s razer"),
    ("anVzdCAtLWxpc3QgcDUxMA==", 0, "#3047 allowed: --list p510"),
    ("Rk9PPTEganVzdCAtbiBwNTEw", 0, "#3047 allowed: NAME=value then -n"),
    ("anVzdCAtZiBKdXN0ZmlsZSAtbiBwNTEw", 0, "#3047 allowed: -f X then -n"),
    (
        "anVzdCAtbiByYXplcjsganVzdCByYXplcg==",
        2,
        "#3047 context: dry run then real razer",
    ),
    (
        "Z2l0IGNvbW1pdCAtbSAncnVuIG5ocyBwNTEwIGxhdGVyJw==",
        2,
        "#3047 documented false positive: prose",
    ),
    (
        "dXBkYXRlLWNvbW1pdC1kZXBsb3lYc2ggcDUxMA==",
        0,
        "#3047 negative: not the script name",
    ),
    ("bmhzYiBwNTEw", 0, "#3047 unchanged: nhsb allowed"),
    ("anVzdCAtLWV2YWx1YXRlIHA1MTA=", 2, "#3047 unchanged: --evaluate still blocked"),
    ("anVzdCAtLXN1bW1hcnkgcDUxMA==", 2, "#3047 unchanged: --summary still blocked"),
]

# A guard whose prepare step fails must deny, not allow (#3047).
fd, broken_prepare = tempfile.mkstemp(suffix=".sh")
os.write(fd, b"guard_prepare() { return 1; }\n")
os.close(fd)
fd, guard_broken = tempfile.mkstemp(suffix=".sh")
os.write(
    fd,
    ("#!/usr/bin/env bash\n" + body.replace(PREPARE, broken_prepare) + "\n").encode(),
)
os.close(fd)
os.chmod(guard_broken, 0o755)

fail = 0
for g, b64, want, label in [(guard, *c) for c in CASES] + [
    (guard_broken, *("bHMgLWxh", 2, "#3047 prepare failure denies (ls -la)"))
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

for f in (guard, guard_broken, broken_prepare):
    os.unlink(f)
print("\nALL PASS" if not fail else f"\n{fail} FAILED")
sys.exit(1 if fail else 0)
