---
status: approved
issue: 3022
spec: spec/2026-11-17-3022-llm-index-private-client.md
coders:
  1: codex   # the filtering proxy is small, security-critical parsing logic with a self-test
  2: coder   # Nix module, wrapper and runner script, following hosts/common/nixos/llm-index.nix patterns
reviewers:
  - codex    # independent read of the diff against this plan, focused on the privacy boundary
  - agy      # second independent read; its prompt names the exact files
---

# Plan: private-tier search through a local-model client on p620

## Approved decisions (self-contained)

**Command.** p620 only. `llm-docs` takes no arguments, or `run <prompt>`.
Anything else is refused.

**Sandbox.** It runs opencode in
`bwrap --unshare-all --die-with-parent --clearenv`. That gives it its own
network namespace with only loopback, and no `--new-session`.

- The wrapper refuses to start unless `dev.tty.legacy_tiocsti` is `0`.
- Only fds 0-2 are passed in.
- Output goes only to your terminal.

**Mounts.** Exactly these, and nothing else:

`H = /home/olafkfreund`. Each row is one bwrap argument group, in this
order:

| Inside | Host source | bwrap |
| --- | --- | --- |
| `/nix/store` | `/nix/store` | `--ro-bind` |
| `/lib64` | `/lib64` | `--ro-bind`. Spec amendment: opencode-bin's loader is nix-ld. |
| `/run/current-system/sw/share/nix-ld` | same | `--ro-bind` (spec amendment) |
| `/etc/passwd`, `/etc/group`, `/etc/nsswitch.conf`, `/etc/localtime` | same | `--ro-bind` each |
| `/proc`, `/dev`, `/tmp`, `$H` | none | `--proc`, `--dev`, `--tmpfs /tmp`, `--tmpfs /home` |
| `$H/.config/llm-index/config.toml` | same | `--ro-bind` |
| `$H/.local/state/llm-index/<f>` for `<f>` in `private.db`, `private.db-wal`, `private.db-shm`, `public.db`, `public.db-wal`, `public.db-shm` | same | `--ro-bind` each, six arguments |
| `$H/.local/share/opencode` | `$H/.local/share/llm-docs/data` | `--bind` |
| `$H/.config/opencode` | `$H/.local/share/llm-docs/config` | `--bind` |
| `$H/.cache/opencode` | `$H/.local/share/llm-docs/cache` | `--bind` |
| `/run/llm-docs.sock` | `$XDG_RUNTIME_DIR/llm-docs/ollama.sock` | `--bind` (the socket file only) |

`$H/.local/share/llm-docs` and its three children are all 0700. Any process
running as you can still read them, as it can `~/Documents`, so mode 0700
only keeps other Unix users out.

**Descriptors.** Only fds 0-2 cross into the sandbox. Both the wrapper,
before `exec bwrap`, and the inner runner, before `exec opencode`, close
every fd above 2:

```bash
for f in /proc/self/fd/*; do n=${f##*/}; [ "$n" -gt 2 ] && eval "exec $n>&-"; done 2>/dev/null || true
```

The wrapper starts the proxy as a background child first; its socket is not
an fd of the shell.

**Inner runner.** It starts
`socat TCP-LISTEN:11434,bind=127.0.0.1,fork,reuseaddr UNIX-CONNECT:/run/llm-docs.sock`.
It waits at most 5 s for the port, then `exec`s opencode.

**Proxy** (`llm-docs-proxy`, Python stdlib, `writers.writePython3Bin`). It
listens on `$XDG_RUNTIME_DIR/llm-docs/ollama.sock`; the folder is 0700. The
wrapper starts it and stops it on exit.

- One request per connection, with `Connection: close` both ways.
- Only `POST /v1/chat/completions` with no query string. Anything else gets
  403 and never reaches Ollama.
- `Content-Length` is required; `Transfer-Encoding` gets 400. A body over
  32 MiB gets 413.
- The body must be one JSON object with no duplicate keys at any level
  (400), and `model` must be exactly the pinned model (403).
- Upstream gets the re-serialised object with fresh headers (`Content-Type`,
  `Content-Length`, `Accept`). The target is fixed at `127.0.0.1:11434`.
  A 3xx answer becomes 502.
