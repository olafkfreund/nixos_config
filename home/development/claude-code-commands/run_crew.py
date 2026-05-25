#!/usr/bin/env python3
"""Local developer crew — delegate file generation to a local LLM.

Talks to the LiteLLM router (default) which proxies Ollama models, so the
same script works from every host on the tailnet without needing a local
ollama or local model pull. Designed to run from any working directory.

Reads four environment knobs:

  CREW_ENDPOINT     Full chat-completion endpoint URL. Must be the
                    OpenAI-compat path (LiteLLM serves it at
                    `/v1/chat/completions`).
                    Default: http://p620:4000/v1/chat/completions

  CREW_MODEL        Model name as exposed by the endpoint. With
                    LiteLLM that's the alias from model_list (e.g.
                    `qwen3:14b`, `qwen3`, `claude-sonnet-4-6`).
                    Default: qwen3:14b

  CREW_API_KEY_FILE Path to a file containing the bearer token to
                    send in `Authorization: Bearer …`. Auto-falls
                    back to `/run/agenix/api-router-<hostname>`,
                    which is where agenix-decrypted per-host LiteLLM
                    keys land on this fleet. The file is read at
                    runtime — token never enters argv or env.

  CREW_REPO_ROOT    Directory the model's `<file path=…>` tags are
                    resolved against. Default: the current working
                    directory.
"""

import sys
import os
import socket
import json
import urllib.request
import urllib.error
import subprocess
import re

ENDPOINT = os.environ.get(
    "CREW_ENDPOINT",
    "http://p620:4000/v1/chat/completions",
)
MODEL_NAME = os.environ.get("CREW_MODEL", "qwen3:14b")
DEFAULT_KEY_FILE = f"/run/agenix/api-router-{socket.gethostname()}"
API_KEY_FILE = os.environ.get("CREW_API_KEY_FILE", DEFAULT_KEY_FILE)


def load_api_key():
    try:
        with open(API_KEY_FILE) as fh:
            return fh.read().strip()
    except OSError as e:
        print(
            f"[-] Cannot read CREW_API_KEY_FILE ({API_KEY_FILE}): {e}.\n"
            f"    Either set CREW_API_KEY_FILE to a readable file containing\n"
            f"    the bearer token, or make sure the per-host agenix secret\n"
            f"    is deployed and readable."
        )
        sys.exit(1)


def query_llm(messages):
    payload = {
        "model": MODEL_NAME,
        "messages": messages,
        "stream": False,
        "temperature": 0.2,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        ENDPOINT,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {load_api_key()}",
        },
    )
    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read().decode("utf-8"))
            # OpenAI-compat: choices[0].message.content
            return res["choices"][0]["message"]["content"]
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:500]
        print(f"[-] LLM HTTP {e.code} from {ENDPOINT}: {body}")
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"[-] LLM connection error: {e}. Endpoint reachable? ({ENDPOINT})")
        sys.exit(1)


def parse_and_write_files(content, repo_root):
    # Parse tags of format: <file path="relative/path/to/file">code</file>
    pattern = re.compile(r'<file\s+path=["\'](.*?)["\']>(.*?)</file>', re.DOTALL)
    matches = pattern.findall(content)

    written_files = []
    for rel_path, code in matches:
        # Prevent Path Traversal
        abs_path = os.path.abspath(os.path.join(repo_root, rel_path))
        if not abs_path.startswith(os.path.abspath(repo_root)):
            print(f"[-] Warning: Blocked path traversal attempt to {rel_path}")
            continue

        # Ensure directories exist
        os.makedirs(os.path.dirname(abs_path), exist_ok=True)
        with open(abs_path, "w") as f:
            f.write(code.strip() + "\n")

        written_files.append(abs_path)
        print(f"[+] Wrote file: {rel_path}")

    return written_files


def validate_syntax(files):
    errors = []
    for f in files:
        if f.endswith(".nix"):
            res = subprocess.run(
                ["nix-instantiate", "--parse", f], capture_output=True, text=True
            )
            if res.returncode != 0:
                errors.append(
                    f"Syntax error in {os.path.basename(f)}:\n{res.stderr.strip()}"
                )
    return errors


def main():
    if len(sys.argv) < 2:
        print('Usage: run_crew.py "task instructions"')
        sys.exit(1)

    task = sys.argv[1]
    # Resolve where file-tagged paths land. Order:
    #   1. CREW_REPO_ROOT env override (lets the user drive crew from
    #      one repo while it edits another, useful when this script
    #      is installed globally).
    #   2. Current working directory — the natural default once the
    #      script lives outside any specific repo. Was previously
    #      `dirname(__file__)/..` which only worked when invoked as
    #      `./scripts/run_crew.py` from a specific repo's root.
    repo_root = os.path.abspath(os.environ.get("CREW_REPO_ROOT", os.getcwd()))

    system_prompt = (
        "You are an expert NixOS systems engineer. Your task is to output the requested file changes.\n"
        "You MUST wrap every file you create or modify inside XML-like tags exactly like this:\n"
        '<file path="relative/path/to/file.nix">\n'
        "code here\n"
        "</file>\n"
        "Do NOT write conversational text, only return the code inside file tags. "
        "Keep your output clean and valid."
    )

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": task},
    ]

    retries = 3
    for attempt in range(retries):
        print(
            f"[*] Querying {MODEL_NAME} via {ENDPOINT} "
            f"(Attempt {attempt + 1}/{retries})..."
        )
        response_content = query_llm(messages)
        messages.append({"role": "assistant", "content": response_content})

        written_files = parse_and_write_files(response_content, repo_root)
        if not written_files:
            print(
                "[-] No files parsed from LLM response. Retrying with a clarifying prompt..."
            )
            messages.append(
                {
                    "role": "user",
                    "content": 'Please format your output using the <file path="...">...</file> tags correctly.',
                }
            )
            continue

        # Verify syntax
        errors = validate_syntax(written_files)
        if not errors:
            print("[+] All syntax checks passed successfully!")

            # Print Git Diff
            rel_files = [os.path.relpath(f, repo_root) for f in written_files]
            diff_res = subprocess.run(
                ["git", "diff"] + rel_files,
                capture_output=True,
                text=True,
                cwd=repo_root,
            )
            if diff_res.returncode == 0 and diff_res.stdout:
                print("\n=== VERIFIED CHANGES ===")
                print(diff_res.stdout)
            sys.exit(0)
        else:
            error_msg = "\n".join(errors)
            print(f"[-] Syntax validation failed:\n{error_msg}\n")
            if attempt < retries - 1:
                print("[*] Dispatching syntax feedback for self-correction...")
                messages.append(
                    {
                        "role": "user",
                        "content": f"The syntax check failed with the following errors. Please fix the syntax mistakes and return the complete corrected files:\n\n{error_msg}",
                    }
                )
            else:
                print("[-] Max retries reached. Validation failed.")
                sys.exit(2)


if __name__ == "__main__":
    main()
