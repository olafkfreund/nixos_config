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
PREPARE = os.path.abspath("modules/programs/claude-guard-prepare.sh")

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
    .replace("${lib.makeBinPath [ pkgs.gnused pkgs.gawk pkgs.coreutils ]}:", "")
    .replace("${./claude-guard-prepare.sh}", PREPARE)
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

CASES += [
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHA1MTA=",
        2,
        "off p510: #3047 blocked: script by bash path",
    ),
    (
        "Li9zY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHJhemVy",
        0,
        "off p510: #3047 blocked: script by ./ path, razer",
    ),
    (
        "L2hvbWUvdS8uY29uZmlnL25peG9zL3NjcmlwdHMvdXBkYXRlLWNvbW1pdC1kZXBsb3kuc2ggcDUxMA==",
        2,
        "off p510: #3047 blocked: script by absolute path",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIC0tbm8tZGVwbG95IHA1MTA=",
        2,
        "off p510: #3047 blocked: script --no-deploy before host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHA1MTAgLS1uby1kZXBsb3k=",
        2,
        "off p510: #3047 blocked: script --no-deploy after host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNo",
        0,
        "off p510: #3047 blocked: script with no host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIDI+JjEgcDUxMA==",
        2,
        "off p510: #3047 blocked: script 2>&1 before host",
    ),
    ("bmhzIDI+JjEgcDUxMA==", 2, "off p510: #3047 blocked: nhs 2>&1 before host"),
    ("J25ocycgcDUxMA==", 2, "off p510: #3047 blocked: single-quoted nhs"),
    ("Im5ocyIgcDUxMA==", 2, "off p510: #3047 blocked: double-quoted nhs"),
    ("YmFzaCAtYyAnbmhzIHA1MTAn", 2, "off p510: #3047 blocked: bash -c nhs"),
    ("KG5ocyBwNTEwKQ==", 2, "off p510: #3047 blocked: nhs in a subshell"),
    ("JChuaHMgcDUxMCk=", 2, "off p510: #3047 blocked: nhs in $()"),
    ("anVzdCAncDUxMCc=", 2, "off p510: #3047 blocked: quoted host recipe"),
    (
        "anVzdCAtbiAiJChzdWRvIG5ocyBwNTEwKSI=",
        2,
        "off p510: #3047 still blocked: dry run wrapping $()",
    ),
    (
        "anVzdCAtbiBgbmhzIHA1MTBg",
        2,
        "off p510: #3047 still blocked: dry run wrapping backticks",
    ),
    ("anVzdCAtZiAtbiBwNTEw", 2, "off p510: #3047 still blocked: -f eats -n"),
    ("c3VkbyBqdXN0IC1uIHA1MTA=", 2, "off p510: #3047 still blocked: sudo before just"),
    (
        "ZW52IFg9MSBqdXN0IC1uIHA1MTA=",
        2,
        "off p510: #3047 still blocked: env before just",
    ),
    (
        "anVzdCAtbiByYXplciAmIGp1c3QgcDUxMA==",
        2,
        "off p510: #3047 still blocked: dry run & real run",
    ),
    (
        "anVzdCAtbiBwNTEwCmp1c3QgcDUxMA==",
        2,
        "off p510: #3047 still blocked: dry run newline real run",
    ),
    (
        "anVzdCAtbiBwNTEwICYmIGp1c3QgcDUxMA==",
        2,
        "off p510: #3047 still blocked: dry run && real run",
    ),
    (
        "anVzdCAtbiBwNTEwIHx8IGp1c3QgcDUxMA==",
        2,
        "off p510: #3047 still blocked: dry run || real run",
    ),
    (
        "anVzdCAtbiBwNTEwOyBqdXN0IHA1MTA=",
        2,
        "off p510: #3047 still blocked: dry run ; real run",
    ),
    (
        "anVzdCAtbiBwNTEwIHwganVzdCBwNTEw",
        2,
        "off p510: #3047 still blocked: dry run | real run",
    ),
    ("anVzdCAtbiByYXplcg==", 0, "off p510: #3047 allowed: -n razer"),
    ("anVzdCAtLWRyeS1ydW4gcDUxMA==", 0, "off p510: #3047 allowed: --dry-run p510"),
    ("anVzdCAtLXNob3cgcDUxMA==", 0, "off p510: #3047 allowed: --show p510"),
    ("anVzdCAtcyByYXplcg==", 0, "off p510: #3047 allowed: -s razer"),
    ("anVzdCAtLWxpc3QgcDUxMA==", 0, "off p510: #3047 allowed: --list p510"),
    ("Rk9PPTEganVzdCAtbiBwNTEw", 0, "off p510: #3047 allowed: NAME=value then -n"),
    ("anVzdCAtZiBKdXN0ZmlsZSAtbiBwNTEw", 0, "off p510: #3047 allowed: -f X then -n"),
    (
        "anVzdCAtbiByYXplcjsganVzdCByYXplcg==",
        0,
        "off p510: #3047 context: dry run then real razer",
    ),
    (
        "Z2l0IGNvbW1pdCAtbSAncnVuIG5ocyBwNTEwIGxhdGVyJw==",
        2,
        "off p510: #3047 documented false positive: prose",
    ),
    (
        "dXBkYXRlLWNvbW1pdC1kZXBsb3lYc2ggcDUxMA==",
        0,
        "off p510: #3047 negative: not the script name",
    ),
    ("bmhzYiBwNTEw", 0, "off p510: #3047 unchanged: nhsb allowed"),
    (
        "anVzdCAtLWV2YWx1YXRlIHA1MTA=",
        2,
        "off p510: #3047 unchanged: --evaluate still blocked",
    ),
    (
        "anVzdCAtLXN1bW1hcnkgcDUxMA==",
        2,
        "off p510: #3047 unchanged: --summary still blocked",
    ),
]

