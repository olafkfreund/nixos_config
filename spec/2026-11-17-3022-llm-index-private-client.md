---
status: approved
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
server, inside a sandbox. Three controls work together. Each one covers a
different way out:

| Control | What it stops | What it relies on |
| --- | --- | --- |
| 1. Sandbox with no network | anything in the sandbox reaching ollama.com, the LAN or the internet | the kernel's network namespace; the bridge socket is the only way out |
| 2. Filtering proxy on the host | a cloud model, or any Ollama API other than chat with the pinned local model | the proxy being the only thing behind the bridge |
| 3. Client lockdown | opencode's own extra features: tools, plugins, providers, sharing | opencode honouring its config. Controls 1 and 2 bound the damage if it does not. |

```text
host                                     │ bwrap sandbox (own net, pid, ipc, uts, user ns)
llm-docs-proxy ── unix socket (one file) ┼── socat 127.0.0.1:11434 ── opencode ── llm-index mcp --tier private
  allow: POST /v1/chat/completions       │                                          (dbs bound read-only)
  model == qwen3.8:27b, local gguf       │
  └─ TCP 127.0.0.1:11434 → Ollama        │
```

### Control 1: the sandbox

`bwrap --unshare-all --die-with-parent --clearenv`, with these mounts:

- **Network.** The sandbox gets its own network namespace with only
  loopback. Probed on p620 on 2026-11-17: through the bridge `/api/version`
  answered 200, and `https://1.1.1.1` got "connection refused". bwrap brought
  `lo` up without any extra flag. The namespace also cuts off the host's
  abstract unix sockets. `/run/user`, `/run/dbus` and `/var/run` are not
  mounted, so there is no D-Bus either.
- **What is visible.** Only the paths in the table below. There is no
  writable host path except the history folder and the socket, and no
  pathname socket except the bridge.
- **One way out.** An inner runner script starts
  `socat TCP-LISTEN:11434,bind=127.0.0.1,fork UNIX-CONNECT:/run/llm-docs.sock`,
  waits until port 11434 accepts connections (at most 5 s, else it exits
  with an error), then `exec`s opencode.
- **File descriptors.** The wrapper runs bwrap with only fds 0-2 open.
  `closefrom` is done in the runner before `exec`.
- **Terminal.** bwrap runs without `--new-session`, so the TUI keeps its
  terminal. That is safe because `dev.tty.legacy_tiocsti = 0` on p620
  (checked 2026-11-17). The wrapper checks this at start and refuses to run
  if it is not `0`.
- **Output.** The chat's output goes only to your terminal. The wrapper does
  not log or tee it.

| Inside the sandbox | Source on the host | Mode |
| --- | --- | --- |
| `/nix/store` | `/nix/store` | ro |
| `/etc/passwd`, `/etc/group`, `/etc/nsswitch.conf`, `/etc/localtime` | same | ro, individual files |
| `/home/olafkfreund` | tmpfs | |
| `~/.config/llm-index/config.toml` | same | ro |
| `~/.local/state/llm-index/{private,public}.db{,-wal,-shm}` | same six files | ro, individual files |
| `~/.local/share/opencode`, `~/.config/opencode`, `~/.cache/opencode` | `~/.local/share/llm-docs/{data,config,cache}` (0700) | rw |
| `/run/llm-docs.sock` | `$XDG_RUNTIME_DIR/llm-docs/ollama.sock` | the socket file only |
| `/tmp` / `/proc` / `/dev` | `--tmpfs` / `--proc` / `--dev` | new |

Notes on the table:

- **The databases are read-only files.** The state folder is not mounted,
  so nothing inside can write `public.db`. That matters because hosted
  clients read `public.db`.
  - The private-tier server opens both databases read-only
    (`Store::open(.., Mode::Both)`, `src/mcp.rs:225-231`).
  - Probed on p620 on 2026-11-17: with exactly these six read-only binds and
    nothing else from the state folder, `llm-index mcp --tier private`
    answered `search` with a hit.
- **The home path stays the same.** `HOME=/home/olafkfreund`, so paths that
  depend on it resolve as on the host. The MCP command also passes `--config`
  with the absolute path. opencode's usual folders are mapped onto
  `~/.local/share/llm-docs/*` on the host, so the history is kept and is
  separate from your normal opencode.
- **Same-user access.** Mode 0700 keeps other Unix users out, but any
  process running as you can read `~/.local/share/llm-docs`. That includes
  a hosted agent with shell access. The same is already true of
  `~/Documents` and `private.db`, so the history adds no new kind of
  exposure. Your normal opencode does not read that folder, because its
  paths differ.
