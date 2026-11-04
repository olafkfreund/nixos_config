"""Speak a short summary of an agent's finished turn, unless anything says not to.

The Stop hook of Claude Code and Codex calls `agent-say hook <agent>`, which
saves the payload and starts `agent-say run <agent>` as a transient user unit,
so the agent is never kept waiting on Ollama or on audio.

Every silence gate fails closed: a gate that cannot be read counts as "held".
A held line in the journal names the gate. The reply itself is never logged.
"""

import contextlib
import errno
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
import urllib.error
import uuid
from datetime import datetime
from pathlib import Path

CONFIG = Path("/etc/agent-say/config.json")
DEFAULTS = {
    "voiceId": "pFZP5JQG7iQjIQuC4Bku",
    "ollamaUrl": "http://127.0.0.1:11434",
    "model": "qwen3:14b",
    "backend": "ollama",
    "elevenLabsKeyFile": None,
    "minTurnSeconds": 60,
    "startEnabled": True,
    "speaker": "agent-say",
    "microphoneGate": {
        "enable": True,
        "ignore": ["Echo-Cancel Capture", "Echo-Cancel Sink", "parecord"],
    },
}
# What the transient unit must be told, since it does not inherit the agent's env.
ENV_KEYS = (
    "CLAUDE_CODE_ENTRYPOINT",
    "AGY_CODER",
    "CODEX_CODER",
    "AGENT_SAY_QUIET",
    "TMUX",
    "CLAUDECODE",
)
DELEGATED = ("AGY_CODER", "CODEX_CODER", "AGENT_SAY_QUIET")

SHORT = (
    "Summarise the assistant message below as 2-3 calm spoken sentences: what was done and "
    "whether anything needs the user. No code, paths, hashes, commands or markdown."
)
LONG = (
    "Retell the assistant message below as about 45 seconds of plain speech: what was done, "
    "what was found and whether anything needs the user. No code, paths, hashes, commands or markdown."
)


def log(msg):
    print(f"agent-say: {msg}", file=sys.stderr, flush=True)


def config():
    cfg = dict(DEFAULTS)
    with contextlib.suppress(OSError, ValueError):
        cfg.update(json.loads(CONFIG.read_text()))
    return cfg


def state_dir():
    return (
        Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
        / "agent-say"
    )


def run_dir():
    return Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "agent-say"


def nixi_ready(agent):
    """Return (state, reason, port, tool token); only absence permits fallback."""
    path = (
        Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
        / "nixi-companion/runtime.json"
    )
    try:
        runtime = json.loads(path.read_text())
        port, tool_token = runtime["port"], runtime["tool_token"]
        if (
            not isinstance(port, int)
            or isinstance(port, bool)
            or not 1 <= port <= 65535
        ):
            raise ValueError("invalid port")
        if not isinstance(tool_token, str) or not tool_token:
            raise ValueError("invalid tool token")
    except FileNotFoundError:
        return "absent", "runtime missing", None, None
    except (OSError, ValueError, KeyError, TypeError) as e:
        return "no", f"runtime unavailable: {type(e).__name__}", None, None
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/api/agent-say/ready",
        json.dumps({"from": agent}).encode(),
        {"Content-Type": "application/json", "X-Nixi-Token": tool_token},
    )
    try:
        with urllib.request.urlopen(req, timeout=2) as response:
            result = json.load(response)
        if result.get("speak") is True:
            return "go", None, port, tool_token
        return "no", result.get("reason", "ready refused"), port, tool_token
    except urllib.error.HTTPError as e:
        return (
            ("absent" if e.code == 404 else "no"),
            f"ready HTTP {e.code}",
            port,
            tool_token,
        )
    except urllib.error.URLError as e:
        if (
            isinstance(e.reason, ConnectionRefusedError)
            or getattr(e.reason, "errno", None) == errno.ECONNREFUSED
        ):
            return "absent", "connection refused", port, tool_token
        return "no", f"ready failed: {type(e.reason).__name__}", port, tool_token
    except (OSError, ValueError, TypeError, AttributeError) as e:
        return "no", f"ready failed: {type(e).__name__}", port, tool_token


