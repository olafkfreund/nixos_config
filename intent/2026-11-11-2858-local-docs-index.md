---
status: draft
issue: 2858
author: olafkfreund
---

# Intent: local document index searchable by all agents

## Problem

The agents on this fleet (Claude Code, Codex, agy, Open WebUI) can read files
only by grepping paths they are told about. Nothing indexes `~/Documents` or
the rest of the home directory, so a request in plain language such as "use
the document from X last week, reference document Y, then draft Z" fails
unless the owner first finds the files by hand.

Three gaps:

- No search by meaning, date or title across local documents, including PDF,
  Word and scanned files.
- No shared index: each agent would have to build its own, or none has one.
- No control over which documents may reach a cloud model. `~/Documents`
  holds `Credentials/`, `passport/`, recovery codes, `Finance/`, `Legal/` and
  `Family/`. Any text a cloud agent retrieves is sent to its provider.

Mail, calendar, tasks, meetings and notes are already reachable (Gmail and
Calendar MCP, `gog`, `meetingai`, `obsidian`). Local files are the missing
source.

## Proposed outcome

- The owner can ask any agent, in plain language, for a local document by
  meaning, by title or path, by folder, or by date ("from last week"), and the
  agent finds it, reads the relevant part and combines it with mail, calendar
  and tasks to do the job.
- The index updates itself when files are added, changed, moved or deleted,
  with no manual step.
- Embeddings and text extraction (including OCR of scanned documents) run on
  this machine through local Ollama. No document is uploaded to build the
  index.
- Two tiers:
  - **public**: folders the owner allowlists. Every agent may search them,
    cloud agents included.
  - **private**: everything else that is indexed. Only clients whose model
    runs locally (Ollama) may search it.
- A folder nobody has classified is private by default. Some paths are never
  indexed at all (credentials, passport scans, keys, `.env` files, agent
  configs, browser profiles).
- Every agent knows the index exists and when to use it, through the global
  agent instructions it already loads (`AGENTS.md`, `CLAUDE.md`).

## Affected users and systems

- Owner (only user).
- p620: first and primary host. Its Ollama keeps `qwen3.8:27b` resident with
  `MAX_LOADED_MODELS=1` (`hosts/p620/configuration.nix:145-148`), so index work
  must not evict it.
- razer: may later query p620's index; not in the first cut.
- p510: out of scope.
- Agent configuration: `home/development/claude-code-mcp.nix`,
  `home/development/antigravity-config.nix`, `home/development/codex-cli.nix`,
  `home/development/agent-rules.nix` and its rule files.
- Open WebUI: currently disabled (`hosts/p620/nixarchy/services.nix:44`); a
  candidate local-only client.

## Constraints

- Change as little of the OS as possible; nothing that works today may break.
  No new database server, container or flake input unless the spec shows it
  is needed.
- Follow repo rules: the service lives in `modules/` behind
  `features.<name>.enable`, imports are explicit, secrets load at runtime.
  System services must use `DynamicUser` and `ProtectHome`, which cannot read
  `/home`; the spec must either use a user service or justify an exception.
- The private tier must never be registered in a cloud-backed agent.
  Retrieved text is treated as untrusted data, never as instructions.
- The index files stay host-local and out of Syncthing (SQLite WAL files
  corrupt when synced live).
- Subscription logins only; no API keys (Issue 1831).
- Agents run unrestricted with passwordless sudo (Issue 2812). Any tier
  separation is therefore routing plus instructions, not an OS wall, unless
  the owner chooses otherwise below.

## Open questions

1. **Public folders:** which folders start in the public tier? Proposed:
   none at first, then add as needed, e.g. `Projects/`, `DevOps/`, `CV/`.
2. **Private-tier enforcement:** (a) routing plus a Claude PreToolUse hook
   that blocks direct reads of private folders, plus an `AGENTS.md` rule for
   Codex and agy (proposed); (b) also an encrypted `gocryptfs` vault for the
   most sensitive files; (c) a separate Unix user, which reverses parts of
   Issue 2812 and the sudo setup.
3. **Local client for the private tier:** enable Open WebUI on p620, run a
   local-model agent profile (Claude Code or opencode against Ollama), or
   both?
4. **Scope beyond `~/Documents`:** which other home folders are indexed, if
   any? `~/Downloads` is proposed as never indexed (untrusted files,
   prompt-injection risk). Are the Obsidian vaults in, given the `obsidian`
   skill already reads them?
5. **Adopt or build:** research favoured a small in-repo MCP package
   (SQLite FTS5 + `sqlite-vec`, all dependencies in nixpkgs) over adopting
   haiku.rag (unpackaged, heavy Docling/LanceDB closure). The spec decides
   this; say now if you prefer one.
