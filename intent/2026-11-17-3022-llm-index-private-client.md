---
status: draft
issue: 3022
author: olafkfreund
---

# Intent: private-tier search through a local-model client on p620

## Problem

The private llm-index root `docs` (`~/Documents`) is indexed on p620 and
razer, but nothing can search it:

- On p620 it holds 6,408 files, and `private.db` is 410 MB.
- `hosts/common/nixos/llm-index.nix` registers only the public server, in
  Claude Code, Codex and agy. This is on purpose: those clients send tool
  results to hosted models, and `docs` holds bank details and contracts.
- The CLI has no `search` command.

So the index of your own documents costs disk space and CPU, and gives you
nothing back.

p620 already runs Ollama locally (`features.ollama-server`, RX 7900 XTX) with
tool-capable models such as `qwen3.8:27b`, `gemma4:26b` and `qwen3:14b`.
opencode is installed and can use MCP servers over stdio.

## Proposed outcome

On p620 you start one command, for example `llm-docs`. It opens a chat whose
model runs in the local Ollama and whose only document access is
`llm-index mcp --tier private`. You ask questions such as "find my last
electricity contract" or "which PDF has the car insurance renewal date". It
answers from `~/Documents`, and nothing leaves p620.

## Affected users and systems

- p620: a new Home Manager entry, a wrapper command plus its own client
  config, probably a menu entry, and the shared module or a p620-only file.
- razer: no change unless open question 2 says otherwise.
- The existing opencode, Claude Code, Codex and agy setups: they must not
  change, and must not gain the private server.

## Constraints

- **Nothing private leaves the machine.** This is the hard requirement.
  - **Only local models.** The local Ollama also serves a cloud model
    (`gpt-oss:120b-cloud`), which proxies to ollama.com. `OLLAMA_API_KEY` is
    set in your environment. The client must be pinned to local models, and
    a cloud model must not be selectable by accident.
  - **No hosted fallback in the client.** That covers every model it might
    call for anything, including a separate model for titles or summaries,
    plus share links, telemetry, auto-update and remote model lists. Each
    one must be off or pointed at the local model.
  - **Separate from your normal opencode.** The client runs with its own
    config. Your normal opencode config (`~/.config/opencode/opencode.json`),
    which may use hosted providers, must never see the private server.
- **Read-only:** the client gets no shell and no file-editing tools. It reads
  documents through llm-index only. `get` and `search` are enough.
- **Untrusted content:** document text can contain instructions. With no
  write, shell or network tools, an injected instruction has nothing
  dangerous to call.
- **Deployment:** follow the repository's usual route (worktree, PR, CI,
  `just p620`). razer is affected only if the shared module changes.

## Open questions

1. **Client:** use opencode, which is installed, in a locked-down profile, or
   another local front end (oterm, mcphost, ollmcp)? The spec will compare
   them on how reliably hosted calls can be ruled out.
2. **razer:** razer has its own private `docs` root, but no Ollama.
   - Should razer get the client, using p620's Ollama over the LAN? That
     sends razer's private text to p620, which is your machine, but it does
     leave razer.
   - Should razer skip the client?
   - Or should it drop its `docs` root?
3. **Model:** which local model by default? `qwen3.8:27b` is the most capable
   but needs most of the GPU. `qwen3:14b` is lighter.