- **`~/Documents` is not mounted:** `get` serves text from the database.
  Search by meaning uses the bundled model2vec model
  (`docs/architecture.md`, "The embedding model"). No embedding endpoint is
  needed.

### Control 2: `llm-docs-proxy`

A Python standard-library script, built with `writers.writePython3Bin`, which
runs flake8 at build time. It listens on
`$XDG_RUNTIME_DIR/llm-docs/ollama.sock`; the folder is 0700. The wrapper
starts it and stops it on exit.

**Requests.** One request per connection, with `Connection: close` in both
directions:

- **Method and path:** exactly `POST /v1/chat/completions`, with no query
  string. Anything else is answered with 403 and never reaches Ollama.
- **Body framing:** `Content-Length` is required; `Transfer-Encoding` returns
  400.
  - A body over 32 MiB returns 413.
- **Body content:** the body must be one JSON object. Duplicate keys at any
  level return 400 (checked with `object_pairs_hook`). `model` must be the
  string `qwen3.8:27b`, otherwise 403.
- **Forwarding:** the parsed object is serialised again and sent upstream.
  The proxy builds new headers (`Content-Type`, `Content-Length`, `Accept`)
  and never passes on the client's.
- **Upstream:** the target is fixed in the script as `127.0.0.1:11434`.
  `http.client` does not follow redirects, and a 3xx answer is relayed as a
  502.

**The model must be local, every time.** Before forwarding each request, the
proxy asks the upstream `/api/tags` and `/api/show` about the model. It
forwards only if the model:

- is listed;
- has `details.format == "gguf"`;
- is larger than 1 GiB;
- has no `remote_host`.

Otherwise it answers 503 with "model not local". The check runs on every
request, so a model swapped during a session is caught at the next request.
Data from p620 on 2026-11-17: the cloud model `gpt-oss:120b-cloud` has
`format ""` and size 307 bytes; `qwen3.8:27b` has `format "gguf"`, size
17.7 GB and `remote_host: null`.

**Answers.** The response status and body bytes are relayed as they arrive.
That works for both SSE streams and plain JSON (`stream: false`). Only
`Content-Type` is passed on.

**Model listing.** `GET /v1/models` is answered by the proxy itself, with a
list containing only the pinned model. It never reaches upstream.

**Failure.** If Ollama is unreachable, the proxy answers 502. opencode shows
the error and has nowhere else to go.

### Control 3: opencode lockdown

- **Environment:** set from nothing (`--clearenv`), so no `*_API_KEY`
  reaches it. Then `HOME`, `TERM`, `COLORTERM`, `LANG` and `PATH` (store
  paths only), plus:
  - `OPENCODE_CONFIG_CONTENT`;
  - `OPENCODE_DISABLE_PROJECT_CONFIG=1`, `OPENCODE_DISABLE_AUTOUPDATE=1`,
    `OPENCODE_DISABLE_SHARE=1`, `OPENCODE_DISABLE_MODELS_FETCH=1`;
  - `OPENCODE_DISABLE_DEFAULT_PLUGINS=1`, `OPENCODE_DISABLE_CLAUDE_CODE=1`,
    `OPENCODE_DISABLE_EXTERNAL_SKILLS=1`, `OPENCODE_DISABLE_LSP_DOWNLOAD=1`.

  All of these names are in the 1.18.31 binary's strings.
- **Config:**
  - **Provider:** one, `ollama`, using `@ai-sdk/openai-compatible` with
    `baseURL http://127.0.0.1:11434/v1` and one model, `qwen3.8:27b`.
    `model` and `small_model` are both `ollama/qwen3.8:27b`.
  - **Provider policy:** `experimental.policies` denies `provider.use` for
    `*` and allows `ollama`.
  - **MCP server:** one, `private`: `[<llm-index>, "mcp", "--tier",
    "private", "--config", "/home/olafkfreund/.config/llm-index/config.toml"]`.
  - **Permissions:** `"*": "deny"`, then `"allow"` for exactly
    `private_search`, `private_get`, `private_recent` and `private_status`.
  - **Other settings:** `share: "disabled"`, `autoupdate: false`,
    `snapshot: false`, `plugin: []`. `instructions` is the HM module's
    `agentInstructions`.
- **Arguments:** `llm-docs` takes none, or `run <prompt>` for a one-shot
  question. Anything else is refused, so no `--config`, `--agent`, `--model`
  or plugin can be passed through.
- **Model string:** opencode sends the model key, `qwen3.8:27b`, without
  the provider prefix. The plan's first live step confirms this in the proxy
  log. If the prefix is sent, the proxy rejects every request, which fails
  closed.

### Nix layout

