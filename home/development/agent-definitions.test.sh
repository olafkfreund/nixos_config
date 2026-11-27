#!/usr/bin/env bash
# usage: agent-definitions.test.sh [script [fixtures-dir]]
set -euo pipefail

here=$(dirname "$0")
script=${1:-$here/agent-definitions.py}
fixtures=${2:-$here/agent-definitions-fixtures}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fixed roles, so expectations do not move with agent-team.nix.
export roles='{"reviewer":{"codex":{"model":"m-reviewer","effort":"e-reviewer"}},
"worker":{"codex":{"model":"m-worker","effort":"e-worker"}},
"explorer":{"codex":{"model":"m-explorer","effort":"e-explorer"}}}'

python3 "$script" "$fixtures/good" "$tmp/good"

python3 - "$fixtures/good" "$tmp/good" <<'PY'
import sys, tomllib
from pathlib import Path

import yaml

src, out = map(Path, sys.argv[1:])
multi = "First line.\nSecond line.\n"
expected = {
    "opus": ("Opus agent", "pro", "reviewer"),
    "missing-model": ("No model", "inherit", "worker"),
    "unknown-model": ("Unknown model", "inherit", "worker"),
    "body-dashes": ("Awkward body", "flash", "worker"),
    "multiline": (multi, "flash", "explorer"),
}
assert sorted(p.name for p in (out / "gemini").iterdir()) == sorted(f"{n}.md" for n in expected)
assert sorted(p.name for p in (out / "codex").iterdir()) == sorted(f"{n}.toml" for n in expected)
dashes = (src / "body-dashes.md").read_bytes()
assert all(s in dashes for s in (b"\n---\n\nEmoji", "\U0001f680".encode(), b'"quote"', b"back\\slash", b"\x7f"))
for name, (description, tier, role) in expected.items():
    body = (src / f"{name}.md").read_bytes().split(b"\n---\n", 1)[1]
    agy = (out / "gemini" / f"{name}.md").read_bytes()
    first, marker, rest = agy.split(b"\n", 2)
    assert first == b"---", name
    assert marker == b"# managed by nixos_config agent-definitions (#3267)", name
    header, agy_body = rest.split(b"\n---\n", 1)
    meta = yaml.safe_load(header)
    assert list(meta.items()) == [("name", name), ("description", description), ("model", tier)], meta
    assert agy_body == body, name
    toml = tomllib.loads((out / "codex" / f"{name}.toml").read_text(encoding="utf-8"))
    assert toml == {
        "name": name,
        "description": description,
        "developer_instructions": body.decode(),
        "model": f"m-{role}",
        "model_reasoning_effort": f"e-{role}",
    }, toml
PY

fails() {
  if python3 "$script" "$1" "$tmp/bad" >"$tmp/log" 2>&1; then
    echo "FAIL: $1 rendered" >&2
    exit 1
  fi
  grep -q -- "$2" "$tmp/log" || {
    cat "$tmp/log" >&2
    exit 1
  }
}
fails "$fixtures/bad-unclosed" "must open and close"
fails "$fixtures/bad-no-description" "missing string 'description'"
fails "$fixtures/bad-slash-name" "invalid name"
fails "$fixtures/bad-duplicate" "duplicate name"
mkdir "$tmp/empty"
fails "$tmp/empty" "no agent definitions rendered"

echo "ALL PASSED"
