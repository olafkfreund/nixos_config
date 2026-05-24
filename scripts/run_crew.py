#!/usr/bin/env python3
import sys
import os
import json
import urllib.request
import urllib.error
import subprocess
import re

OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
MODEL_NAME = "qwen3:14b"


def query_ollama(messages):
    payload = {
        "model": MODEL_NAME,
        "messages": messages,
        "stream": False,
        "options": {"temperature": 0.2},
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_URL, data=data, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read().decode("utf-8"))
            return res["message"]["content"]
    except urllib.error.URLError as e:
        print(f"[-] Ollama connection error: {e}. Is Ollama running on {OLLAMA_URL}?")
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
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

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
        print(f"[*] Querying {MODEL_NAME} (Attempt {attempt + 1}/{retries})...")
        response_content = query_ollama(messages)
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
