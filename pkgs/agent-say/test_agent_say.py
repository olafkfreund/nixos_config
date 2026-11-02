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
    monkeypatch.setattr(a, "offer_more", lambda text: False)
    return spoken


def test_run_speaks_when_clear(dirs, monkeypatch):
    spoken = prepare_run(dirs, monkeypatch)
    clear_gates(monkeypatch)
    monkeypatch.setattr(a, "summarise", lambda cfg, ins, text: "All done.")
    a.run("claude")
    assert spoken == ["All done."]


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
        lambda text: (setattr(a, "gate_dnd", lambda cfg: "dnd"), True)[1],
    )
    a.run("claude")  # speaks short, click arrives, DND turned on meanwhile
    assert spoken == ["short"]


def test_think_stripped(monkeypatch):
    class R(io.BytesIO):
        __enter__ = lambda s: s
        __exit__ = lambda s, *x: None

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
