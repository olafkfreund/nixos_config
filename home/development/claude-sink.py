"""Publish Claude Code hook replies for herdr-team."""

import fcntl
import json
import os
import re
import stat
import sys
import uuid
from contextlib import contextmanager, suppress
from pathlib import Path

HOOK_LIMIT = 1 << 20
TRANSCRIPT_LIMIT = 16 << 20
PROMPT_ID = re.compile(r"[A-Za-z0-9._-]{1,128}")
# herdr-team's current generation IDs are eight bytes rendered as hex.
POINTER = re.compile(
    r"Request (?:[0-9]+|[0-9a-f]{16})-[0-9]+: read \S+ and answer it in your reply\."
)


@contextmanager
def open_fd(path, flags, directory=None):
    fd = os.open(path, flags | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=directory)
    try:
        yield fd
    finally:
        os.close(fd)


def read_file(path, limit, directory=None):
    with open_fd(path, os.O_RDONLY, directory) as fd:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise ValueError
        with open(fd, "rb", closefd=False) as stream:
            data = stream.read(limit + 1)
        if len(data) > limit:
            raise ValueError
        return data.decode("utf-8")


def publish(directory, temporary, target, data, *, replace=False):
    with open_fd(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, directory) as fd:
        try:
            with open(fd, "w", encoding="utf-8", closefd=False) as stream:
                stream.write(data)
            if replace:
                os.replace(
                    temporary, target, src_dir_fd=directory, dst_dir_fd=directory
                )
            else:
                os.link(
                    temporary,
                    target,
                    src_dir_fd=directory,
                    dst_dir_fd=directory,
                    follow_symlinks=False,
                )
        finally:
            with suppress(FileNotFoundError):
                os.unlink(temporary, dir_fd=directory)


def message_text(content):
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    return "\n".join(
        block["text"]
        for block in content
        if isinstance(block, dict)
        and block.get("type") == "text"
        and isinstance(block.get("text"), str)
    )


def transcript_reply(path, prompt_id, pointer):
    if not isinstance(path, str):
        return ""
    matched = explicit_match = False
    reply = ""
    for line in read_file(path, TRANSCRIPT_LIMIT).splitlines():
        entry = json.loads(line)
        if not isinstance(entry, dict):
            return ""
        kind = entry.get("type")
        message = entry.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        reply = ""
        if kind == "user":
            if (
                isinstance(content, list)
                and content
                and all(
                    isinstance(block, dict) and block.get("type") == "tool_result"
                    for block in content
                )
            ):
                continue
            entry_id = entry.get("prompt_id")
            matched = entry_id == prompt_id
            explicit_match |= matched
            if entry_id is None and not explicit_match:
                matched = pointer in message_text(content)
        elif kind == "assistant" and matched and isinstance(content, list):
            reply = message_text(content)
    return reply


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in {"prompt", "stop"}:
        return
    event, path = sys.argv[1:]
    if not path:
        return
    payload = sys.stdin.buffer.read(HOOK_LIMIT)
    if len(payload) == HOOK_LIMIT:
        return
    hook = json.loads(payload)
    if not isinstance(hook, dict):
        return
    prompt_id = hook.get("prompt_id")
    if not isinstance(prompt_id, str) or not PROMPT_ID.fullmatch(prompt_id):
        return
    state = f".claude-input.{prompt_id}"
    with open_fd(Path(path), os.O_RDONLY | os.O_DIRECTORY) as directory:
        info = os.fstat(directory)
        if info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700:
            return
        # Serialize Stop hooks through state removal, including simultaneous Stops.
        fcntl.flock(directory, fcntl.LOCK_EX)
        if event == "prompt":
            prompt = hook.get("prompt")
            if isinstance(prompt, str):
                for line in prompt.splitlines():
                    if POINTER.fullmatch(line):
                        publish(
                            directory, f".{uuid.uuid4()}.tmp", state, line, replace=True
                        )
                        break
            return

        pointer = read_file(state, HOOK_LIMIT, directory)
        if not POINTER.fullmatch(pointer):
            return
        reply = hook.get("last_assistant_message")
        if not isinstance(reply, str) or not reply:
            reply = transcript_reply(hook.get("transcript_path"), prompt_id, pointer)
        if reply:
            turn_id = str(uuid.uuid4())
            payload = {
                "turn_id": turn_id,
                "input": pointer,
                "reply": reply,
                "source": "claude",
            }
            publish(
                directory, f".{turn_id}.tmp", f"{turn_id}.json", json.dumps(payload)
            )
            os.unlink(state, dir_fd=directory)


if __name__ == "__main__":
    with suppress(OSError, ValueError, RecursionError):
        main()
