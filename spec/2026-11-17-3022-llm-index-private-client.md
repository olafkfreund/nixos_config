---
status: draft
issue: 3022
intent: intent/2026-11-17-3022-llm-index-private-client.md
---

# Spec: private-tier search through a local-model client on p620

Approved intent decisions:

- p620 only; razer gets no client.
- History is kept in a private folder.
- The model is `qwen3.8:27b`, the one Ollama keeps loaded.

## Design

A command `llm-docs` on p620 runs opencode with the private llm-index MCP
server. Three layers enforce the boundary, and each one holds on its own:

```text
 host                                   │ sandbox (bwrap, no network namespace access)
 llm-docs-proxy ── unix socket ─────────┼── socat 127.0.0.1:11434 ── opencode ── llm-index mcp --tier private
   │ allowlist: POST /v1/chat/completions│                                          (reads private.db only)
   │ model must be qwen3.8:27b           │
   └─ TCP 127.0.0.1:11434 → Ollama       │
```

### Layer 1: no network, enforced by the OS

- `bwrap --unshare-all --die-with-parent --clearenv` gives the client its own
  empty network namespace, with loopback only. Nothing in it can reach
  ollama.com, the LAN or the internet, whatever its settings or updates do.
  Probed on p620 on 2026-11-17:
  - `curl http://127.0.0.1:11434/api/version` through the bridge: 200;
  - `curl https://1.1.1.1`: connection refused.
- Unit-level `IPAddressDeny` was tried first: a user scope does not enforce
  it. `systemd-run --user --scope -p IPAddressDeny=any` still reached
  example.com.
- Inside the sandbox, `socat TCP-LISTEN:11434,bind=127.0.0.1` forwards to a
  unix socket bound in from the host. That socket is the only way out.

### Layer 2: a filtering proxy on the host

`llm-docs-proxy` is a Python standard-library script of about 80 lines. It
listens on the unix socket and forwards only what it allows to
`127.0.0.1:11434`:

- `POST /v1/chat/completions` is allowed only when the JSON body's `model` is
  exactly `qwen3.8:27b`. It rejects anything else with 403, so a cloud model
  such as `gpt-oss:120b-cloud` cannot be reached, even if a document asks for
  it or the client config changes. The response is streamed back chunk by
  chunk (SSE).
- `GET /v1/models` returns a list with only that model, made by the proxy
  itself.
- Every other method or path returns 403. That includes `/api/*`, pulls,
  pushes, deletes and web search.
- The request body is capped at 32 MiB; a request that cannot be parsed
  returns 400. The upstream address is fixed in the script.
- The socket lives in `$XDG_RUNTIME_DIR/llm-docs/` with mode 0700. The proxy
  is started and stopped by the wrapper, so it runs only while a session is
  open.

### Layer 3: the client's own config

opencode runs with `HOME=$XDG_DATA_HOME/llm-docs` (0700). Its config, data,
sessions and caches therefore live there. It never reads
`~/.config/opencode` or `~/.local/share/opencode`, including `auth.json`. The
environment is cleared, so no `*_API_KEY` reaches it. The config is set
through `OPENCODE_CONFIG_CONTENT`, plus:

- `OPENCODE_DISABLE_PROJECT_CONFIG=1`, `OPENCODE_DISABLE_AUTOUPDATE=1`,
  `OPENCODE_DISABLE_SHARE=1`, `OPENCODE_DISABLE_MODELS_FETCH=1`;
- `OPENCODE_DISABLE_DEFAULT_PLUGINS=1`, `OPENCODE_DISABLE_CLAUDE_CODE=1`,
  `OPENCODE_DISABLE_EXTERNAL_SKILLS=1`, `OPENCODE_DISABLE_LSP_DOWNLOAD=1`.

The config:

- **One provider:** `ollama`, using `@ai-sdk/openai-compatible` with
  `baseURL http://127.0.0.1:11434/v1` and one model, `qwen3.8:27b`.
  - `model` and `small_model` are both `ollama/qwen3.8:27b`.
  - An `experimental.policies` rule denies `provider.use` on `*` and allows
    `ollama`.
- **One MCP server:** `private`, of type `local`, command
  `[<llm-index>/bin/llm-index, "mcp", "--tier", "private"]`. It is the HM
  `services.llm-index` package, which reads the default
  `~/.config/llm-index/config.toml`.
- **Permissions:** `"*": "deny"` with `"private_*": "allow"`. Every built-in
  tool (bash, edit, write, read, glob, grep, webfetch, task, …) is off, and
  only the four llm-index tools remain.
- `share: "disabled"`, `autoupdate: false`, `snapshot: false`.
- `instructions`: the HM module's `agentInstructions` text, which treats
  index content as untrusted data.

### Sandbox mounts

