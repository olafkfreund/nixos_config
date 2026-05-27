"""Generate the auto-mirrored reference section of the docs site.

Run by the mkdocs-gen-files plugin at build time (see mkdocs.yml). It walks
the repository source — modules/, pkgs/, hosts/, lib/, overlays/ — and emits
one in-memory Markdown page per area plus a literate-nav SUMMARY.md. Nothing
is written to disk, so the generated reference never goes stale in git.

Extraction is best-effort and source-of-truth-linked: every page links back
to the exact file on GitHub, and the raw `options` block is shown verbatim
(brace-matched) rather than re-parsed, so we never misrepresent a module.
"""

from __future__ import annotations

import re
from pathlib import Path

import mkdocs_gen_files

REPO_BLOB = "https://github.com/olafkfreund/nixos_config/blob/main"
ROOT = Path(__file__).resolve().parent.parent

nav = mkdocs_gen_files.Nav()

# Human-friendly titles for module categories. Anything not listed falls back
# to a title-cased directory name.
CATEGORY_TITLES = {
    "ai": "AI Providers",
    "cloud": "Cloud",
    "common": "Common",
    "containers": "Containers",
    "desktop": "Desktop",
    "development": "Development",
    "email": "Email",
    "fonts": "Fonts",
    "funny": "Fun",
    "helpers": "Helpers",
    "installer": "Live Installer",
    "microvms": "MicroVMs",
    "networking": "Networking",
    "nix": "Nix Settings",
    "nix-index": "Nix Index",
    "nixos": "NixOS Core",
    "obsidian": "Obsidian",
    "office": "Office",
    "overlays": "Overlay Hooks",
    "packages": "Package Sets",
    "pkgs": "Package Glue",
    "programs": "Programs",
    "scrcpy": "scrcpy",
    "scripts": "Scripts",
    "secrets": "Secrets",
    "security": "Security",
    "services": "Services",
    "spell": "Spell Checking",
    "storage": "Storage",
    "system": "System",
    "system-utils": "System Utilities",
    "virt": "Virtualisation",
    "webcam": "Webcam",
    "windows": "Windows Interop",
}


# --------------------------------------------------------------------------
# Extraction helpers (stdlib + regex only)
# --------------------------------------------------------------------------
def leading_comment(text: str) -> str:
    """Return the top-of-file `#` comment block as prose."""
    lines = []
    for raw in text.splitlines():
        stripped = raw.strip()
        if stripped.startswith("#"):
            lines.append(stripped.lstrip("#").strip())
        elif stripped == "":
            if lines:
                break
            continue
        else:
            break
    # Drop empty trailing/leading entries.
    return "\n".join(lines).strip()


def match_braces(text: str, open_idx: int) -> int:
    """Return index just past the brace that matches the `{` at open_idx.

    Naive depth counter — good enough for Nix option blocks. Returns -1 if
    unbalanced.
    """
    depth = 0
    for i in range(open_idx, len(text)):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
    return -1


def extract_options_block(text: str) -> str | None:
    """Extract the first `options[...] = { ... }` block, verbatim."""
    m = re.search(r"(?m)^\s*options\b[^=\n]*=\s*", text)
    if not m:
        # Some modules write `options = { ... }` or `options.foo.bar = {`.
        return None
    brace = text.find("{", m.end() - 1)
    if brace == -1:
        return None
    end = match_braces(text, brace)
    if end == -1:
        return None
    block = text[m.start() : end]
    return block


def enable_options(text: str) -> list[str]:
    """Return descriptions of any `mkEnableOption "..."` calls."""
    return re.findall(r'mkEnableOption\s+"([^"]+)"', text)


def option_names(block: str) -> list[str]:
    """Best-effort list of declared option leaf names in an options block."""
    names = re.findall(r"(?m)^\s*([A-Za-z_][\w-]*)\s*=\s*mkOption\b", block)
    enable = re.findall(r"(?m)^\s*([A-Za-z_][\w-]*)\s*=\s*mkEnableOption\b", block)
    # Preserve order, dedupe.
    seen = {}
    for n in enable + names:
        seen.setdefault(n, None)
    return list(seen)


def nix_string(text: str, key: str) -> str | None:
    """Extract `key = "value";` (double-quoted) from text."""
    m = re.search(rf'\b{re.escape(key)}\s*=\s*"([^"]*)"', text)
    return m.group(1) if m else None


