import importlib.util
import os
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "claude_swarm_reaper",
    os.environ.get("REAPER_MODULE", Path(__file__).with_name("claude_swarm_reaper.py")),
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

NOW = 10_000.0
WIN = 600


def run(sockets, alive, panes, records):
    return m.decide(sockets, alive, panes, records, NOW, WIN)


def test_orphan():
    assert run(["claude-swarm-1"], {1: False}, {}, {}) == [
        ("kill-server", "claude-swarm-1", None, "lead dead")
    ]


def test_idle_past_window_kills_pane_keeps_server():
    r = run(
        ["claude-swarm-1"],
        {1: True},
        {"claude-swarm-1": ["%1", "%2"]},
        {"claude-swarm-1": {"%1": NOW - WIN}},
    )
    assert r == [("kill-pane", "claude-swarm-1", "%1", "idle past window")]


def test_idle_inside_window():
    r = run(
        ["claude-swarm-1"],
        {1: True},
        {"claude-swarm-1": ["%1"]},
        {"claude-swarm-1": {"%1": NOW - WIN + 1}},
    )
    assert r == []


def test_active_after_idle_has_no_record():
    assert run(["claude-swarm-1"], {1: True}, {"claude-swarm-1": ["%1"]}, {}) == []


def test_foreign_socket_ignored():
    assert run(["default", "claude-swarm-x"], {}, {}, {}) == []


def test_pane_without_record_survives():
    r = run(
        ["claude-swarm-1"],
        {1: True},
        {"claude-swarm-1": ["%1", "%2"]},
        {"claude-swarm-1": {"%1": 0}},
    )
    assert [a[:3] for a in r] == [("kill-pane", "claude-swarm-1", "%1")]


def test_last_pane_kills_server():
    r = run(
        ["claude-swarm-1"],
        {1: True},
        {"claude-swarm-1": ["%1"]},
        {"claude-swarm-1": {"%1": 0}},
    )
    assert [a[0] for a in r] == ["kill-pane", "kill-server"]


def test_unqueryable_server_skipped():
    assert run(["claude-swarm-1"], {1: True}, {"claude-swarm-1": None}, {}) == []


def test_hook_idle_then_active(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path))
    monkeypatch.setenv("TMUX", "/run/user/1/tmux-1/claude-swarm-5,12,0")
    monkeypatch.setenv("TMUX_PANE", "%3")
    f = tmp_path / "claude-swarm-reaper" / "claude-swarm-5" / "%3.json"
    assert m.main(["hook", "idle"]) == 0
    assert f.exists()
    assert m.main(["hook", "active"]) == 0
    assert not f.exists()
    assert capsys.readouterr().out == ""


def test_hook_ignores_other_tmux(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path))
    monkeypatch.setenv("TMUX", "/run/user/1/tmux-1/default,12,0")
    monkeypatch.setenv("TMUX_PANE", "%3")
    assert m.main(["hook", "idle"]) == 0
    assert not (tmp_path / "claude-swarm-reaper").exists()


def herdr(owned, agents, clocks):
    return m.decide_herdr(owned, agents, clocks, NOW, WIN)


def test_herdr_foreign_terminal_untouched():
    closes, new = herdr([("/s", "t1")], {"/s": {"t9": "idle"}}, {"/s\tt9": 0})
    assert closes == [] and new == {}


def test_herdr_socket_mismatch_untouched():
    closes, _ = herdr([("/s", "t1")], {"/other": {"t1": "idle"}}, {"/s\tt1": 0})
    assert closes == []


def test_herdr_unqueried_socket_keeps_clock():
    closes, new = herdr([("/s", "t1")], {}, {"/s\tt1": 5.0})
    assert closes == [] and new == {"/s\tt1": 5.0}


def test_herdr_first_idle_starts_clock():
    closes, new = herdr([("/s", "t1")], {"/s": {"t1": "idle"}}, {})
    assert closes == [] and new == {"/s\tt1": NOW}


def test_herdr_too_recent():
    closes, new = herdr(
        [("/s", "t1")], {"/s": {"t1": "done"}}, {"/s\tt1": NOW - WIN + 1}
    )
    assert closes == [] and "/s\tt1" in new


def test_herdr_idle_long_enough_closes():
    closes, new = herdr([("/s", "t1")], {"/s": {"t1": "idle"}}, {"/s\tt1": NOW - WIN})
    assert closes == [("/s", "t1")] and new == {}


def test_herdr_status_flip_resets_clock():
    _, new = herdr([("/s", "t1")], {"/s": {"t1": "working"}}, {"/s\tt1": 0})
    assert new == {}
    closes, new = herdr([("/s", "t1")], {"/s": {}}, {"/s\tt1": 0})  # no longer listed
    assert closes == [] and new == {}
