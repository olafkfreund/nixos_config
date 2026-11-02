"""Every gate both ways, plus the promises the hook makes to the agent."""

import importlib.util
import io
import json
import os
import subprocess
import time
from pathlib import Path
from types import SimpleNamespace

import pytest

_path = os.environ.get("AGENT_SAY_MODULE", Path(__file__).with_name("agent_say.py"))
_spec = importlib.util.spec_from_file_location("agent_say", _path)
a = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(a)

CFG = dict(a.DEFAULTS)


@pytest.fixture(autouse=True)
def dirs(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path / "run"))
    for k in a.ENV_KEYS:
        monkeypatch.delenv(k, raising=False)
    (tmp_path / "run").mkdir()
    return tmp_path


def fake_run(monkeypatch, table):
    """table maps argv[0] to stdout, an exception, or a (stdout, returncode)."""

    def run(cmd, **kw):
        out = table[cmd[0]]
        if isinstance(out, Exception):
            raise out
        out, rc = out if isinstance(out, tuple) else (out, 0)
        return SimpleNamespace(stdout=out, returncode=rc)

    monkeypatch.setattr(a.subprocess, "run", run)


@pytest.mark.parametrize(
    "out,silent",
    [
        ("off\n", False),
        ("on\n", True),
        ("???", True),
        ("", True),
        (subprocess.TimeoutExpired("x", 2), True),
        (FileNotFoundError(), True),
    ],
)
def test_dnd(monkeypatch, out, silent):
    fake_run(monkeypatch, {"omarchy-shell": out})
    assert bool(a.gate_dnd(CFG)) is silent


def quiet(home, body):
    p = home / ".local/state/omarchy/notifications/quiet.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(body if isinstance(body, str) else json.dumps(body))


@pytest.mark.parametrize(
    "body,silent",
    [
        (None, True),
        ("not json", True),
        ([], True),
        ({}, False),
        ({"dnd": True}, True),
        ({"dnd": False, "silencedSince": 0}, False),
        ({"silencedSince": 5}, True),
        ({"snoozes": {"*": {"until": time.time() + 600}}}, True),
        ({"snoozes": {"*": {"until": (time.time() + 600) * 1000}}}, True),
        ({"snoozes": {"*": {"until": time.time() - 600}}}, False),
    ],
)
def test_quiet(dirs, body, silent):
    if body is not None:
        quiet(dirs, body)
    assert bool(a.gate_quiet(CFG)) is silent


@pytest.mark.parametrize(
    "streams,silent",
    [
        ([], False),
        ([{"corked": False, "properties": {"application.name": "parecord"}}], False),
        (
            [{"corked": False, "properties": {"media.name": "Echo-Cancel Capture"}}],
            False,
        ),
        ([{"corked": False, "properties": {"media.name": "Meet call"}}], True),
        ([{"corked": False, "properties": {}}], True),
        (
            [{"corked": False, "properties": {"application.name": "Google Chrome"}}],
            True,
        ),
        (
            [{"corked": True, "properties": {"application.name": "Google Chrome"}}],
            False,
        ),
    ],
)
def test_mic(monkeypatch, streams, silent):
    fake_run(monkeypatch, {"pactl": json.dumps(streams)})
    assert bool(a.gate_mic(CFG)) is silent


def test_mic_failure_and_option_off(monkeypatch):
    fake_run(monkeypatch, {"pactl": ("", 1)})
    assert a.gate_mic(CFG) == "mic"
    fake_run(monkeypatch, {"pactl": FileNotFoundError()})
    assert a.gate_mic(CFG) == "mic"
    assert a.gate_mic({"microphoneGate": {"enable": False, "ignore": []}}) is None


def test_switch(dirs):
    assert a.gate_switch(CFG) is None
    a.main(["x", "off"])
    assert a.gate_switch(CFG) == "switch"
    a.main(["x", "on"])
    assert a.gate_switch(CFG) is None
    assert a.gate_switch({**CFG, "startEnabled": False}) is None  # `on` file present
    (a.state_dir() / "on").unlink()
    assert a.gate_switch({**CFG, "startEnabled": False}) == "switch"