| Path | Mode | Why |
| --- | --- | --- |
| `/nix/store`, `/run/current-system`, `/etc` | ro | binaries, terminfo, users |
| `~/.config/llm-index/config.toml` | ro | the MCP server's config |
| `~/.local/state/llm-index` | ro, or rw if SQLite WAL needs it (plan step proves which) | `private.db` |
| `$XDG_DATA_HOME/llm-docs` → `$HOME` | rw, 0700 | sessions and history (approved: kept) |
| `$XDG_RUNTIME_DIR/llm-docs` | rw | the proxy socket |
| `/tmp`, `/proc`, `/dev` | tmpfs / new | |

- `~/Documents` is not mounted: `get` serves text from `private.db`
  (`src/mcp.rs:402`).
- `public.db`, `~/.ssh` and `/run/agenix` are not visible either.

### Nix layout

- **New `hosts/common/nixos/llm-docs.nix`:**
  - the option `local.llmIndex.privateClient.enable` (default `false`);
  - a `writeShellApplication` for `llm-docs`, with `bwrap`, `socat`,
    `python3` and `opencode` as runtime inputs;
  - `llm-docs-proxy.py` next to it, installed with `writers.writePython3Bin`.
    That writer runs flake8 at build time.
- **Changed:** `hosts/common/nixos/llm-index.nix` imports it.
- **Changed:** `hosts/p620/nixos/nixarchy.nix`, or the file that sets
  `local.llmIndex` for p620, sets `enable = true`.
- `MODEL` lives in one Nix `let` and is passed to both the proxy (argv) and
  the opencode config, so the two cannot disagree.

## Alternatives rejected

- **Rely on opencode settings only.** A prebuilt binary's settings can
  change with an update. The intent asks for enforcement below the client.
- **Set `OLLAMA_NO_CLOUD=1` on the daemon.** It turns cloud off for every
  client, and you use cloud models elsewhere (the `ask-ollama-cloud`
  skill).
- **Run a second Ollama instance without cloud.** It needs a second copy of
  a 27B model in VRAM, and only one model fits.
- **Use another front end (oterm, mcphost, ollmcp).** None is packaged here.
  The sandbox and proxy would be needed anyway, and opencode is installed
  and supports MCP over stdio with permission rules.
- **Block the network with `systemd-run --user -p IPAddressDeny`.** Probed:
  a user scope does not enforce it.
- **Add a menu entry.** Nobody asked for one, and it is easy to add later.

## Risks

- **opencode may need network at start.** The `@ai-sdk/openai-compatible`
  provider might be installed from npm on first use. The plan's first step
  proves whether 1.18.31 bundles it. If not, the wrapper pre-installs it once
  into `$HOME/.cache` from a run with network that has no MCP server and no
  private data, then starts the sandboxed run.
- **Tool calling with `qwen3.8:27b`.** The model may call tools unreliably
  through the OpenAI-compatible endpoint. The plan tests one `private_search`
  round trip. If it fails, the step stops and you are asked about the model
  choice.
- **The TUI inside bwrap.** It needs a working tty. `--new-session` may break
  it, so the plan tests with and without. The legacy TIOCSTI ioctl is off by
  default on 7.x kernels, so leaving `--new-session` out is acceptable.
- **SQLite read-only.** `private.db` is in WAL mode. Opening it read-only
  needs the `-shm` file. If the ro bind fails, the state directory is bound
  rw. The server still opens it `SQLITE_OPEN_READ_ONLY` with `query_only`
  (`src/db.rs:77-79`).
- **Only p620 is affected.** razer evaluates the option at its default,
  `false`, so its configuration does not change.

## Verification

- **Build:** `nix build` of p620's toplevel, with flake8 run on the proxy;
  `just validate`; CI for p510, p620 and razer.
- **razer unchanged:** its toplevel `drvPath` is the same before and after.
  `llm-docs` is not in razer's closure.
- **Proxy unit test** (`llm-docs-proxy.py --self-test` against a fake
  upstream):
  - the allowed model is forwarded and streams;
  - another model returns 403;
  - `/api/pull` returns 403;
  - an oversized body returns 413;
  - bad JSON returns 400.
- **Live on p620:**
  1. In the sandbox, `curl https://1.1.1.1` fails and the bridge to Ollama
     answers.
  2. A request to `gpt-oss:120b-cloud` through the socket returns 403.
  3. `llm-docs run "find my car insurance renewal date"` calls
     `private_search` and answers from `~/Documents`.
  4. The opencode config of that session lists only the `private` MCP server
     and the `ollama` provider.
  5. `~/.config/opencode/opencode.json` and `~/.local/share/opencode` are
     unchanged (checksums before and after).
  6. `~/.local/share/llm-docs` has mode 0700, and its session files are
     there.
