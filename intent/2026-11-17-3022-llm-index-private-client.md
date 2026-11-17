---
status: approved
issue: 3022
author: olafkfreund
---

# Intent: private-tier search through a local-model client on p620

## Problem

The private llm-index root `docs` (`~/Documents`) is indexed on p620 and
razer, but you have no way to search it:

- On p620 on 2026-11-17 it held 6,408 files, and `private.db` was 410 MB.
- `hosts/common/nixos/llm-index.nix:44` registers only the public server, in
  Claude Code, Codex and agy. This is on purpose: those clients send tool
  results to hosted models, and `docs` holds bank details and contracts.
- The llm-index CLI (54e0fbe) has no search command.

So the index of your own documents costs disk space and CPU, and gives you
nothing back.

p620 runs Ollama with local, tool-capable models:

- `hosts/p620/configuration.nix:124-143` configures it, with `qwen3.8:27b`
  kept loaded.
- `/api/tags` also lists `gemma4:26b` and `qwen3:14b`, which were pulled by
  hand.

## Proposed outcome

On p620 you can ask questions about `~/Documents` in a chat, for example
"find my last electricity contract" or "which PDF has the car insurance
renewal date". The answers come from the private index, and the model runs
on p620. Which client, command and model to use is for the spec.

## Affected users and systems

- p620: a new user-level client setup.
- razer: see open question 1.
- Your existing opencode, Claude Code, Codex and agy setups: they must not
  change, and must not gain access to the private index.

## Constraints

**Nothing from the private index leaves p620.** That covers file text, paths,
titles, and anything the model writes from them.

- **Local inference only, failing closed.**
  - Every model call, including any helper call for titles or summaries,
    must go to the Ollama on p620 at a loopback address. If that is
    unavailable, the client stops. It never falls back elsewhere.
  - The local Ollama can also proxy to ollama.com: `gpt-oss:120b-cloud` is
    listed. The daemon holds its own cloud key
    (`modules/services/ollama.nix:210-231`), and `OLLAMA_API_KEY` is also
    exported to your shells (`modules/secrets/api-keys.nix:254`).
  - So removing the key from the client is not enough. The client must be
    unable to use a cloud model at all, even if a document's text asks it to.
- **Enforced below the client config where possible.** A prebuilt client's
  own settings, for telemetry, update checks, share links and remote model
  lists, can change with an update. The spec should block the client
  process's outbound network at the OS level, allowing only loopback to
  Ollama, or explain why it can't.
- **Kept apart from your other clients.**
  - Your other client profiles must not see, resume or inherit private
    sessions.
  - Inherited settings, project settings, plugins and other MCP servers must
    not add hosted providers or extra tools to it.
  - Transcripts, caches and logs are inside the privacy boundary.
- **Read-only, and document text treated as untrusted.**
  - The client gets no shell and no file-editing or web tools.
  - Document text must not be able to change the model, the provider, the
    destination or the client's permissions.
  - This does not make injection harmless: a document can still steer
    answers or pull up other private documents. The goal is that it cannot
    move data off the machine.
- **Out of scope:** Ollama listening on `0.0.0.0` with the firewall off
  (`hosts/p620/configuration.nix:98,126`). It is unauthenticated, but it is a
  separate issue. Requests from this client go over loopback and never cross
  that network. Ollama does not store conversations.
- **Deployment:** the repository's usual route (worktree, PR, CI,
  `just p620`).

## Open questions

1. **razer** has its own private `docs` root and no Ollama. Which do you
   want?
   - Skip the client on razer, and leave its `docs` root unsearchable.
     **Recommendation.**
   - Use p620's Ollama over the LAN. That sends razer's private text to p620
     over plain HTTP, so it breaks the "never leaves the machine" rule.
   - Drop razer's `docs` root. That is a separate change.
2. **Chat history:** should private sessions be wiped on exit, or kept in a
   private folder only you can read?
   - **Recommendation:** keep them in a private folder that no other client
     reads.
3. **Model:** prefer the one Ollama already keeps loaded (`qwen3.8:27b`)?
   - Only one model is loaded at a time (`OLLAMA_MAX_LOADED_MODELS = 1`), so
     any other model pushes your coding models out of the GPU on every
     query.
   - **Recommendation:** yes. The spec will check that it calls tools
     reliably.