- Before each forward, the proxy checks `/api/tags` and `/api/show`. The
  model must be listed, have format `gguf`, be larger than 1 GiB and have no
  `remote_host`. Otherwise it answers 503.
- The status and body are relayed as they arrive, for both SSE and plain
  JSON. Only `Content-Type` is passed on.
- `GET /v1/models` is answered locally with the pinned model only.
- If upstream is down, it answers 502.

**opencode.**

- Environment: only `HOME=/home/olafkfreund`, `TERM`, `COLORTERM`, `LANG`,
  `PATH` (store paths) and the opencode variables: `OPENCODE_CONFIG_CONTENT`,
  and `OPENCODE_DISABLE_*` for PROJECT_CONFIG, AUTOUPDATE, SHARE,
  MODELS_FETCH, DEFAULT_PLUGINS, CLAUDE_CODE, EXTERNAL_SKILLS and
  LSP_DOWNLOAD, each set to `1`.
- Provider: `ollama`, using `@ai-sdk/openai-compatible` with
  `baseURL http://127.0.0.1:11434/v1` and one model, `qwen3.8:27b`. `model`
  and `small_model` are both `ollama/qwen3.8:27b`.
- `experimental.policies`: deny `provider.use` for `*`, then allow `ollama`.
- MCP server: `private`, command
  `[ "${cfg.package}/bin/llm-index" "mcp" "--tier" "private" "--config" "${config.home.homeDirectory}/.config/llm-index/config.toml" ]`.
  That is `/home/olafkfreund/.config/llm-index/config.toml`.
- `permission`: `"*": "deny"`, then allow exactly `private_search`,
  `private_get`, `private_recent` and `private_status`.
- `share: "disabled"`, `autoupdate: false`, `snapshot: false`, `plugin: []`.
  `instructions` is the HM `agentInstructions`.

**Probed on p620 on 2026-11-17** with this exact config and these mounts,
using a logging proxy:

- opencode ran fully offline; the provider is bundled and needed no npm;
- it sent `model: "qwen3.8:27b"` with no prefix;
- the model was offered only the four `private_*` tools;
- `qwen3.8:27b` called `private_search` and answered correctly.

So the spec's bootstrap fallback is not built, and the model choice stands.
The spec records this and the nix-ld rows as an amendment.

If either assumption breaks during implementation or after an opencode
update, the plan stops and asks you before changing anything:

- opencode tries to download;
- `qwen3.8:27b` stops calling the tools.

The wrapper fails closed in both cases: no network, and no other model.

**Nix.**

- New file `hosts/common/nixos/llm-docs.nix`, with the option
  `local.llmIndex.privateClient.enable` (default `false`). When it is on, it
  adds an HM module for `olafkfreund`.
- That module uses `config.services.llm-index.package` and
  `.agentInstructions` from the same HM evaluation.
- `MODEL` is defined once in a `let`.
- `llm-index.nix` imports the file.
- p620 enables it at `hosts/p620/nixos/nixarchy.nix:60`.
- razer is unchanged.

## Steps

### 1. `hosts/common/nixos/llm-docs-proxy.py`: the proxy and its self-test

**Change:** write the proxy to the contract above.

- **Arguments:** `--socket PATH --model NAME`, or `--self-test`. Before
  binding, it unlinks a stale socket left at `PATH` by an earlier crash.
- **Server:** `socketserver.ThreadingUnixStreamServer`, with a hand-written
  request parser that reads the request line, the headers, and exactly
  `Content-Length` bytes. No `http.server` keep-alive.
- **Duplicate keys:** checked with `json.loads(..., object_pairs_hook=…)`,
  raising on a duplicate.
- **Upstream:** `http.client.HTTPConnection("127.0.0.1", 11434, timeout=600)`,
  relaying `r.read1()` chunks.
- **Locality check:** a helper `local_model_ok(name)` queries `/api/tags`
  (name, size) and `/api/show` (`details.format`, `remote_host`). It runs on
  every chat request.