def test_delegated_and_entrypoint(dirs):
    assert a.interactive("claude", {}, {"CLAUDE_CODE_ENTRYPOINT": "cli"})
    assert not a.interactive("claude", {}, {"CLAUDE_CODE_ENTRYPOINT": "sdk-cli"})
    for k in ("AGY_CODER", "CODEX_CODER", "AGENT_SAY_QUIET"):
        assert not a.interactive(
            "claude", {}, {"CLAUDE_CODE_ENTRYPOINT": "cli", k: "1"}
        )


@pytest.mark.parametrize(
    "source,ok",
    [("cli", True), ("vscode", True), ("exec", False), ({"subagent": "x"}, False)],
)
def test_codex_source(dirs, source, ok):
    t = dirs / "t.jsonl"
    t.write_text(
        json.dumps({"type": "session_meta", "payload": {"source": source}}) + "\n"
    )
    assert a.interactive("codex", {"transcript_path": str(t)}, {}) is ok


def iso(ago):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - ago))


def test_turn_seconds(dirs):
    t = dirs / "c.jsonl"
    t.write_text(
        "\n".join(
            json.dumps(x)
            for x in [
                {"type": "user", "promptId": "old", "timestamp": iso(900)},
                {"type": "user", "promptId": "p1", "timestamp": iso(100)},
                {"type": "user", "promptId": "p1", "timestamp": iso(10)},
            ]
        )
    )
    assert (
        95
        < a.turn_seconds("claude", {"transcript_path": str(t), "prompt_id": "p1"})
        < 110
    )
    assert (
        a.turn_seconds("claude", {"transcript_path": str(t), "prompt_id": "nope"})
        is None
    )
    assert a.turn_seconds("claude", {"transcript_path": "/missing"}) is None
    t.write_text(
        "\n".join(
            json.dumps(x)
            for x in [
                {
                    "type": "event_msg",
                    "payload": {"type": "user_message"},
                    "timestamp": iso(500),
                },
                {
                    "type": "event_msg",
                    "payload": {"type": "user_message"},
                    "timestamp": iso(50),
                },
            ]
        )
    )
    assert 45 < a.turn_seconds("codex", {"transcript_path": str(t)}) < 60


def test_hook_never_fails_or_prints(dirs, monkeypatch, capsys):
    monkeypatch.setenv("CLAUDE_CODE_ENTRYPOINT", "cli")
    for stdin in ("garbage", "{}", json.dumps({"last_assistant_message": "hi"})):
        monkeypatch.setattr("sys.stdin", io.StringIO(stdin))
        monkeypatch.setattr(
            a.subprocess,
            "run",
            lambda *x, **k: (_ for _ in ()).throw(FileNotFoundError()),
        )
        assert a.main(["x", "hook", "claude"]) == 0
        assert capsys.readouterr().out == ""
    saved = json.loads((a.run_dir() / "last-claude.json").read_text())
    assert saved["env"] == {"CLAUDE_CODE_ENTRYPOINT": "cli"}