LOCAL_P510 += [
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHA1MTA=",
        2,
        "on p510: #3047 blocked: script by bash path",
    ),
    (
        "Li9zY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHJhemVy",
        2,
        "on p510: #3047 blocked: script by ./ path, razer",
    ),
    (
        "L2hvbWUvdS8uY29uZmlnL25peG9zL3NjcmlwdHMvdXBkYXRlLWNvbW1pdC1kZXBsb3kuc2ggcDUxMA==",
        2,
        "on p510: #3047 blocked: script by absolute path",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIC0tbm8tZGVwbG95IHA1MTA=",
        2,
        "on p510: #3047 blocked: script --no-deploy before host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIHA1MTAgLS1uby1kZXBsb3k=",
        2,
        "on p510: #3047 blocked: script --no-deploy after host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNo",
        2,
        "on p510: #3047 blocked: script with no host",
    ),
    (
        "YmFzaCBzY3JpcHRzL3VwZGF0ZS1jb21taXQtZGVwbG95LnNoIDI+JjEgcDUxMA==",
        2,
        "on p510: #3047 blocked: script 2>&1 before host",
    ),
    ("bmhzIDI+JjEgcDUxMA==", 2, "on p510: #3047 blocked: nhs 2>&1 before host"),
    ("J25ocycgcDUxMA==", 2, "on p510: #3047 blocked: single-quoted nhs"),
    ("Im5ocyIgcDUxMA==", 2, "on p510: #3047 blocked: double-quoted nhs"),
    ("YmFzaCAtYyAnbmhzIHA1MTAn", 2, "on p510: #3047 blocked: bash -c nhs"),
    ("KG5ocyBwNTEwKQ==", 2, "on p510: #3047 blocked: nhs in a subshell"),
    ("JChuaHMgcDUxMCk=", 2, "on p510: #3047 blocked: nhs in $()"),
    ("anVzdCAncDUxMCc=", 2, "on p510: #3047 blocked: quoted host recipe"),
    (
        "anVzdCAtbiAiJChzdWRvIG5ocyBwNTEwKSI=",
        2,
        "on p510: #3047 still blocked: dry run wrapping $()",
    ),
    (
        "anVzdCAtbiBgbmhzIHA1MTBg",
        2,
        "on p510: #3047 still blocked: dry run wrapping backticks",
    ),
    ("anVzdCAtZiAtbiBwNTEw", 2, "on p510: #3047 still blocked: -f eats -n"),
    ("c3VkbyBqdXN0IC1uIHA1MTA=", 2, "on p510: #3047 still blocked: sudo before just"),
    (
        "ZW52IFg9MSBqdXN0IC1uIHA1MTA=",
        2,
        "on p510: #3047 still blocked: env before just",
    ),
    (
        "anVzdCAtbiByYXplciAmIGp1c3QgcDUxMA==",
        2,
        "on p510: #3047 still blocked: dry run & real run",
    ),
    (
        "anVzdCAtbiBwNTEwCmp1c3QgcDUxMA==",
        2,
        "on p510: #3047 still blocked: dry run newline real run",
    ),
    (
        "anVzdCAtbiBwNTEwICYmIGp1c3QgcDUxMA==",
        2,
        "on p510: #3047 still blocked: dry run && real run",
    ),
    (
        "anVzdCAtbiBwNTEwIHx8IGp1c3QgcDUxMA==",
        2,
        "on p510: #3047 still blocked: dry run || real run",
    ),
    (
        "anVzdCAtbiBwNTEwOyBqdXN0IHA1MTA=",
        2,
        "on p510: #3047 still blocked: dry run ; real run",
    ),
    (
        "anVzdCAtbiBwNTEwIHwganVzdCBwNTEw",
        2,
        "on p510: #3047 still blocked: dry run | real run",
    ),
    ("anVzdCAtbiByYXplcg==", 0, "on p510: #3047 allowed: -n razer"),
    ("anVzdCAtLWRyeS1ydW4gcDUxMA==", 0, "on p510: #3047 allowed: --dry-run p510"),
    ("anVzdCAtLXNob3cgcDUxMA==", 0, "on p510: #3047 allowed: --show p510"),
    ("anVzdCAtcyByYXplcg==", 0, "on p510: #3047 allowed: -s razer"),
    ("anVzdCAtLWxpc3QgcDUxMA==", 0, "on p510: #3047 allowed: --list p510"),
    ("Rk9PPTEganVzdCAtbiBwNTEw", 0, "on p510: #3047 allowed: NAME=value then -n"),
    ("anVzdCAtZiBKdXN0ZmlsZSAtbiBwNTEw", 0, "on p510: #3047 allowed: -f X then -n"),
    (
        "anVzdCAtbiByYXplcjsganVzdCByYXplcg==",
        0,
        "on p510: #3047 context: dry run then real razer",
    ),
    (
        "Z2l0IGNvbW1pdCAtbSAncnVuIG5ocyBwNTEwIGxhdGVyJw==",
        2,
        "on p510: #3047 documented false positive: prose",
    ),
    (
        "dXBkYXRlLWNvbW1pdC1kZXBsb3lYc2ggcDUxMA==",
        0,
        "on p510: #3047 negative: not the script name",
    ),
    ("bmhzYiBwNTEw", 0, "on p510: #3047 unchanged: nhsb allowed"),
    (
        "anVzdCAtLWV2YWx1YXRlIHA1MTA=",
        2,
        "on p510: #3047 unchanged: --evaluate still blocked",
    ),
    (
        "anVzdCAtLXN1bW1hcnkgcDUxMA==",
        2,
        "on p510: #3047 unchanged: --summary still blocked",
    ),
]

