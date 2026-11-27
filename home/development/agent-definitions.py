"""Render .claude/agents/*.md into agy Markdown and Codex TOML (#3267)."""

import json
import os
import re
import sys
import tomllib
from pathlib import Path

import yaml

MARKER = "# managed by nixos_config agent-definitions (#3267)"
TIERS = {"haiku": "flash", "sonnet": "flash", "opus": "pro"}
ROLES = {"haiku": "explorer", "sonnet": "worker", "opus": "reviewer"}


def toml_str(value):
    return json.dumps(value, ensure_ascii=False).replace("\x7f", "\\u007f")


def parse(path):
    lines = path.read_bytes().decode("utf-8").split("\n")
    if lines[0] != "---" or "---" not in lines[1:]:
        sys.exit(f"{path}: frontmatter must open and close with a '---' line")
    end = lines.index("---", 1)
    meta = yaml.safe_load("\n".join(lines[1:end]))
    for key in ("name", "description"):
        if not isinstance(meta, dict) or not isinstance(meta.get(key), str):
            sys.exit(f"{path}: missing string '{key}'")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", meta["name"]):
        sys.exit(f"{path}: invalid name {meta['name']!r}")
    return meta, "\n".join(lines[end + 1 :])


def main():
    src, out = map(Path, sys.argv[1:3])
    roles = json.loads(os.environ["roles"])
    (out / "gemini").mkdir(parents=True, exist_ok=True)
    (out / "codex").mkdir(parents=True, exist_ok=True)
    seen = set()
    for path in sorted(src.glob("*.md")):
        meta, body = parse(path)
        name, description = meta["name"], meta["description"]
        if name in seen:
            sys.exit(f"{path}: duplicate name {name!r}")
        seen.add(name)
        model = meta.get("model")
        model = model if isinstance(model, str) else None

        header = yaml.safe_dump(
            {
                "name": name,
                "description": description,
                "model": TIERS.get(model, "inherit"),
            },
            sort_keys=False,
            allow_unicode=True,
        )
        (out / "gemini" / f"{name}.md").write_bytes(
            f"---\n{MARKER}\n{header}---\n{body}".encode()
        )

        codex = roles[ROLES.get(model, "worker")]["codex"]
        values = {
            "name": name,
            "description": description,
            "developer_instructions": body,
            "model": codex["model"],
            "model_reasoning_effort": codex["effort"],
        }
        text = "".join(f"{key} = {toml_str(value)}\n" for key, value in values.items())
        if tomllib.loads(text) != values:
            sys.exit(f"{path}: TOML does not round-trip")
        (out / "codex" / f"{name}.toml").write_bytes(text.encode())
    if not seen:
        sys.exit(f"{src}: no agent definitions rendered")
    print(f"rendered {len(seen)} agy and {len(seen)} codex agent definitions")


if __name__ == "__main__":
    main()