- **Self-test:** `--self-test` starts a fake upstream on a random 127.0.0.1
  port. The upstream address is a module constant that the self-test
  overrides. The fake records the requests it receives, and the self-test
  asserts every spec case:
  - the allowed model is forwarded, and a streamed and a plain answer are
    both relayed;
  - another model gets 403;
  - duplicate `model` keys get 400;
  - `Transfer-Encoding: chunked` gets 400;
  - a body over 32 MiB gets 413;
  - bad JSON gets 400;
  - `/api/pull`, `/api/chat`, `GET /v1/chat/completions` and
    `/v1/chat/completions?x=1` get 403;
  - a non-gguf or tiny model upstream gets 503;
  - upstream down gets 502;
  - `GET /v1/models` returns only the pinned model.

  The assertions on what reaches the fake upstream:

  - For every 400, 403 and 413 case, and for `GET /v1/models`, it receives
    no request at all.
  - For the 503 case, it receives only `/api/tags` and `/api/show`, and no
    chat request.

**Where:** new file `hosts/common/nixos/llm-docs-proxy.py`, starting at
line 1.

**Check:** `python3 -I hosts/common/nixos/llm-docs-proxy.py --self-test`
exits 0, and `flake8 --max-line-length 100` is clean.

**Traps:**

- Never log request or response bodies. They hold private text. Log only
  the method, path, model and status.
- No third-party imports: `writePython3Bin` gets no libraries.

### 2. `hosts/common/nixos/llm-docs.nix`, plus imports in `llm-index.nix` and p620

**Where:** the new file `hosts/common/nixos/llm-docs.nix`, written from line
1, and the two one-line edits below.

**Change:**

- **The option.** `options.local.llmIndex.privateClient.enable =
  lib.mkEnableOption "llm-docs, the private llm-index client (local model
  only)"`.
- **The HM module,** under
  `config = lib.mkIf cfg.enable { home-manager.users.olafkfreund = { config, pkgs, ... }: { … }; }`:
  - **`llm-docs-proxy`:** `pkgs.writers.writePython3Bin "llm-docs-proxy" {
    flakeIgnore = [ "E501" ]; } (builtins.readFile ./llm-docs-proxy.py)`.
  - **`llm-docs`:** `pkgs.writeShellApplication`, with `runtimeInputs`
    `bubblewrap`, `socat` and `coreutils`. It:
    - checks its arguments;
    - checks `/proc/sys/dev/tty/legacy_tiocsti` is `0`;
    - creates `$XDG_RUNTIME_DIR/llm-docs`, `~/.local/share/llm-docs` and
      its `{data,config,cache}` with `install -d -m 0700` each, the parent
      first, so modes are set even when the folders exist;
    - starts the proxy in the background and traps EXIT to kill it;
    - waits for the socket;
    - closes fds above 2, then runs `bwrap` with the mounts and environment
      above. The inner runner
      is a separate `writeShellScript` in the store, given socat's store
      path. opencode is
      `${inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencode-bin}/bin/opencode`,
      the attribute `home/default.nix:76` installs. A version change
      re-runs live check 4.
  - **The opencode config:** built with `builtins.toJSON` in Nix and passed
    as one `--setenv OPENCODE_CONFIG_CONTENT` argument.
  - **One sandbox definition, two entry points.** The bwrap argument list is
    a single Nix list, used by `llm-docs` and by a diagnostic script,
    `llm-docs-diag <cmd…>`. The diagnostic runs `<cmd…>` in the same sandbox,
    with the same mounts, environment and bridge, in place of opencode. It
    is exposed only through a read-only HM option, `local.llmDocs.diag`
    (`type = package`, `readOnly = true`), and is never added to
    `home.packages`, so it is not on `PATH`. The lead builds it for live
    checks 1 and 2.
  - `home.packages = [ llm-docs ]`.
- **`hosts/common/nixos/llm-index.nix:10`:** `imports = [ ./omarchy-enable-once.nix ./llm-docs.nix ];`.
- **`hosts/p620/nixos/nixarchy.nix`:** a new line 61, after the existing
  `local.llmIndex.sourcePath` line: `local.llmIndex.privateClient.enable = true;`.

**Check:**