CASES += [
    (
        "c3NoIHA1MTAgJ2NkIC9ldGMvbml4b3MgJiYgc3VkbyBuaXhvcy1yZWJ1aWxkIHN3aXRjaCc=",
        2,
        "off p510: #3047 review: ssh host then && switch",
    ),
    (
        "c3NoIHA1MTAgImNkIC9ldGMvbml4b3MgJiYgc3VkbyBuaCBvcyBzd2l0Y2ggLiI=",
        2,
        "off p510: #3047 review: ssh host then && nh os switch",
    ),
    (
        "SD1wNTEwICYmIG5ocyAkSA==",
        2,
        "off p510: #3047 review: host in a variable then &&",
    ),
    (
        "anVzdCAtLWp1c3RmaWxlPSJKdXN0ZmlsZSIgcDUxMA==",
        2,
        "off p510: #3047 review: quoted --justfile value",
    ),
    (
        "anVzdCAtZiBqZiAtLXNoZWxsLWFyZyAtbiBwNTEw",
        2,
        "off p510: #3047 review: --shell-arg value looks like -n",
    ),
]

LOCAL_P510 += [
    (
        "c3NoIHA1MTAgJ2NkIC9ldGMvbml4b3MgJiYgc3VkbyBuaXhvcy1yZWJ1aWxkIHN3aXRjaCc=",
        2,
        "on p510: #3047 review: ssh host then && switch",
    ),
    (
        "c3NoIHA1MTAgImNkIC9ldGMvbml4b3MgJiYgc3VkbyBuaCBvcyBzd2l0Y2ggLiI=",
        2,
        "on p510: #3047 review: ssh host then && nh os switch",
    ),
    (
        "SD1wNTEwICYmIG5ocyAkSA==",
        2,
        "on p510: #3047 review: host in a variable then &&",
    ),
    (
        "anVzdCAtLWp1c3RmaWxlPSJKdXN0ZmlsZSIgcDUxMA==",
        2,
        "on p510: #3047 review: quoted --justfile value",
    ),
    (
        "anVzdCAtZiBqZiAtLXNoZWxsLWFyZyAtbiBwNTEw",
        2,
        "on p510: #3047 review: --shell-arg value looks like -n",
    ),
]

