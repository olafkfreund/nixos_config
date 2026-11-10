#!/usr/bin/env python3
"""Exercise the ACP client through a terminal and a fake JSON-RPC agy."""

import json
import os
import pty
import select
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path


FAKE = r"""#!/usr/bin/env python3
import json, os, signal, sys, time
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
open(os.environ['FAKE_PID'], 'w').write(str(os.getpid()))
count = 0
def send(obj):
    print(json.dumps({'jsonrpc': '2.0', **obj}), flush=True)
for line in sys.stdin:
    msg = json.loads(line)
    method = msg.get('method')
    if method == 'initialize':
        send({'id': msg['id'], 'result': {'protocolVersion': 1}})
    elif method == 'session/new':
        send({'id': msg['id'], 'result': {'sessionId': 'fake-session', 'configOptions': [{'id': 'model'}, {'id': 'thought_level'}]}})
    elif method == 'session/set_config_option':
        send({'id': msg['id'], 'result': {}})
    elif method == 'session/prompt':
        count += 1
        prompt = msg['params']['prompt'][0]['text']
        if prompt == 'permission':
            send({'id': 1000, 'method': 'session/request_permission', 'params': {'options': [{'kind': 'reject', 'optionId': 'no'}, {'kind': 'allow_once', 'optionId': 'yes'}]}})
            answer = json.loads(sys.stdin.readline())
            assert answer['result']['outcome']['optionId'] == 'yes'
        if prompt == 'unknown':
            send({'id': 1001, 'method': 'unknown', 'params': {}})
            answer = json.loads(sys.stdin.readline())
            assert answer['error']['code'] == -32601
        if prompt == 'wait':
            send({'method': 'session/update', 'params': {'update': {'sessionUpdate': 'agent_message_chunk', 'content': {'type': 'text', 'text': 'waiting'}}}})
            cancel = json.loads(sys.stdin.readline())
            assert cancel['method'] == 'session/cancel'
            send({'id': msg['id'], 'result': {'stopReason': 'cancelled'}})
            continue
        send({'method': 'session/update', 'params': {'update': {'sessionUpdate': 'tool_call', 'title': 'fake tool'}}})
        send({'method': 'session/update', 'params': {'update': {'sessionUpdate': 'agent_message_chunk', 'content': {'type': 'text', 'text': f'reply {count}: {prompt}'}}}})
        send({'id': msg['id'], 'result': {'stopReason': 'blocked' if prompt == 'other' else 'end_turn'}})
"""


def wait_for(predicate, seconds=5):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.02)
    raise AssertionError("timed out waiting for condition")


def read_until(fd, needle):
    deadline = time.monotonic() + 5
    output = b""
    while needle.encode() not in output:
        assert time.monotonic() < deadline, output
        if select.select([fd], [], [], 0.1)[0]:
            output += os.read(fd, 65536)
    return output.decode(errors="replace")


def live(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split()[2] != "Z"
    except FileNotFoundError:
        return False


def main(client):
    with tempfile.TemporaryDirectory() as base:
        root = Path(base)
        fake = root / "agy"
        fake.write_text(
            FAKE.replace("#!/usr/bin/env python3", f"#!{sys.executable}", 1)
        )
        fake.chmod(0o755)
        turns = root / "turns"
        turns.mkdir(mode=0o700)
        pidfile = root / "pid"
        env = {
            **os.environ,
            "PATH": f"{root}:{os.environ['PATH']}",
            "FAKE_PID": str(pidfile),
            "HERDR_TEAM_TIME_SCALE": "0.01",
        }
        cmd = [
            client,
            "--turns",
            str(turns),
            "--model",
            "fake-model",
            "--effort",
            "high",
        ]

        bad = root / "bad"
        bad.mkdir(mode=0o755)
        bad.chmod(0o755)
        result = subprocess.run(
            [client, "--turns", str(bad), "--once"],
            env=env,
            input="",
            text=True,
            capture_output=True,
        )
        assert result.returncode != 0 and "invalid --turns" in result.stderr

        master, slave = pty.openpty()
        process = subprocess.Popen(
            cmd, env=env, stdin=slave, stdout=slave, stderr=slave, preexec_fn=os.setsid
        )
        os.close(slave)
        try:
            assert "agy session fake-session" in read_until(master, "❯ ")
            for prompt in ("first", "permission", "unknown", "other"):
                os.write(master, (prompt + "\n").encode())
                output = read_until(master, "❯ ")
                assert "· fake tool" in output and f"reply" in output, output
            os.write(master, b"wait\n")
            assert "waiting" in read_until(master, "waiting")
            os.killpg(process.pid, signal.SIGINT)
            assert "■ Conversation interrupted" in read_until(master, "❯ ")
            os.write(master, b"after\n")
            assert "reply 6: after" in read_until(master, "❯ ")
            os.killpg(process.pid, signal.SIGINT)
            assert process.wait(timeout=5) == 0
            files = [json.loads(path.read_text()) for path in turns.glob("*.json")]
            assert {f["input"] for f in files} == {
                "first",
                "permission",
                "unknown",
                "after",
            }, files
            assert (
                next(f for f in files if f["input"] == "after")["reply"]
                == "reply 6: after"
            )
            assert all(f["source"] == "agy" and f["turn_id"] for f in files)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

        for path in turns.iterdir():
            path.unlink()
        result = subprocess.run(
            cmd + ["--once"],
            env=env,
            input="one\ntwo\n",
            text=True,
            capture_output=True,
            timeout=5,
        )
        assert result.returncode == 0, result.stderr
        files = [json.loads(path.read_text()) for path in turns.glob("*.json")]
        assert len(files) == 2 and {f["input"] for f in files} == {"one", "two"}, files
        assert any(f["reply"] == "reply 2: two" for f in files)

        for settled in (False, True):
            pidfile.unlink()
            process = subprocess.Popen(
                cmd + ["--once"],
                env=env,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            wait_for(pidfile.exists)
            child_pid = int(pidfile.read_text())
            if settled:
                time.sleep(0.1)
            process.kill()
            process.wait(timeout=5)
            wait_for(lambda: not live(child_pid))
            process.stdin.close()


if __name__ == "__main__":
    main(
        sys.argv[1]
        if len(sys.argv) > 1
        else str(Path(__file__).with_name("agy-acp-member.py"))
    )