- p620 builds:
  `nix build .#nixosConfigurations.p620.config.system.build.toplevel`.
- razer is unchanged:
  `nix eval --raw .#nixosConfigurations.razer.config.system.build.toplevel.drvPath`
  is identical before and after.
- `just validate` passes.

**Traps:**

- `writeShellApplication` runs shellcheck. Quote every path and use arrays
  for the bwrap arguments.
- Do not touch the existing `llmIndexMcp` activation, or the Claude, Codex
  and agy registration.
- `--clearenv` must come before the `--setenv` arguments.
- Never bind the state folder, `~/Documents`, `/run/user` or `/run/agenix`.

### 3. Lead: build, review, PR, deploy and live checks

This step edits no files.

**Run:** step 2's checks, a fresh Opus review given only this plan and the
diff, and the Codex and agy reviews. The Codex review is a new
`codex exec --ephemeral` session, not the one that wrote step 1. Then open the PR linking the intent,
spec and plan, and wait for CI on p510, p620 and razer. After the merge:

1. `git pull --ff-only` in `~/.config/nixos`.
2. Read the agent bus (`read_new`), check that nothing conflicts on p620,
   and post the deploy.
3. Run `AGENT_BUS_ANNOUNCED=1 just p620`.

**Live checks.** Before the first check, assert that
`~/.local/share/llm-docs` does not exist yet. The checks then run before you
have used the client, so the folder holds only verification sessions, and
it is removed completely at the end. To run commands inside the sandbox,
build the diagnostic script:

```bash
nix build -o /tmp/claude-diag .#nixosConfigurations.p620.config.home-manager.users.olafkfreund.local.llmDocs.diag
/tmp/claude-diag/bin/llm-docs-diag curl -sS https://1.1.1.1
```

1. **Network, inside the sandbox:** the bridge answers; these all fail:
   - `https://1.1.1.1`;
   - `http://[2606:4700::1111]`;
   - DNS for `example.com`;
   - p620's LAN IP on port 11434.

   `ls /run /var/run /tmp` shows no host sockets.
2. **Databases:** writing to `public.db` fails as read-only, and the state
   folder lists only the six files.
3. **Proxy:**
   - a chat request for `gpt-oss:120b-cloud` through the socket gets 403;
   - with Ollama stopped, a chat answers with an error and the proxy log
     shows no other destination. Ollama is shared: read the bus, post, then
     stop it with `AGENT_BUS_ANNOUNCED=1`, and restart it right after.
4. **A real question:** `llm-docs run "<question about a known document>"`
   calls `private_search` and answers. The proxy log shows only
   `qwen3.8:27b`.
5. **Denied tools:** a prompt asking for a shell command or a URL fetch is
   refused.
6. **Normal opencode:**
   - `~/.config/opencode` and `~/.local/share/opencode` have the same
     checksums before and after;
   - the normal opencode lists no `private` server;
   - `~/.local/share/llm-docs` is mode 0700.

**Traps:**

- p510 is not built locally (CI only).
- Stopping Ollama interrupts other agents, so announce on the bus first.
- After the checks, remove the whole verification folder:
  `rm -rf ~/.local/share/llm-docs`. It held only verification sessions,
  because of the assert above. Your first real session recreates it.
- After any opencode version change, re-run all six live checks, not only
  check 4.
- **Descriptor check:** `exec 9</etc/hostname` before the diag, then
  `llm-docs-diag ls /proc/self/fd` lists only 0, 1, 2 and the listing's own
  fd.

## Tests

| Command | Expected |
| --- | --- |
| `python3 -I hosts/common/nixos/llm-docs-proxy.py --self-test` | exit 0, all cases pass |
| p620 toplevel build | builds; flake8 passes inside `writePython3Bin` |
| razer `drvPath` before and after | identical |
| `just validate` | passes |
| Live checks 1-6 | as listed |

## Rollback

- Set `local.llmIndex.privateClient.enable = false` on p620, or revert the
  PR, then run `just p620`.
- Delete `~/.local/share/llm-docs` to remove the history.
- Nothing else on the host changes: Ollama and the llm-index service are
  left as they are.