- **New `hosts/common/nixos/llm-docs.nix`:** the NixOS option
  `local.llmIndex.privateClient.enable`, with default `false`. When it is
  on, it adds a Home Manager module for `olafkfreund`:
  - The wrapper is a `writeShellApplication` named `llm-docs`, with runtime
    inputs `bwrap`, `socat` and `opencode`. The proxy is installed alongside.
  - It uses `config.services.llm-index.package` and `.agentInstructions`
    from the same HM evaluation, as `llm-index.nix:39-67` already does.
  - `MODEL` is defined once in a `let` and passed to the proxy (argv) and
    the opencode config, so the two cannot disagree.
- **Changed:** `hosts/common/nixos/llm-index.nix` imports `llm-docs.nix`.
- **Changed:** `hosts/p620/nixos/nixarchy.nix:60` gains
  `local.llmIndex.privateClient.enable = true;`.

## Alternatives rejected

- **Client settings only.** A prebuilt binary's settings can change with an
  update. The intent asks for enforcement below the client.
- **`OLLAMA_NO_CLOUD=1` on the daemon.** It turns cloud off for every client,
  and you use cloud models elsewhere (`ask-ollama-cloud`).
- **A second Ollama instance without cloud.** It needs a second copy of a 27B
  model in VRAM, and only one fits.
- **Another front end (oterm, mcphost, ollmcp).** None is packaged. The
  sandbox and proxy would be needed anyway, and opencode supports MCP over
  stdio with permission rules.
- **`systemd-run --user -p IPAddressDeny`.** Probed: a user scope does not
  enforce it.
- **Mounting the whole state folder.** It would let the sandbox write
  `public.db`, which hosted clients read (Codex and agy review).
- **A menu entry.** Nobody asked for one, and it can be added later.

## Risks

- **opencode may need network at start.** The `@ai-sdk/openai-compatible`
  provider might be installed from npm on first use. The plan's first step
  proves whether 1.18.31 bundles it.
  - If it does not, a one-off bootstrap runs with network in a separate,
    empty temporary home. It has no history folder, no database files and no
    MCP server. It copies only the installed provider package into
    `~/.local/share/llm-docs/cache`.
  - The bootstrap never runs on its own. The wrapper names the missing piece
    and the command to run, and you run it.
- **Tool calling with `qwen3.8:27b`.** The model may call tools unreliably.
  The plan tests one `private_search` round trip. If that fails, the plan
  stops and asks you about the model.
- **Only p620 is affected.** razer evaluates the option at its default,
  `false`. The plan proves this by comparing razer's `drvPath`.

## Verification

**Builds:** p620's toplevel, with flake8 run on the proxy; `just validate`;
CI for p510, p620 and razer. razer's toplevel `drvPath` is the same before
and after.

**Proxy self-test** (`llm-docs-proxy --self-test`, against a fake upstream
that records every request it gets):

- The pinned local model is forwarded. Both a streamed and a plain answer
  are relayed.
- Each of these is rejected with no upstream request at all:
  - another model: 403;
  - duplicate `model` keys: 400;
  - `Transfer-Encoding: chunked`: 400;
  - a body over 32 MiB: 413;
  - bad JSON: 400;
  - `/api/pull`, `/api/chat`, `GET /v1/chat/completions` and
    `/v1/chat/completions?x=1`: 403.
- An upstream model that is not a local gguf: 503.
- The upstream being down: 502.

**Live on p620:**

1. **Network, from inside the sandbox:**
   - `https://1.1.1.1` fails, as do `http://[2606:4700::1111]`, DNS for
     `example.com`, and p620's LAN address on port 11434;
   - the bridge answers;
   - `ls /run /var/run /tmp` shows no host sockets.
2. **The databases:** writing to `public.db` inside the sandbox fails with
   "read-only", and the state folder lists only the six bound files.
3. **The proxy:** a chat request for `gpt-oss:120b-cloud` through the socket
   is answered 403. With Ollama stopped (`systemctl stop ollama`, announced
   on the bus first), a chat answers with an error and the proxy log shows
   no other destination.
4. **A real question:** `llm-docs run "find my car insurance renewal date"`
   calls `private_search` and answers from `~/Documents`. The proxy log
   shows only `qwen3.8:27b` requests.
5. **Locked-down tools:** a prompt asking the model to run a shell command
   or to fetch a URL is refused, because the tool is denied.
6. **Your normal opencode is untouched:**
   - `~/.config/opencode` and `~/.local/share/opencode` have the same
     checksums before and after;
   - your normal opencode lists no `private` server;
   - `~/.local/share/llm-docs` has mode 0700 and holds the session.
