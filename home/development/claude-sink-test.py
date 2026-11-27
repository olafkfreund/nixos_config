"""Exercise the Claude hook script or its packaged shell entry point."""

import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory

POINTER_A = "Request 123-1: read /tmp/req/1.md and answer it in your reply."
POINTER_B = (
    "Request 9cfc29693b43d393-2: read /tmp/req/2.md and answer it in your reply."
)


def user(content, **fields):
    return {"type": "user", "message": {"content": content}, **fields}


def assistant(*texts, **block):
    content = [{"type": "text", "text": value} for value in texts]
    if block:
        content.append(block)
    return {"type": "assistant", "message": {"content": content}}


def main():
    script = sys.argv[1]
    command = [sys.executable, script] if script.endswith(".py") else [script]
    with TemporaryDirectory() as root:
        root = Path(root)
        turns = root / "turns"
        turns.mkdir(mode=0o700)
        transcript = root / "transcript.jsonl"

        def invoke(event, path=turns, raw=None, env=None, **fields):
            result = subprocess.run(
                [*command, event, str(path)],
                input=raw if raw is not None else json.dumps(fields).encode(),
                capture_output=True,
                timeout=10,
                env=env,
                check=False,
            )
            assert (result.returncode, result.stdout, result.stderr) == (0, b"", b""), (
                result
            )

        def prompt(pointer=POINTER_A, prompt_id="a"):
            invoke("prompt", prompt_id=prompt_id, prompt=pointer)

        def stop(prompt_id="a", **fields):
            invoke("stop", prompt_id=prompt_id, **fields)

        def expect(*pairs):
            files = list(turns.glob("*.json"))
            assert len(files) == len(pairs), files
            actual = set()
            for file in files:
                turn = json.loads(file.read_text())
                assert set(turn) == {"turn_id", "input", "reply", "source"}
                assert turn["source"] == "claude" and turn["turn_id"] == file.stem
                actual.add((turn["input"], turn["reply"]))
                file.unlink()
            assert actual == set(pairs), actual
            assert not list(turns.glob(".*.tmp"))

        def fallback(*entries):
            transcript.write_text(
                "".join(json.dumps(entry) + "\n" for entry in entries)
            )
            stop(transcript_path=str(transcript))

        prompt()
        stop(last_assistant_message="direct reply", transcript_path="/missing")
        expect((POINTER_A, "direct reply"))
        stop(last_assistant_message="second Stop")
        expect()

        prompt()
        fallback(user(POINTER_A), assistant("text-only reply"))
        expect((POINTER_A, "text-only reply"))

        prompt()
        matching = user("correlated by ID", prompt_id="a")
        invoke("stop", transcript_path=str(transcript))
        expect()
        fallback(matching, assistant("interim"), assistant(type="tool_use"))
        expect()
        fallback(matching, assistant("old reply"), {"type": "progress"})
        expect()
        fallback(
            matching,
            assistant("old reply"),
            user("unrelated"),
            assistant("wrong reply"),
        )
        expect()
        fallback(user(POINTER_A, prompt_id="b"), assistant("wrong prompt ID"))
        expect()
        fallback(
            matching,
            assistant("interim"),
            assistant(type="tool_use"),
            user([{"type": "tool_result"}]),
            assistant("final", "second block"),
        )
        expect((POINTER_A, "final\nsecond block"))

        prompt()
        prompt(f"<hc-envelope>\n{POINTER_B}\n</hc-envelope>", "b")
        assert (turns / ".claude-input.b").read_text() == POINTER_B
        stop(last_assistant_message="reply A")
        stop("b", last_assistant_message="reply B")
        expect((POINTER_A, "reply A"), (POINTER_B, "reply B"))

        prompt()
        with ThreadPoolExecutor(max_workers=2) as executor:
            list(
                executor.map(
                    lambda _: stop(last_assistant_message="concurrent"), range(2)
                )
            )
        expect((POINTER_A, "concurrent"))

        prompt("ordinary prompt")
        invoke("prompt", prompt=POINTER_A)
        invoke("prompt", prompt_id="../invalid", prompt=POINTER_A)
        invoke("prompt", raw=b"{not JSON")
        invoke(
            "prompt",
            raw=json.dumps({"prompt_id": "a", "prompt": POINTER_A}).encode()
            + b" " * (1 << 20),
        )
        stop(last_assistant_message="no saved pointer")
        assert not list(turns.iterdir())

        turns.chmod(0o750)
        prompt()
        turns.chmod(0o700)
        link = root / "link"
        link.symlink_to(turns)
        invoke("prompt", path=f"{link}/", prompt_id="a", prompt=POINTER_A)
        invoke("prompt", path=f"{link}/.", prompt_id="a", prompt=POINTER_A)
        assert not list(turns.iterdir())

        state = turns / ".claude-input.a"
        transcript.write_text(POINTER_A)
        state.symlink_to(transcript)
        stop(last_assistant_message="symlinked state")
        expect()
        assert state.is_symlink()
        state.unlink()
        prompt()
        link.unlink()
        link.symlink_to(transcript)
        transcript.write_text(
            "\n".join(map(json.dumps, [user(POINTER_A), assistant("reply")]))
        )
        stop(transcript_path=str(link))
        expect()
        with transcript.open("ab") as stream:
            stream.truncate((16 << 20) + 1)
        stop(transcript_path=str(transcript))
        expect()

        fixed_id = "11111111-1111-4111-8111-111111111111"
        (root / "uuid.py").write_text(f"def uuid4(): return {fixed_id!r}\n")
        target = turns / f"{fixed_id}.json"
        transcript.write_text("untouched")
        target.symlink_to(transcript)
        env = dict(os.environ, PYTHONPATH=str(root))
        invoke("stop", prompt_id="a", last_assistant_message="collision", env=env)
        assert (
            target.is_symlink()
            and transcript.read_text() == "untouched"
            and state.exists()
        )
        target.unlink()
        target.write_text("existing turn")
        invoke("stop", prompt_id="a", last_assistant_message="collision", env=env)
        assert target.read_text() == "existing turn" and state.exists()
        target.unlink()
        stop(last_assistant_message="retried")
        expect((POINTER_A, "retried"))
        assert not list(turns.iterdir())

    print("ALL PASSED")


if __name__ == "__main__":
    main()