def test_hook_scripted_starts_no_unit(dirs, monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_ENTRYPOINT", "sdk-cli")
    monkeypatch.setattr("sys.stdin", io.StringIO("{}"))
    monkeypatch.setattr(
        a.subprocess, "run", lambda *x, **k: pytest.fail("unit started")
    )
    a.hook("claude")


def clear_gates(monkeypatch):
    for g in ("gate_switch", "gate_dnd", "gate_quiet", "gate_mic"):
        monkeypatch.setattr(a, g, lambda cfg: None)


def prepare_run(dirs, monkeypatch, reply="Did the thing."):
    t = dirs / "c.jsonl"
    t.write_text(json.dumps({"type": "user", "promptId": "p", "timestamp": iso(300)}))
    (a.run_dir()).mkdir(parents=True, exist_ok=True)
    (a.run_dir() / "last-claude.json").write_text(
        json.dumps(
            {
                "payload": {
                    "transcript_path": str(t),
                    "prompt_id": "p",
                    "last_assistant_message": reply,
                },
                "env": {},
            }
        )
    )
    monkeypatch.setattr(a, "CONFIG", dirs / "none.json")
    spoken = []
    monkeypatch.setattr(a, "speak", lambda cfg, text: spoken.append(text))
    monkeypatch.setattr(a, "offer_more", lambda *x: False)
    return spoken


def test_run_speaks_when_clear(dirs, monkeypatch):
    spoken = prepare_run(dirs, monkeypatch)
    clear_gates(monkeypatch)
    monkeypatch.setattr(a, "summarise", lambda cfg, ins, text: "All done.")
    a.run("claude")
    assert " ".join(spoken) == "From Claude. All done."


def test_run_held_gate_is_silent(dirs, monkeypatch):
    spoken = prepare_run(dirs, monkeypatch)
    clear_gates(monkeypatch)
    monkeypatch.setattr(a, "gate_dnd", lambda cfg: "dnd")
    monkeypatch.setattr(a, "summarise", lambda cfg, ins, text: "All done.")
    a.run("claude")
    assert spoken == []


def test_run_ollama_down_is_silent(dirs, monkeypatch):
    spoken = prepare_run(dirs, monkeypatch)
    clear_gates(monkeypatch)
    monkeypatch.setattr(
        a.urllib.request,
        "urlopen",
        lambda *x, **k: (_ for _ in ()).throw(OSError("down")),
    )
    a.run("claude")
    assert spoken == []


def test_run_short_turn_is_silent(dirs, monkeypatch):
    spoken = prepare_run(dirs, monkeypatch)
    clear_gates(monkeypatch)
    monkeypatch.setattr(a, "config", lambda: {**CFG, "minTurnSeconds": 3600})
    monkeypatch.setattr(a, "summarise", lambda *x: pytest.fail("asked ollama"))
    a.run("claude")
    assert spoken == []


def test_more_rechecks_gates(dirs, monkeypatch):
    spoken = prepare_run(dirs, monkeypatch)
    clear_gates(monkeypatch)
    monkeypatch.setattr(
        a, "summarise", lambda cfg, ins, text: "long" if ins == a.LONG else "short"
    )
    monkeypatch.setattr(
        a,
        "offer_more",
        lambda *x: (setattr(a, "gate_dnd", lambda cfg: "dnd"), True)[1],
    )
    a.run("claude")  # speaks short, click arrives, DND turned on meanwhile
    assert " ".join(spoken) == "From Claude. short"


@pytest.mark.parametrize(
    "out,clicked", [("default\n", True), ("\n", False), ("more\n", False)]
)
def test_offer_more_default_action(monkeypatch, out, clicked):
    calls = []

    def fake_run(cmd, **kw):
        calls.append(cmd)
        return SimpleNamespace(stdout=out)

    monkeypatch.setattr(a.subprocess, "run", fake_run)
    assert a.offer_more("hi") is clicked
    assert "default=Tell me more" in calls[0]


def write_jsonl(path, *objs):
    path.write_text("\n".join(json.dumps(o) for o in objs))
    return str(path)


def test_label_claude_uses_last_ai_title(dirs):
    t = write_jsonl(
        dirs / "t.jsonl",
        {"type": "ai-title", "aiTitle": "Old"},
        {"type": "user"},
        {"type": "ai-title", "aiTitle": "New title"},
    )
    assert a.label("claude", {"transcript_path": t, "cwd": "/x/proj"}) == (
        "Claude",
        "New title",
    )


def test_label_claude_falls_back_to_cwd(dirs):
    t = write_jsonl(dirs / "t.jsonl", {"type": "user"})
    assert a.label("claude", {"transcript_path": t, "cwd": "/x/proj/"}) == (
        "Claude",
        "proj",
    )


def test_label_codex_cwd_from_session_meta(dirs):
    t = write_jsonl(
        dirs / "t.jsonl", {"type": "session_meta", "payload": {"cwd": "/a/meetingai"}}
    )
    assert a.label("codex", {"transcript_path": t, "cwd": "/other"}) == (
        "Codex",
        "meetingai",
    )


def test_label_nothing_is_agent_only():
    assert a.label("codex", {"transcript_path": "/nonexistent"}) == ("Codex", "")
    assert a.spoken_prefix("Codex", "") == "From Codex. "


def test_label_truncated_to_eight_words(dirs):
    t = write_jsonl(
        dirs / "t.jsonl", {"type": "ai-title", "aiTitle": "a b c d e f g h i j"}
    )
    assert a.label("claude", {"transcript_path": t})[1] == "a b c d e f g h"


def test_run_and_more_use_label_and_title(dirs, monkeypatch):
    spoken = prepare_run(dirs, monkeypatch)
    t = dirs / "c.jsonl"
    write_jsonl(
        t,
        {"type": "user", "promptId": "p", "timestamp": iso(300)},
        {"type": "ai-title", "aiTitle": "Fix the bar"},
    )
    clear_gates(monkeypatch)
    monkeypatch.setattr(
        a, "summarise", lambda cfg, ins, text: "long" if ins == a.LONG else "short"
    )
    titles = []
    monkeypatch.setattr(a, "offer_more", lambda text, title: titles.append(title))
    a.run("claude")
    a.more()
    assert titles == ["Claude · Fix the bar"]
    assert " ".join(spoken) == (
        "From Claude, Fix the bar. short From Claude, Fix the bar. long"
    )


AGY_PAYLOAD = {"workspacePaths": ["/w/proj"]}


def agy_payload(dirs):
    t = write_jsonl(
        dirs / "agy.jsonl",
        {"type": "USER_INPUT", "created_at": iso(300)},
        {"type": "PLANNER_RESPONSE", "content": "first"},
        {"type": "PLANNER_RESPONSE", "content": "probe ok"},
    )
    return {**AGY_PAYLOAD, "transcriptPath": t}


def test_agy_reply_turn_and_label(dirs):
    p = agy_payload(dirs)
    assert a.reply_text("agy", p) == "probe ok"
    assert 290 < a.turn_seconds("agy", p) < 320
    assert a.label("agy", p) == ("Agy", "proj")


@pytest.mark.parametrize(
    "agent,env,ok",
    [
        ("agy", {}, True),
        ("agy", {"CLAUDECODE": "1"}, False),
        ("agy", {"AGY_CODER": "1"}, False),
        ("claude", {"CLAUDE_CODE_ENTRYPOINT": "cli", "CLAUDECODE": "1"}, True),
        (
            "claude",
            {"CLAUDE_CODE_ENTRYPOINT": "cli", "TMUX": "/t/claude-swarm-1,2,0"},
            False,
        ),
        ("claude", {"CLAUDE_CODE_ENTRYPOINT": "cli", "TMUX": "/t/herdr,2,0"}, True),
    ],
)
def test_interactive_agy_and_swarm(agent, env, ok):
    assert a.interactive(agent, {}, env) is ok


def fake_claude(monkeypatch, rc=0, out="sum\n", exe="/bin/claude"):
    calls = []

    def run_(cmd, **kw):
        calls.append((cmd, kw))
        return SimpleNamespace(returncode=rc, stdout=out)

    monkeypatch.setattr(a.shutil, "which", lambda n: exe)
    monkeypatch.setattr(a.subprocess, "run", run_)
    return calls


def test_claude_backend(dirs, monkeypatch):
    calls = fake_claude(monkeypatch)
    monkeypatch.setenv("ELEVENLABS_API_KEY", "sekrit")
    cfg = {**CFG, "backend": "claude", "claudeModel": "haiku"}
    assert a.summarise(cfg, "ins", "reply") == "sum"
    cmd, kw = calls[0]
    assert cmd[:4] == ["/bin/claude", "-p", "--model", "haiku"]
    # Untrusted reply text: no tools, no MCP, nothing persisted.
    assert cmd[cmd.index("--tools") + 1] == ""
    for flag in (
        "--strict-mcp-config",
        "--no-session-persistence",
        "--disable-slash-commands",
    ):
        assert flag in cmd
    assert "ELEVENLABS_API_KEY" not in kw["env"] and kw["env"]["AGENT_SAY_QUIET"] == "1"
    assert "ins" in kw["input"] and "reply" in kw["input"] and kw["timeout"] == 90


@pytest.mark.parametrize("kw", [{"rc": 1}, {"out": " "}, {"exe": None}])
def test_claude_backend_failure_is_silent(monkeypatch, kw):
    fake_claude(monkeypatch, **kw)
    assert a.summarise({**CFG, "backend": "claude"}, "i", "r") is None


def test_key_file_exported_unless_set(dirs, monkeypatch):
    k = dirs / "key"
    k.write_text("sekrit\n")
    monkeypatch.delenv("ELEVENLABS_API_KEY", raising=False)
    monkeypatch.setitem(__import__("sys").modules, "omarchy_voice", None)
    with pytest.raises(ImportError):
        a.speak({**CFG, "elevenLabsKeyFile": str(k)}, "x")
    assert os.environ["ELEVENLABS_API_KEY"] == "sekrit"
    monkeypatch.setenv("ELEVENLABS_API_KEY", "mine")
    with pytest.raises(ImportError):
        a.speak({**CFG, "elevenLabsKeyFile": str(k)}, "x")
    assert os.environ["ELEVENLABS_API_KEY"] == "mine"


def test_think_stripped(monkeypatch):
    class R(io.BytesIO):
        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return None

    body = json.dumps(
        {"message": {"content": "<think>hmm\nok</think>\nHello."}}
    ).encode()
    monkeypatch.setattr(a.urllib.request, "urlopen", lambda *x, **k: R(body))
    assert a.summarise(CFG, "i", "t") == "Hello."


def test_lock_busy_drops(dirs, monkeypatch):
    import fcntl

    spoken = prepare_run(dirs, monkeypatch)
    clear_gates(monkeypatch)
    with open(a.run_dir().parent / "agent-say.lock", "w") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        assert a.say_gated(CFG, "x") is False
    assert spoken == []


def test_hook_unit_argv_has_path_and_absolute_bin(dirs, monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_ENTRYPOINT", "cli")
    monkeypatch.setenv("PATH", "/x/bin")
    monkeypatch.setenv("AGENT_SAY_BIN", "/store/bin/agent-say")
    monkeypatch.setattr("sys.stdin", io.StringIO("{}"))
    seen = []
    monkeypatch.setattr(a.subprocess, "run", lambda cmd, **k: seen.append(cmd))
    a.hook("claude")
    assert "--setenv=PATH=/x/bin" in seen[0]
    assert seen[0][-3:] == ["/store/bin/agent-say", "run", "claude"]


def test_gate_closing_mid_text_cuts_after_current_sentence(dirs, monkeypatch):
    spoken = prepare_run(dirs, monkeypatch)
    clear_gates(monkeypatch)
    real_speak = a.speak

    def speak_then_dnd(cfg, text):
        real_speak(cfg, text)
        monkeypatch.setattr(a, "gate_dnd", lambda cfg: "dnd")

    monkeypatch.setattr(a, "speak", speak_then_dnd)
    assert a.say_gated(CFG, "One. Two! Three?") is True
    assert spoken == ["One."]


def test_codex_interactive_reads_first_line_only(dirs):
    t = dirs / "s.jsonl"
    t.write_text(json.dumps({"payload": {"source": "cli"}}) + "\n{broken\n")
    assert a.interactive("codex", {"transcript_path": str(t)}, {}) is True
    t.write_text("[1]\n")
    assert a.interactive("codex", {"transcript_path": str(t)}, {}) is False


def test_hook_unit_is_non_blocking_with_timeout(dirs, monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_ENTRYPOINT", "cli")
    monkeypatch.setattr("sys.stdin", io.StringIO("{}"))
    seen = []
    monkeypatch.setattr(a.subprocess, "run", lambda cmd, **k: seen.append((cmd, k)))
    a.hook("claude")
    assert "--no-block" in seen[0][0] and seen[0][1]["timeout"] == 5


def test_agy_reply_skips_empty_last_step(dirs):
    t = dirs / "agy.jsonl"
    t.write_text(
        json.dumps({"type": "PLANNER_RESPONSE", "content": "Did the work."})
        + "\n"
        + json.dumps({"type": "PLANNER_RESPONSE", "content": ""})
        + "\n"
    )
    assert a.reply_text("agy", {"transcriptPath": str(t)}) == "Did the work."


def _proc(root, pid, ppid, argv):
    d = root / str(pid)
    d.mkdir(parents=True)
    (d / "cmdline").write_bytes(b"\0".join(x.encode() for x in argv) + b"\0")
    (d / "stat").write_text(f"{pid} (a b) S {ppid} 0 0")


def test_is_teammate_walks_ancestors(tmp_path):
    _proc(tmp_path, 40, 30, ["bash"])
    _proc(tmp_path, 30, 20, ["claude", "--agent-id", "alpha@t"])
    _proc(tmp_path, 20, 1, ["zsh"])
    assert a.is_teammate(40, str(tmp_path))
    assert not a.is_teammate(20, str(tmp_path))
    assert not a.is_teammate(999, str(tmp_path))  # unreadable: fail closed
