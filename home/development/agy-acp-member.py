#!/usr/bin/env python3
"""Small ACP terminal client for an agy herdr member."""

import argparse
import atexit
import ctypes
import json
import os
import select
import signal
import stat
import subprocess
import sys
import time
import uuid
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--turns", required=True, type=Path)
    parser.add_argument("--model")
    parser.add_argument("--effort")
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    directory = args.turns
    try:
        info = directory.lstat()
        if (
            not stat.S_ISDIR(info.st_mode)
            or stat.S_IMODE(info.st_mode) != 0o700
            or info.st_uid != os.getuid()
        ):
            raise ValueError("turns directory must be owned by you and have mode 0700")
    except (OSError, ValueError) as error:
        parser.error(f"invalid --turns: {error}")

    libc = ctypes.CDLL(None)
    parent_pid = os.getpid()

    def child_setup():
        if libc.prctl(1, 15, 0, 0, 0) != 0 or os.getppid() != parent_pid:
            os._exit(1)

    child = subprocess.Popen(
        ["agy", "acp", "--dangerously-skip-permissions"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        process_group=0,
        preexec_fn=child_setup,
    )

    def cleanup():
        if child.poll() is not None:
            return
        try:
            os.killpg(child.pid, signal.SIGTERM)
            child.wait(timeout=3 * float(os.environ.get("HERDR_TEAM_TIME_SCALE", "1")))
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
        except ProcessLookupError:
            pass

    atexit.register(cleanup)

    def stop(_signum, _frame):
        cleanup()
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGHUP, stop)

    def send(message):
        child.stdin.write((json.dumps({"jsonrpc": "2.0", **message}) + "\n").encode())
        child.stdin.flush()

    pending = bytearray()

    def receive(deadline=None):
        while b"\n" not in pending:
            if (
                deadline is not None
                and not select.select(
                    [child.stdout], [], [], max(0, deadline - time.monotonic())
                )[0]
            ):
                raise TimeoutError("cancel response timed out")
            data = os.read(child.stdout.fileno(), 65536)
            if not data:
                raise RuntimeError("agy acp exited")
            pending.extend(data)
        line, _, rest = pending.partition(b"\n")
        pending[:] = rest
        message = json.loads(line)
        if "method" in message and "id" in message:
            if message["method"] == "session/request_permission":
                options = message.get("params", {}).get("options", [])
                option = next(
                    (o for o in options if o.get("kind", "").startswith("allow")), None
                )
                if option is None:
                    raise RuntimeError("permission request has no allow option")
                send(
                    {
                        "id": message["id"],
                        "result": {
                            "outcome": {
                                "outcome": "selected",
                                "optionId": option["optionId"],
                            }
                        },
                    }
                )
            else:
                send({"id": message["id"], "error": {"code": -32601}})
        return message

    serial = 0

    def request(method, params, stream=None):
        nonlocal serial
        serial += 1
        request_id = serial
        send({"id": request_id, "method": method, "params": params})
        try:
            while True:
                message = receive()
                if message.get("method") == "session/update" and stream is not None:
                    update = message.get("params", {}).get("update", {})
                    if (
                        update.get("sessionUpdate") == "agent_message_chunk"
                        and update.get("content", {}).get("type") == "text"
                    ):
                        chunk = update["content"].get("text", "")
                        stream.append(chunk)
                        print(chunk, end="", flush=True)
                    elif update.get("sessionUpdate") == "tool_call":
                        print(f"\n· {update.get('title', 'tool')}", flush=True)
                if message.get("id") == request_id and "method" not in message:
                    if "error" in message:
                        raise RuntimeError(f"{method}: {message['error']}")
                    return message.get("result", {})
        except KeyboardInterrupt:
            if stream is None:
                raise
            send({"method": "session/cancel", "params": {"sessionId": session_id}})
            deadline = time.monotonic() + 10
            while True:
                message = receive(deadline)
                if message.get("id") == request_id and "method" not in message:
                    print("\n■ Conversation interrupted", flush=True)
                    return None

    request("initialize", {"protocolVersion": 1, "clientCapabilities": {}})
    session = request("session/new", {"cwd": os.getcwd(), "mcpServers": []})
    session_id = session["sessionId"]
    for key, value in (("model", args.model), ("thought_level", args.effort)):
        if value:
            option = next(
                (o for o in session.get("configOptions", []) if o.get("id") == key),
                None,
            )
            if option is None:
                raise RuntimeError(f"agy acp does not offer {key}")
            request(
                "session/set_config_option",
                {"sessionId": session_id, "configId": option["id"], "value": value},
            )
    print(f"agy session {session_id}", flush=True)

    while True:
        try:
            line = sys.stdin.readline() if args.once else input("❯ ")
        except (EOFError, KeyboardInterrupt):
            return 0
        if args.once and not line:
            return 0
        line = line.rstrip("\r\n")
        if not line.strip():
            continue
        chunks = []
        try:
            result = request(
                "session/prompt",
                {"sessionId": session_id, "prompt": [{"type": "text", "text": line}]},
                chunks,
            )
        except TimeoutError:
            cleanup()
            return 1
        print(flush=True)
        if result is not None and result.get("stopReason") == "end_turn":
            turn_id = str(uuid.uuid4())
            temporary = directory / f".{turn_id}.tmp"
            final = directory / f"{turn_id}.json"
            try:
                with temporary.open("x") as output:
                    json.dump(
                        {
                            "turn_id": turn_id,
                            "input": line,
                            "reply": "".join(chunks),
                            "source": "agy",
                        },
                        output,
                    )
                os.replace(temporary, final)
            finally:
                temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, json.JSONDecodeError) as error:
        print(f"agy-acp-member: {error}", file=sys.stderr, flush=True)
        sys.exit(1)
