#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import re
import subprocess
from pathlib import Path

prepare = Path("modules/programs/claude-guard-prepare.sh").read_text()
recipes = json.loads(subprocess.check_output(["just", "--dump", "--dump-format", "json"]))["recipes"]
safe = {}
for line in prepare.splitlines():
    if line.strip().startswith('safe["'):
        names = re.findall(r'safe\["([^"]+)"\]', line)
        count = int(re.search(r'= ([0-9]+)$', line).group(1))
        safe.update({name: count for name in names})

assert safe, "no safe recipes found in guard prepare"
for name, count in safe.items():
    assert name in recipes, f"missing recipe: {name}"
    actual = len(recipes[name]["parameters"])
    assert actual == count, f"{name}: guard allows {count} arguments, recipe has {actual}"
print(f"safe recipe arities passed ({len(safe)})")
PY
