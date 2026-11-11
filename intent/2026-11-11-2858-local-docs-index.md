---
status: draft
issue: 2858
author: olafkfreund
---

# Intent: local document index searchable by all agents

## Problem

The coding agents on this fleet (Claude Code, Codex, agy) can find local
files by name with `rg`, `fd` and globs, and the `obsidian` skill reads the
vaults. What they cannot do is find a document by what it says, by when it
changed, or inside formats they cannot grep: PDF, Word, spreadsheets,
slides and scanned documents. A request in plain language such as "use the
document from X last week, reference document Y, then draft Z" therefore
fails unless the owner first finds the files by hand.

Two further gaps:

- No shared index: each agent would build its own, or none has one.
- No control over which documents reach a cloud model. `~/Documents` holds
  `Credentials/`, `passport/`, recovery codes, `Finance/`, `Legal/` and
  `Family/`. Any text a cloud-backed agent retrieves is sent to its provider.

Mail, calendar, tasks, meetings and notes are already reachable through
existing tools (Gmail and Calendar MCP, `gog`, `meetingai`, `obsidian`).
Local files are the missing source.

## Proposed outcome

On p620, when this is done:

- Claude Code, Codex and agy can search the **public** tier by meaning, by
  title or path, by folder, by file type, and by modification date ("changed
  last week" means file mtime). Each hit gives the path, the date and the
  relevant passage, and the agent can read more of that document on request.
  The agents combine hits with mail, calendar and tasks through the tools
  they already have; this task builds no new mail or task integration.
- At least one client that runs **local model weights only** can search both
  tiers. A hosted model, including Ollama's `*-cloud` / Turbo models (enabled
  on p620 through `cloudApiKeyFile`), never receives private-tier text.
- Private-tier documents are invisible to cloud-backed agents through the
  index: no passages, titles, paths or counts.
- The index keeps itself current with no manual step. A file added, changed,
  moved or deleted is reflected within 5 minutes, and a scheduled full pass
  catches anything missed.
- Moving a document out of the public tier, or into a never-indexed path,
  removes every derived item for it from the public tier (text, vectors,
  title, path) within the same bound.
- Building the index uploads nothing: text extraction, OCR of scanned pages
  and embeddings run on p620.
- Acceptance check: with a fixture folder of known documents in each tier, a
  scripted query set (by meaning, by title, by date, and a scanned PDF) returns
  the expected files from the right tier, and returns nothing from the
  private tier to a cloud client.

Tiers:

- **public**: folders the owner allowlists.
- **private**: indexed folders not allowlisted as public. A new or unclassified
  folder is private.
- **never indexed**: credentials, passport scans, recovery codes, keys,
  `.env` files, agent configs (`~/.claude`, `~/.codex`, `~/.gemini`), browser
  profiles, `~/Downloads`, and symlinks that leave an indexed folder.

Every agent with access to the public tier is told it exists and when to use
it, through the global instructions it already loads (`AGENTS.md`,
`CLAUDE.md`).

## Threat model

This task prevents **accidental disclosure through retrieval**: a cooperative
agent searching the index never receives private text. It does not contain an
agent that deliberately reads `~/Documents` directly; agents run without
sandboxes or approval prompts (Issue 2812) and the owner keeps passwordless
sudo. Blocking direct reads of sensitive folders is a separate workstation
containment problem and goes to a follow-up issue.

## Affected users and systems

- Owner (only user).
- p620: the only host in this cut. Its Ollama serves `0.0.0.0`, keeps
  `qwen3.8:27b` resident with `MAX_LOADED_MODELS=1`
  (`hosts/p620/configuration.nix:141-148`) and has hosted models enabled
  (`:166-168`). It is also the only self-hosted CI runner host.
- p510: not deployed, but its `audiobook-mcp` and `audiobook-import` use
  `qwen2.5:7b` on p620's Ollama (`hosts/p620/configuration.nix:149-152`).
  They must keep working.
- razer and p510 share the Home Manager developer profiles, so the MCP
  registration and agent rules must be gated to hosts that run the index.
- Agent configuration: `home/development/claude-code-mcp.nix`,
  `home/development/antigravity-config.nix`, `home/development/codex-cli.nix`,
  `home/development/agent-rules.nix` and its rule files.
- Open WebUI: disabled today (`hosts/p620/nixarchy/services.nix:44`); a
  candidate for the local-only client.
- Syncthing ignore rules and backup exclusions for the index files.
- Docs: a new page under `docs/` with nav in both `mkdocs.yml` and
  `mkdocs-full.yml`.

## Constraints

- Change as little of the OS as possible; nothing that works today may break.
  No new database server, container or flake input unless the spec shows it
  is needed.
- Index work must not evict `qwen3.8:27b` from VRAM, and must not stall CI
  runners or the desktop: the first full index is throttled.
- Repo rules: the service lives in `modules/` behind `features.<name>.enable`,
  imports are explicit, secrets load at runtime. A system service needs
  `DynamicUser`, `ProtectSystem = "strict"`, `ProtectHome`, `NoNewPrivileges`;
  since `ProtectHome` hides `/home`, the spec must use a user service or
  justify an exception.
- The indexer has read-only access to the documents it indexes. It never
  writes, moves or deletes them.
- Any listener binds to loopback only in this cut.
- The private tier is never registered in a cloud-backed agent. Retrieved text
  is untrusted data, never instructions.
- Index files stay host-local, out of Syncthing and out of backups, and are
  readable only by the owner.
- `just quick-test` passes for all hosts; razer and p510 get no dead MCP
  entries.
- Subscription logins only; no API keys (Issue 1831).

## Out of scope (follow-up issues)

- Blocking direct agent reads of sensitive folders (hook, encrypted vault,
  separate Unix user).
- razer querying p620's index.
- Wiring mail, calendar or tasks into the local-only client.

## Open questions

1. **Public folders:** which folders start public? Proposed: one or two you
   name now (e.g. `Projects/`, `DevOps/`), so the cloud agents have something
   to search at launch; the rest stays private.
2. **Local-only client:** enable Open WebUI on p620 (local models only), run a
   local-model agent profile against Ollama, or both?
3. **Scope beyond `~/Documents`:** which other home folders are indexed? Are
   the Obsidian vaults in?
4. **Languages:** English only, or also Norwegian or other languages, for
   search and OCR?
5. **Formats:** proposed first cut: Markdown, text, PDF (including scanned),
   `.docx`, `.odt`, `.xlsx`, `.csv`, `.pptx`, images. Email files (`.eml`)
   out, since mail is reached through Gmail. Agree?