# -- gates: each returns None when clear, else its name ------------------------


def gate_switch(cfg):
    sd = state_dir()
    if (sd / "off").exists() or not (cfg["startEnabled"] or (sd / "on").exists()):
        return "switch"


def set_switch(state):
    sd = state_dir()
    sd.mkdir(parents=True, exist_ok=True)
    (sd / state).touch()
    (sd / ("on" if state == "off" else "off")).unlink(missing_ok=True)


def gate_dnd(cfg):
    try:
        r = subprocess.run(
            ["omarchy-shell", "notifications", "isDnd"],
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return "dnd"
    if r.stdout.strip() != "off":
        return "dnd"


def gate_quiet(cfg):
    path = Path.home() / ".local/state/omarchy/notifications/quiet.json"
    try:
        q = json.loads(path.read_text())
        if not isinstance(q, dict):
            return "quiet"
        until = (q.get("snoozes") or {}).get("*", {}).get("until") or 0
        until = until / 1000 if until > 1e12 else until
        if (
            q.get("dnd") is True
            or until > time.time()
            or (q.get("silencedSince") or 0) > 0
        ):
            return "quiet"
    except (OSError, ValueError, TypeError, AttributeError):
        return "quiet"


def gate_mic(cfg):
    mic = cfg["microphoneGate"]
    if not mic["enable"]:
        return None
    try:
        r = subprocess.run(
            ["pactl", "-f", "json", "list", "source-outputs"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode:
            return "mic"
        for s in json.loads(r.stdout):
            # Filter streams (meetingai's echo-cancel) carry only media.name.
            props = s.get("properties") or {}
            name = props.get("application.name") or props.get("media.name")
            if s.get("corked") is False and name not in mic["ignore"]:
                return "mic"
    except (OSError, subprocess.SubprocessError, ValueError, AttributeError):
        return "mic"


def held(cfg, quiet=False):
    """First closed gate among 1-4, or None. Called again right before every sound."""
    for gate in (gate_switch, gate_dnd, gate_quiet, gate_mic):
        name = gate(cfg)
        if name:
            if not quiet:
                log(f"held {name}")
            return name


# -- turn facts -----------------------------------------------------------------


def jsonl(path):
    with contextlib.suppress(OSError):
        for line in Path(path).read_text().splitlines():
            with contextlib.suppress(ValueError):
                obj = json.loads(line)
                if isinstance(obj, dict):
                    yield obj


PROC = "/proc"


def is_teammate(pid=None, proc=None):
    """True when an ancestor (up to 6 levels) runs with an --agent-id argv token."""
    proc = proc or PROC
    pid = os.getppid() if pid is None else pid
    for _ in range(6):
        try:
            with open(f"{proc}/{pid}/cmdline", "rb") as f:
                if any(
                    t == b"--agent-id" or t.startswith(b"--agent-id=")
                    for t in f.read().split(b"\0")
                ):
                    return True
            with open(f"{proc}/{pid}/stat") as f:
                # comm may hold spaces and parens; ppid is the 2nd field after the last ")"
                pid = int(f.read().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            return False
        if pid <= 1:
            return False
    return False


def interactive(agent, payload, env):
    """Gate 5: scripted and delegated runs stay silent."""
    if any(env.get(k) for k in DELEGATED):
        return False
    # Agent-spawned Claude sessions (coders, teams) run in a claude-swarm tmux.
    if "/claude-swarm-" in env.get("TMUX", ""):
        return False
    if is_teammate():
        return False
    if agent == "agy":
        # agy started by Claude (second opinion, handoff) carries CLAUDECODE.
        return not env.get("CLAUDECODE")
    if agent == "claude":
        return env.get("CLAUDE_CODE_ENTRYPOINT") == "cli"
    # Only the first line: a long Codex session file must not stall the hook.
    first = {}
    with contextlib.suppress(OSError, ValueError):
        with open(payload.get("transcript_path", "")) as f:
            first = json.loads(f.readline())
    if not isinstance(first, dict):
        first = {}
    return (first.get("payload") or {}).get("source") in ("cli", "vscode")


def transcript(agent, payload):
    return payload.get("transcriptPath" if agent == "agy" else "transcript_path", "")


def reply_text(agent, payload):
    """The assistant's last message; agy's payload has none, so read its transcript."""
    if agent != "agy":
        return payload.get("last_assistant_message") or ""
    text = ""
    for obj in jsonl(transcript(agent, payload)):
        content = obj.get("content")
        # Keep the last non-empty reply: a tool-only step has empty content.
        if (
            obj.get("type") == "PLANNER_RESPONSE"
            and isinstance(content, str)
            and content.strip()
        ):
            text = content
    return text


def turn_seconds(agent, payload):
    """Seconds since the turn began; None when it cannot be told."""
    start = None
    for obj in jsonl(transcript(agent, payload)):
        if agent == "agy":
            if obj.get("type") == "USER_INPUT":
                start = obj.get("created_at")
        elif agent == "claude":
            if obj.get("type") == "user" and obj.get("promptId") == payload.get(
                "prompt_id"
            ):
                start = obj.get("timestamp")
                break
        elif (
            obj.get("type") == "event_msg"
            and (obj.get("payload") or {}).get("type") == "user_message"
        ):
            start = obj.get("timestamp")
    try:
        return (
            time.time()
            - datetime.fromisoformat(start.replace("Z", "+00:00")).timestamp()
        )
    except (AttributeError, ValueError):
        return None


def label(agent, payload):
    """(agent name, session name or ''): tells concurrent sessions apart."""
    name = ""
    path = transcript(agent, payload)
    if agent == "agy":
        ws = payload.get("workspacePaths")
        if isinstance(ws, list) and ws and isinstance(ws[0], str):
            name = os.path.basename(ws[0].rstrip("/"))
    elif agent == "claude":
        for obj in jsonl(path):
            if obj.get("type") == "ai-title" and isinstance(obj.get("aiTitle"), str):
                name = obj["aiTitle"]
    else:
        first = next(jsonl(path), {})
        cwd = (first.get("payload") or {}).get("cwd")
        name = os.path.basename(cwd.rstrip("/")) if isinstance(cwd, str) else ""
    if not name.strip() and isinstance(payload.get("cwd"), str):
        name = os.path.basename(payload["cwd"].rstrip("/"))
    return agent.capitalize(), " ".join(name.split()[:8])


def spoken_prefix(who, name):
    return f"From {who}, {name}. " if name else f"From {who}. "


# -- summary and speech -----------------------------------------------------------


def summarise_claude(cfg, instruction, text):
    exe = shutil.which("claude")
    if not exe:
        log("claude not found")
        return None
    try:
        r = subprocess.run(
            # The reply is untrusted text: no tools, no MCP, no user/project
            # settings or transcript, no key in its env, and its own Stop hook held.
            [
                exe,
                "-p",
                "--model",
                cfg.get("claudeModel", "haiku"),
                "--tools",
                "",
                "--strict-mcp-config",
                "--no-session-persistence",
                "--setting-sources",
                "",
                "--disable-slash-commands",
            ],
            input=f"{instruction}\n\n{text}",
            capture_output=True,
            text=True,
            timeout=90,
            cwd=run_dir(),
            env={
                **{k: v for k, v in os.environ.items() if k != "ELEVENLABS_API_KEY"},
                "AGENT_SAY_QUIET": "1",
            },
        )
    except (OSError, subprocess.SubprocessError) as e:
        log(f"claude failed: {e}")
        return None
    if r.returncode != 0:
        log(f"claude exited {r.returncode}")
        return None
    return r.stdout.strip() or None


def summarise(cfg, instruction, text):
    if cfg.get("backend") == "claude":
        return summarise_claude(cfg, instruction, text)
    body = {
        "model": cfg["model"],
        "stream": False,
        "think": False,
        "messages": [
            {"role": "system", "content": instruction},
            {"role": "user", "content": text},
        ],
    }
    req = urllib.request.Request(
        cfg["ollamaUrl"].rstrip("/") + "/api/chat",
        json.dumps(body).encode(),
        {"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            out = json.load(r)["message"]["content"]
    except (OSError, ValueError, KeyError, TypeError) as e:
        log(f"ollama failed: {e}")
        return None
    return re.sub(r"<think>.*?</think>", "", out, flags=re.S).strip() or None


def speak(cfg, text):
    # Read at run time, never from the store.
    if cfg.get("elevenLabsKeyFile") and not os.environ.get("ELEVENLABS_API_KEY"):
        with contextlib.suppress(OSError):
            key = Path(cfg["elevenLabsKeyFile"]).read_text().strip()
            if key:
                os.environ["ELEVENLABS_API_KEY"] = key
    overrides = {"elevenlabs_voice_id": cfg["voiceId"]}
    if cfg.get("elevenLabsKeyFile") and os.environ.get("ELEVENLABS_API_KEY"):
        # omarchy-voice tries the keyring before the environment, and its own
        # config may leave ElevenLabs off; the key file decides for this narrator.
        overrides.update(elevenlabs_enabled=True, elevenlabs_key_slot="")
    # Lazy: only the package wrapper has omarchy-voice on PYTHONPATH.
    from omarchy_voice import config as voice_config
    from omarchy_voice.feedback import Feedback

    # speak() returns on a daemon thread; _speak_now plays to the end.
    Feedback(voice_config.load(**overrides))._speak_now(text)


def say_gated(cfg, text):
    """Speak under the lock with gates 1-4 freshly checked; busy or held drops it."""
    run_dir().mkdir(parents=True, exist_ok=True)
    with open(run_dir().parent / "agent-say.lock", "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            log("held lock")
            return False
        # Gates before every sentence: a call or DND that starts mid-way cuts
        # it off after the current sentence, not after the whole explanation.
        spoke = False
        for sentence in re.split(r"(?<=[.!?])\s+", text.strip()):
            if held(cfg):
                return spoke
            speak(cfg, sentence)
            spoke = True
        return spoke


def deliver(cfg, agent, turn, who, name, text, kind, ready=None):
    if cfg.get("speaker") != "nixi":
        return "absent" if say_gated(cfg, spoken_prefix(who, name) + text) else "no"
    state, reason, port, tool_token = ready or nixi_ready(agent)
    if state == "absent":
        return "absent" if say_gated(cfg, spoken_prefix(who, name) + text) else "no"
    if state == "no":
        log(f"nixi held: {reason}")
        return "no"
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/api/agent-say",
        json.dumps(
            {"from": agent, "turn": turn, "name": name, "text": text, "kind": kind}
        ).encode(),
        {"Content-Type": "application/json", "X-Nixi-Token": tool_token},
    )
    try:
        with urllib.request.urlopen(req, timeout=2) as response:
            result = json.load(response)
        if result.get("accepted") is True:
            return "go"
        log(f"nixi delivery refused: {result.get('reason', 'unknown')}")
    except urllib.error.HTTPError as e:
        log(f"nixi delivery HTTP {e.code}")
    except (OSError, ValueError, TypeError, AttributeError) as e:
        log(f"nixi delivery failed: {type(e).__name__}")
    return "no"


def offer_more(text, title="Agent finished"):
    """Notification with a 'Tell me more' action; True when it was clicked.

    Named `default` because Omarchy hands notifications to the nixi companion,
    and a click there only invokes the default action."""
    try:
        r = subprocess.run(
            [
                "notify-send",
                "-a",
                "Agent voice",
                "-A",
                "default=Tell me more",
                "--wait",
                "-t",
                "60000",
                title,
                text,
            ],
            capture_output=True,
            text=True,
            timeout=75,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return r.stdout.strip() == "default"


# -- subcommands ------------------------------------------------------------------


def hook(agent):
    """Never fails and never writes stdout: Claude parses Stop-hook stdout as JSON."""
    try:
        payload = json.load(sys.stdin)
        env = {k: os.environ[k] for k in ENV_KEYS if k in os.environ}
        if not interactive(agent, payload, env):
            log("held delegated")
            return
        run_dir().mkdir(parents=True, exist_ok=True)
        payload_id = uuid.uuid4().hex
        (run_dir() / f"last-{agent}-{payload_id}.json").write_text(
            json.dumps({"payload": payload, "env": env})
        )
        subprocess.run(
            [
                "systemd-run",
                "--user",
                "--no-block",
                "--collect",
                "-p",
                "SyslogIdentifier=agent-say",
                f"--setenv=PATH={os.environ.get('PATH', '')}",
                os.environ.get("AGENT_SAY_BIN", "agent-say"),
                "run",
                agent,
                payload_id,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=5,
        )
    except Exception as e:  # noqa: BLE001 -- a hook that raises can stall the agent
        log(f"hook failed: {e}")


def run(agent, payload_id):
    cfg = config()
    path = run_dir() / f"last-{agent}-{payload_id}.json"
    try:
        saved = json.loads(path.read_text())
    finally:
        path.unlink(missing_ok=True)
    payload = saved["payload"]
    secs = turn_seconds(agent, payload)
    if secs is None:
        log("turn length unknown, treating as long enough")
    elif secs < cfg["minTurnSeconds"]:
        log("held short turn")
        return
    reply = reply_text(agent, payload)
    if not reply.strip():
        log("no reply text")
        return
    ready = None
    if (
        cfg.get("speaker") == "nixi"
    ):  # (the old speaker keeps today's order: summary first)
        if held(cfg):
            return
        ready = nixi_ready(agent)
    if ready and ready[0] == "no":
        log(f"nixi held: {ready[1]}")
        return
    short = summarise(cfg, SHORT, reply)
    if not short:
        return
    who, name = label(agent, payload)
    (run_dir() / "last-summary.json").write_text(
        json.dumps(
            {
                "agent": agent,
                "turn": payload_id,
                "reply": reply,
                "short": short,
                "who": who,
                "name": name,
            }
        )
    )
    log(f"summary: {short}")
    if deliver(cfg, agent, payload_id, who, name, short, "short", ready) != "absent":
        return
    if offer_more(short, f"{who} · {name}" if name else who):
        more(cfg)


def more(cfg=None):
    cfg = cfg or config()
    try:
        saved = json.loads((run_dir() / "last-summary.json").read_text())
        reply = saved["reply"]
    except (OSError, ValueError, KeyError):
        log("nothing to tell more about")
        return
    long = summarise(cfg, LONG, reply)
    if long:
        deliver(
            cfg,
            saved.get("agent", "claude"),
            saved.get("turn") or uuid.uuid4().hex,
            saved.get("who") or "the agent",
            saved.get("name", ""),
            long,
            "more",
        )


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    if cmd == "hook" and len(argv) > 2:
        hook(argv[2])
    elif cmd == "run" and len(argv) > 3:
        run(argv[2], argv[3])
    elif cmd == "more":
        more()
    elif cmd == "held":
        return 1 if held(config(), quiet=True) else 0
    elif cmd in ("on", "off"):
        set_switch(cmd)
    elif cmd == "toggle":
        new = "on" if gate_switch(config()) else "off"
        set_switch(new)
        print(new)
        with contextlib.suppress(OSError, subprocess.SubprocessError):
            subprocess.run(
                ["notify-send", "-a", "Agent voice", f"Agent voice {new}"],
                timeout=5,
                check=False,
            )
    elif cmd == "status":
        print("off" if gate_switch(config()) else "on")
    else:
        print(
            "usage: agent-say hook <agent> | run <agent> <id> | more | held | on | off | toggle | status",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