CASES += [
    ("dHJ1ZTtuaHMgcDUxMA==", 2, "off p510: #3047 review 2: unspaced ; before nhs"),
    ("dHJ1ZSYmbmhzIHA1MTA=", 2, "off p510: #3047 review 2: unspaced && before nhs"),
    ("dHJ1ZTtyZWJvb3Q=", 0, "off p510: #3047 review 2: unspaced ; before reboot"),
]

LOCAL_P510 += [
    ("dHJ1ZTtuaHMgcDUxMA==", 2, "on p510: #3047 review 2: unspaced ; before nhs"),
    ("dHJ1ZSYmbmhzIHA1MTA=", 2, "on p510: #3047 review 2: unspaced && before nhs"),
    ("dHJ1ZTtyZWJvb3Q=", 0, "on p510: #3047 review 2: unspaced ; before reboot"),
]

CASES += [
    (
        "anVzdCAtbiAtLWNvbW1hbmQgbmhzIHA1MTA=",
        2,
        "off p510: #3047 review 3: --command after -n runs anyway",
    ),
    (
        "anVzdCAtbiAtYyBuaHMgcDUxMA==",
        2,
        "off p510: #3047 review 3: -c after -n runs anyway",
    ),
    (
        "TEFCRUw9InRleHQganVzdCAtbiBwNTEwIiBuaHMgcDUxMA==",
        2,
        "off p510: #3047 review 3: just -n inside a quoted assignment",
    ),
    (
        "anVzdCAtbiBwNTEwIFw7IG5ocyBwNTEw",
        2,
        "off p510: #3047 review 3: backslash in a dry-run line",
    ),
]

LOCAL_P510 += [
    (
        "anVzdCAtbiAtLWNvbW1hbmQgbmhzIHA1MTA=",
        2,
        "on p510: #3047 review 3: --command after -n runs anyway",
    ),
    (
        "anVzdCAtbiAtYyBuaHMgcDUxMA==",
        2,
        "on p510: #3047 review 3: -c after -n runs anyway",
    ),
    (
        "TEFCRUw9InRleHQganVzdCAtbiBwNTEwIiBuaHMgcDUxMA==",
        2,
        "on p510: #3047 review 3: just -n inside a quoted assignment",
    ),
    (
        "anVzdCAtbiBwNTEwIFw7IG5ocyBwNTEw",
        2,
        "on p510: #3047 review 3: backslash in a dry-run line",
    ),
]

CASES += [
    (
        "JCgKanVzdCAtbiBwNTEwKSBuaHMgcDUxMA==",
        2,
        "off p510: #3047 review 4: closing ) of a multiline $( ends a dry run",
    ),
    (
        "YApqdXN0IC1uIHA1MTBgIG5ocyBwNTEw",
        2,
        "off p510: #3047 review 4: closing backtick of a multiline substitution",
    ),
    (
        "anVzdCAtbiBwNTEwID54OyBuaHMgcDUxMA==",
        2,
        "off p510: #3047 review 4: redirect in a dry-run line",
    ),
]

LOCAL_P510 += [
    (
        "JCgKanVzdCAtbiBwNTEwKSBuaHMgcDUxMA==",
        2,
        "on p510: #3047 review 4: closing ) of a multiline $( ends a dry run",
    ),
    (
        "YApqdXN0IC1uIHA1MTBgIG5ocyBwNTEw",
        2,
        "on p510: #3047 review 4: closing backtick of a multiline substitution",
    ),
    (
        "anVzdCAtbiBwNTEwID54OyBuaHMgcDUxMA==",
        2,
        "on p510: #3047 review 4: redirect in a dry-run line",
    ),
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
for g, b64, want, label in (
    [(guard, *c) for c in CASES]
    + [(guard_p510, *c) for c in LOCAL_P510]
    + [(guard_broken, *("bHMgLWxh", 2, "#3047 prepare failure denies (ls -la)"))]
):
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
for f in (guard_p510, guard_broken, broken_prepare):
    os.unlink(f)
print("\nALL PASS" if not fail else f"\n{fail} FAILED")
sys.exit(1 if fail else 0)
