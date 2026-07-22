"""Ollama code-delegation MCP server.

Lets Claude Code delegate isolated, well-specified coding tasks to a local
Ollama coder model over the OpenAI-compatible /v1 endpoint, then review the
result. Claude stays the supervisor; Ollama is the junior worker.

Stateless stdio server — spawned per Claude Code session, no daemon.
"""

import json
import os
import urllib.request
from mcp.server.fastmcp import FastMCP

DEFAULT_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
DEFAULT_MODEL = "qwen2.5-coder:14b"
GEN_TIMEOUT = 300  # a 14b coder can take a while on a real task

# ponytail: named backends so Claude can pick one without knowing URLs.
HOSTS = {
    "p620": "http://p620:11434",
    "p510": "http://p510:11434",
    "local": "http://localhost:11434",
}

mcp = FastMCP("ollama-code")


def _resolve(host):
    if not host:
        return DEFAULT_HOST
    return HOSTS.get(host, host)  # unknown -> treat as a raw URL


@mcp.tool()
def ollama_code(task, model=DEFAULT_MODEL, host=None):
    """Delegate a self-contained coding task to a local Ollama coder model and
    return only its output. Use for isolated, fully-specified units: write a
    function, generate tests from a signature, convert a snippet, fill
    boilerplate. Then review the result yourself — the local model is the
    junior, you are the reviewer. Keep multi-file reasoning and anything
    subtle on your own model.

    task: the complete, specific instruction for the worker model.
    model: qwen2.5-coder:14b (default), :7b (faster), or
           qwen2.5-coder-bigctx:14b (large context, p510 only).
    host: "p620", "p510", "local", or a full URL. Default from OLLAMA_HOST.
    """
    base = _resolve(host).rstrip("/")
    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a coding assistant. Output only the requested "
                    "code or answer. No preamble, no explanation unless asked."
                ),
            },
            {"role": "user", "content": task},
        ],
        "stream": False,
    }
    req = urllib.request.Request(
        base + "/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=GEN_TIMEOUT) as r:
        data = json.loads(r.read())
    return data["choices"][0]["message"]["content"]


@mcp.tool()
def ollama_list_models(host=None):
    """List models available on an Ollama backend ("p620", "p510", "local",
    or a full URL). Use to discover which coder models a host can serve."""
    base = _resolve(host).rstrip("/")
    req = urllib.request.Request(base + "/v1/models")
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read())
    return [m["id"] for m in data.get("data", [])]


if __name__ == "__main__":
    mcp.run()