def truncate_block(block: str, max_lines: int = 90) -> tuple[str, bool]:
    lines = block.splitlines()
    if len(lines) <= max_lines:
        return block, False
    return "\n".join(lines[:max_lines]), True


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def source_link(path: Path) -> str:
    r = rel(path)
    return f"[:material-github: `{r}`]({REPO_BLOB}/{r})"


# --------------------------------------------------------------------------
# modules/  — one page per category, a subsection per .nix file
# --------------------------------------------------------------------------
def render_module_file(out, path: Path) -> None:
    text = path.read_text(errors="replace")
    print(f"### `{path.name}`\n", file=out)
    print(f"{source_link(path)}\n", file=out)

    comment = leading_comment(text)
    if comment:
        print(f"{comment}\n", file=out)

    for desc in enable_options(text):
        print(f"- **Enable option:** {desc}", file=out)
    if enable_options(text):
        print("", file=out)

    block = extract_options_block(text)
    if block:
        names = option_names(block)
        if names:
            joined = ", ".join(f"`{n}`" for n in names)
            print(f"**Options:** {joined}\n", file=out)
        shown, truncated = truncate_block(block)
        print('??? note "Options declaration (Nix)"\n', file=out)
        print("    ```nix", file=out)
        for line in shown.splitlines():
            print(f"    {line}", file=out)
        if truncated:
            print("    # … truncated — see source link above", file=out)
        print("    ```\n", file=out)
    else:
        print("_No option declarations; see source for implementation._\n", file=out)


def gen_modules() -> None:
    modules = ROOT / "modules"
    categories = sorted(p for p in modules.iterdir() if p.is_dir())

    # Category index landing page.
    index_path = "reference/modules/index.md"
    with mkdocs_gen_files.open(index_path, "w") as out:
        print("# Modules\n", file=out)
        print(
            "Feature modules are imported explicitly by the host template and "
            "gated by feature flags. Each category below documents every "
            "`.nix` file it contains, with the raw option declarations and a "
            "link to the source.\n",
            file=out,
        )
        print("| Category | Files | Description |", file=out)
        print("| --- | ---: | --- |", file=out)
        for cat in categories:
            nix_files = sorted(cat.rglob("*.nix"))
            title = CATEGORY_TITLES.get(cat.name, cat.name.replace("-", " ").title())
            print(
                f"| [{title}](./{cat.name}.md) | {len(nix_files)} | "
                f"`modules/{cat.name}/` |",
                file=out,
            )
    nav["Modules", "Overview"] = "modules/index.md"

    for cat in categories:
        title = CATEGORY_TITLES.get(cat.name, cat.name.replace("-", " ").title())
        nix_files = sorted(cat.rglob("*.nix"))
        page = f"reference/modules/{cat.name}.md"
        with mkdocs_gen_files.open(page, "w") as out:
            print(f"# {title}\n", file=out)
            print(f"Source directory: `modules/{cat.name}/`\n", file=out)
            if not nix_files:
                print("_No Nix files in this category._", file=out)
            for nf in nix_files:
                render_module_file(out, nf)
        nav["Modules", title] = f"modules/{cat.name}.md"


# --------------------------------------------------------------------------
# pkgs/  — single sortable table + per-package detail
# --------------------------------------------------------------------------
def package_meta(pkg_dir: Path) -> dict:
    candidates = [pkg_dir / "default.nix"]
    candidates += sorted(pkg_dir.glob("*.nix"))
    text = ""
    used = None
    for c in candidates:
        if c.exists():
            used = c
            text = c.read_text(errors="replace")
            break
    return {
        "name": pkg_dir.name,
        "pname": nix_string(text, "pname") or pkg_dir.name,
        "version": nix_string(text, "version") or "—",
        "description": nix_string(text, "description") or "",
        "homepage": nix_string(text, "homepage") or "",
        "file": used,
    }


