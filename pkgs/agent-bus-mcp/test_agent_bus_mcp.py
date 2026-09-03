"""Self-check for the parts that are not one-liners.

Deliberately no network and no MCP harness -- the tools are thin wrappers over
httpx. What is checked here is the bookkeeping that would fail silently: a
cursor that re-reads a room from the beginning or skips messages, an identity
that collides with another agent's, and the alias qualification whose absence
made a bare room name unusable.
"""

import importlib.util
import os
import stat
import sys
import tempfile

with tempfile.TemporaryDirectory() as tmp:
    os.environ["AGENT_BUS_STATE"] = tmp
    os.environ["MATRIX_SERVER_NAME"] = "example.org"
    os.environ["AGENT_BUS_HOST"] = "testhost"
    os.environ["CLAUDE_CODE_SESSION_ID"] = "7f9c0ac4-4de6-4aa5-b8c8-f80947ec1906"
    os.environ.pop("AGENT_BUS_NAME", None)

    # In the nix build the test and the module are separate store paths, so
    # "next to me" is /nix/store and wrong; the derivation passes the real path.
    module = os.environ.get(
        "AGENT_BUS_MODULE",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "agent_bus_mcp.py"),
    )
    spec = importlib.util.spec_from_file_location("agent_bus_mcp", module)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)

    # --- identity ---------------------------------------------------------
    # A session's name is derived from its session id, not randomly, so that
    # resuming a session keeps its cursors and its history.
    assert m.SESSION_NAME == "testhost-7f9c0a", m.SESSION_NAME
    assert m._session_name() == m.SESSION_NAME

    # A subagent is namespaced beneath the session that spawned it, so the same
    # subagent type in two sessions is two identities rather than one shared.
    assert m._name_for(None) == "testhost-7f9c0a"
    assert m._name_for("debugger") == "testhost-7f9c0a.debugger"

    # Matrix localparts are a restricted grammar; anything else must be folded
    # away here or registration fails on a name that looked harmless.
    assert m._slug("Code Reviewer #2") == "code-reviewer--2", m._slug(
        "Code Reviewer #2"
    )
    assert m._slug("!!!") == "agent"
    assert m._slug("UPPER") == "upper"

    # An identity already in the table must be returned as-is: reaching the
    # network here would mean re-registering an agent on every single call.
    with m._db() as conn:
        conn.execute(
            "INSERT INTO identities (name, user_id, token) VALUES (?, ?, ?)",
            ("cached", "@agent-cached:example.org", "tok"),
        )
    assert m._identity("cached") == ("@agent-cached:example.org", "tok")

    # The database holds access tokens, so it must not be readable by anyone
    # else even if the enclosing directory is permissive.
    mode = stat.S_IMODE(os.stat(os.path.join(tmp, "bus.db")).st_mode)
    assert mode == 0o600, oct(mode)

    # --- room references --------------------------------------------------
    # The bug this replaced: a bare name became "#agents", which is not a legal
    # alias, so the server rejected it instead of looking it up.
    assert m._alias("agents") == "#agents:example.org"
    assert m._alias("#agents") == "#agents:example.org"
    assert m._alias("#agents:other.org") == "#agents:other.org"
    # A room id is already resolved and must be passed through untouched.
    assert m._alias("!abc") is None

    # --- cursors ----------------------------------------------------------
    assert m._get_cursor("agent-test", "!r:x") is None

    m._set_cursor("agent-test", "!r:x", "t1")
    assert m._get_cursor("agent-test", "!r:x") == "t1"

    # Advancing must overwrite, not accumulate: the PRIMARY KEY conflict clause
    # is what stops a second read inserting a duplicate row and the cursor
    # becoming ambiguous.
    m._set_cursor("agent-test", "!r:x", "t2")
    assert m._get_cursor("agent-test", "!r:x") == "t2"

    # Cursors are per agent and per room. Sharing one would make one agent's
    # read hide messages from another -- including a subagent hiding messages
    # from its own parent session.
    assert m._get_cursor("other-agent", "!r:x") is None
    assert m._get_cursor("agent-test", "!other:x") is None
    m._set_cursor(m._name_for(None), "!r:x", "parent-mark")
    m._set_cursor(m._name_for("debugger"), "!r:x", "child-mark")
    assert m._get_cursor(m._name_for(None), "!r:x") == "parent-mark"
    assert m._get_cursor(m._name_for("debugger"), "!r:x") == "child-mark"

    # --- event shaping ----------------------------------------------------
    threaded = m._format(
        {
            "sender": "@a:x",
            "origin_server_ts": 1,
            "event_id": "$e",
            "content": {
                "body": "hi",
                "m.relates_to": {"rel_type": "m.thread", "event_id": "$root"},
            },
        }
    )
    assert threaded == {
        "from": "@a:x",
        "at": 1,
        "text": "hi",
        "event_id": "$e",
        "thread": "$root",
    }, threaded

    plain = m._format(
        {
            "sender": "@b:x",
            "origin_server_ts": 2,
            "event_id": "$f",
            "content": {"body": "yo"},
        }
    )
    assert plain["thread"] is None and plain["text"] == "yo"

    # A malformed event must not take the whole read down.
    assert m._format({})["text"] == ""

    # An explicit name overrides the session derivation, for clients that have
    # no session id of their own to be derived from.
    os.environ["AGENT_BUS_NAME"] = "codex-p620"
    assert m._session_name() == "codex-p620"

print("agent-bus-mcp self-check passed", file=sys.stderr)
