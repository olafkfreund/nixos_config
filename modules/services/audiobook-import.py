"""Audiobook import worker.

Scans the configured download dirs for completed, stable audiobook folders,
asks the local Ollama to parse the release name into structured metadata,
(optionally) merges multi-file books into a chaptered M4B with m4b-tool, and
places the result into the Audiobookshelf library under
<Author>/[<Series>/][<index> - ]<Title>/ with an Audiobookshelf metadata.json.

Source files are left in place (hardlinked, not moved) so torrent seeding
continues; a `.imported` marker in each source folder makes runs idempotent.

All configuration comes from environment variables (set by the systemd unit):
  AUDIOBOOK_WATCH_DIRS  colon-separated source dirs
  AUDIOBOOK_LIBRARY_DIR Audiobookshelf library root
  OLLAMA_URL            default http://127.0.0.1:11434
  OLLAMA_MODEL          default qwen2.5:7b
  M4B_TOOL              path to the m4b-tool binary
  MERGE_TO_M4B          "1" to merge multi-file books, else "0"
  STABLE_SECONDS        skip folders modified more recently than this
"""

import json
import os
import pathlib
import re
import shutil
import subprocess
import time
import urllib.request

WATCH_DIRS = [d for d in os.environ.get("AUDIOBOOK_WATCH_DIRS", "").split(":") if d]
LIBRARY = os.environ["AUDIOBOOK_LIBRARY_DIR"]
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/")
MODEL = os.environ.get("OLLAMA_MODEL", "qwen2.5:7b")
M4B_TOOL = os.environ.get("M4B_TOOL", "m4b-tool")
MERGE = os.environ.get("MERGE_TO_M4B", "1") == "1"
STABLE = int(os.environ.get("STABLE_SECONDS", "120"))

AUDIO_EXT = {".mp3", ".m4a", ".m4b", ".flac", ".ogg", ".opus", ".aac", ".wav"}


def log(*a):
    print("[audiobook-import]", *a, flush=True)


def audio_files(folder):
    return [p for p in pathlib.Path(folder).rglob("*") if p.suffix.lower() in AUDIO_EXT]


def newest_mtime(folder):
    newest = 0.0
    for p in pathlib.Path(folder).rglob("*"):
        try:
            newest = max(newest, p.stat().st_mtime)
        except OSError:
            pass
    return newest


def sanitize(value):
    s = re.sub(r'[<>:"/\\|?*\x00-\x1f]', " ", str(value)).strip()
    s = re.sub(r"\s+", " ", s)
    return s[:180] or "Unknown"


def parse_metadata(name):
    schema = {
        "type": "object",
        "properties": {
            "author": {"type": "string"},
            "title": {"type": "string"},
            "series": {"type": "string"},
            "series_index": {"type": "string"},
            "narrator": {"type": "string"},
            "year": {"type": "string"},
        },
        "required": ["author", "title"],
    }
    prompt = (
        "You extract audiobook metadata from a messy release/folder name. "
        "Return author, title, and (if present) series, series_index, narrator, year. "
        "Use an empty string for unknown fields. Do not invent values.\n"
        f"Name: {name!r}"
    )
    payload = json.dumps(
        {
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
            "format": schema,
            "options": {"temperature": 0},
        }
    ).encode()
    meta = {}
    try:
        req = urllib.request.Request(
            OLLAMA_URL + "/api/generate", payload, {"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.load(resp)
        meta = json.loads(data.get("response", "{}"))
        if not isinstance(meta, dict):
            meta = {}
    except Exception as exc:  # noqa: BLE001 - any failure falls back to the raw name
        log("LLM parse failed, falling back to folder name:", exc)

    return {
        "author": sanitize(meta.get("author") or "Unknown Author"),
        "title": sanitize(meta.get("title") or name),
        "series": sanitize(meta["series"]) if meta.get("series") else "",
        "index": (meta.get("series_index") or "").strip(),
        "narrator": (meta.get("narrator") or "").strip(),
        "year": (meta.get("year") or "").strip(),
    }


def target_dir(m):
    parts = [LIBRARY, m["author"]]
    if m["series"]:
        parts.append(m["series"])
        leaf = (f"{m['index']} - " if m["index"] else "") + m["title"]
    else:
        leaf = m["title"]
    parts.append(sanitize(leaf))
    return os.path.join(*parts)


def write_abs_metadata(folder, m):
    md = {"title": m["title"], "authors": [m["author"]]}
    if m["series"]:
        md["series"] = [m["series"] + (f" #{m['index']}" if m["index"] else "")]
    if m["narrator"]:
        md["narrators"] = [m["narrator"]]
    if m["year"]:
        md["publishedYear"] = m["year"]
    with open(os.path.join(folder, "metadata.json"), "w") as fh:
        json.dump(md, fh, indent=2)


def merge_m4b(src, out, m):
    cmd = [
        M4B_TOOL,
        "merge",
        src,
        "-o",
        out,
        "--name",
        m["title"],
        "--artist",
        m["author"],
    ]
    log("merging ->", out)
    return subprocess.run(cmd).returncode == 0


def place_files(files, dest):
    for p in files:
        tgt = os.path.join(dest, p.name)
        if os.path.exists(tgt):
            continue
        try:
            os.link(p, tgt)  # hardlink keeps source intact for seeding
        except OSError:
            shutil.copy2(p, tgt)


def _notify_media_bot(title, author):
    """Best-effort POST to the media-bot webhook on successful import.
    Failure is logged and swallowed — notification down ≠ import down."""
    url = os.environ.get("MEDIA_BOT_URL", "http://localhost:8090/audiobook")
    payload = json.dumps({"title": title, "author": author}).encode()
    try:
        req = urllib.request.Request(url, payload, {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=5):
            pass
    except Exception as exc:  # noqa: BLE001
        log("media-bot notify failed (ignored):", exc)


def process(folder):
    files = audio_files(folder)
    if not files:
        return
    if time.time() - newest_mtime(folder) < STABLE:
        log("still settling, skip:", folder)
        return

    m = parse_metadata(os.path.basename(folder.rstrip("/")))
    dest = target_dir(m)
    os.makedirs(dest, exist_ok=True)

    placed = False
    if MERGE and len(files) > 1:
        out = os.path.join(dest, sanitize(m["title"]) + ".m4b")
        try:
            placed = merge_m4b(folder, out, m)
        except Exception as exc:  # noqa: BLE001
            log("merge error, falling back to copy:", exc)
    if not placed:
        place_files(files, dest)

    write_abs_metadata(dest, m)
    pathlib.Path(os.path.join(folder, ".imported")).touch()
    log("imported:", folder, "->", dest)
    _notify_media_bot(m["title"], m["author"])


def main():
    for wd in WATCH_DIRS:
        if not os.path.isdir(wd):
            continue
        for entry in os.scandir(wd):
            if not entry.is_dir() or entry.name.startswith("."):
                continue
            if os.path.exists(os.path.join(entry.path, ".imported")):
                continue
            try:
                process(entry.path)
            except Exception as exc:  # noqa: BLE001
                log("ERROR processing", entry.path, exc)


if __name__ == "__main__":
    main()