def gen_packages() -> None:
    pkgs = ROOT / "pkgs"
    pkg_dirs = sorted(p for p in pkgs.iterdir() if p.is_dir())
    metas = [package_meta(p) for p in pkg_dirs]

    page = "reference/packages.md"
    with mkdocs_gen_files.open(page, "w") as out:
        print("# Custom Packages\n", file=out)
        print(
            f"{len(metas)} packages live under `pkgs/`, wired in through the "
            "overlays. Each is built from source or vendored and exposed to "
            "every host. Packages flagged unfree require "
            "`allowUnfree`.\n",
            file=out,
        )
        print("| Package | Version | Description |", file=out)
        print("| --- | --- | --- |", file=out)
        for m in metas:
            anchor = m["name"].lower().replace(".", "").replace("_", "-")
            desc = m["description"].replace("|", "\\|")
            print(f"| [`{m['name']}`](#{anchor}) | {m['version']} | {desc} |", file=out)
        print("", file=out)

        for m in metas:
            print(f"## {m['name']}\n", file=out)
            if m["file"] is not None:
                print(f"{source_link(m['file'])}\n", file=out)
            rows = [
                ("Package name", f"`{m['pname']}`"),
                ("Version", m["version"]),
            ]
            if m["homepage"]:
                rows.append(("Homepage", f"<{m['homepage']}>"))
            print("| | |", file=out)
            print("| --- | --- |", file=out)
            for k, v in rows:
                print(f"| **{k}** | {v} |", file=out)
            print("", file=out)
            if m["description"]:
                print(f"{m['description']}\n", file=out)
    nav["Packages"] = "packages.md"


# --------------------------------------------------------------------------
# hosts/  — file manifest per host (complements the hand-written host pages)
# --------------------------------------------------------------------------
def gen_hosts() -> None:
    hosts = ROOT / "hosts"
    host_dirs = sorted(
        p
        for p in hosts.iterdir()
        if p.is_dir() and p.name not in ("common", "templates")
    )

    index_path = "reference/hosts/index.md"
    with mkdocs_gen_files.open(index_path, "w") as out:
        print("# Host File Manifests\n", file=out)
        print(
            "Per-host file listings for the curious. For the narrative — what "
            "each machine is for and how to run it — see the "
            "[Hosts](../../hosts/index.md) section.\n",
            file=out,
        )
        print("Shared host scaffolding lives in:", file=out)
        for sub in ("common", "templates"):
            d = hosts / sub
            if d.exists():
                print(f"\n- `hosts/{sub}/`", file=out)
                for f in sorted(d.rglob("*.nix")):
                    print(f"    - {source_link(f)}", file=out)
    nav["Hosts", "Overview"] = "hosts/index.md"

    for hd in host_dirs:
        page = f"reference/hosts/{hd.name}.md"
        with mkdocs_gen_files.open(page, "w") as out:
            print(f"# `hosts/{hd.name}/`\n", file=out)
            variables = hd / "variables.nix"
            if variables.exists():
                print(f"Host variables: {source_link(variables)}\n", file=out)
            print("## Files\n", file=out)
            for f in sorted(hd.rglob("*.nix")):
                comment = leading_comment(f.read_text(errors="replace"))
                first = comment.splitlines()[0] if comment else ""
                print(
                    f"- {source_link(f)}" + (f" — {first}" if first else ""), file=out
                )
        nav["Hosts", hd.name] = f"hosts/{hd.name}.md"


# --------------------------------------------------------------------------
# lib/ and overlays/  — small manifests with leading comments
# --------------------------------------------------------------------------
def gen_simple_dir(dir_name: str, title: str, blurb: str) -> None:
    base = ROOT / dir_name
    if not base.exists():
        return
    page = f"reference/{dir_name}.md"
    with mkdocs_gen_files.open(page, "w") as out:
        print(f"# {title}\n", file=out)
        print(f"{blurb}\n", file=out)
        for f in sorted(base.rglob("*.nix")):
            print(f"## `{f.relative_to(base).as_posix()}`\n", file=out)
            print(f"{source_link(f)}\n", file=out)
            comment = leading_comment(f.read_text(errors="replace"))
            if comment:
                print(f"{comment}\n", file=out)
    nav[title] = f"{dir_name}.md"


# --------------------------------------------------------------------------
# Drive everything + write the literate-nav SUMMARY.
# --------------------------------------------------------------------------
gen_modules()
gen_packages()
gen_hosts()
gen_simple_dir(
    "lib",
    "Library Functions",
    "Helper functions and builders consumed by the flake: feature system, "
    "host types, secrets wiring, live-image builders, and validation.",
)
gen_simple_dir(
    "overlays",
    "Overlays",
    "Overlays are split by purpose. They inject the custom `pkgs/` packages "
    "and apply upstream fixes and compatibility shims.",
)

with mkdocs_gen_files.open("reference/SUMMARY.md", "w") as nav_file:
    nav_file.writelines(nav.build_literate_nav())
