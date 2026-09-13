---
name: notebooklm
description: >-
  Drive Google NotebookLM from inside the agent — ask questions of a notebook
  and get sourced answers, add sources (URLs, PDFs, text), and generate then
  download artifacts (audio overview, video, report, mind map, slide deck,
  infographic, data table). Use for research against a notebook's own sources
  rather than the open web. Triggers on `/notebooklm`, `/nlm`, "ask my
  notebook", "what do my sources say about X", "add this to NotebookLM",
  "make an audio overview / podcast / study guide / mind map", "download the
  report", or any mention of NotebookLM, `nlm`, or a notebook by alias.
version: 0.1.0
category: research
tags: [notebooklm, google, research, mcp, artifacts, cli]
recommended_skills: []
platforms:
  - claude-code
  - codex
  - gemini
---

# notebooklm — research notebooks as tools

Two interfaces to the same account, both installed on p620 and razer:

| Interface | What it is | When to use |
| --- | --- | --- |
| **MCP server** `notebooklm` | 49 tools, declared in `features.ai.mcp.notebooklm` | **Default.** Structured results, no shell parsing. |
| **`nlm` CLI** | the same tool as a command | Anything the MCP tools don't expose, and all auth work. |

Prefer the MCP tools when they cover the job. Drop to `nlm` for auth, for
`usage`, and for flags the tools don't surface.

## The full command surface is self-documenting — use it

Do **not** guess flags, and do not trust this file over the binary:

```bash
nlm --ai                  # ~1000 lines of AI-oriented docs for the whole CLI
nlm <area> --help         # per-command flags
```

This file deliberately does not copy that surface, because it changes every
few days — upstream ships often and a nightly job follows it. This file holds
only what the upstream docs cannot know: how it is set up here, and the traps.

Both command styles work: noun-first (`nlm notebook list`) and verb-first
(`nlm list notebooks`). Pick one and stay consistent within a task.

## Getting an answer out of a notebook

This is the common request — "what do my sources say about X":

```bash
nlm notebook query <notebook> "question"
```

Answers are grounded in that notebook's sources, not the open web. That is the
whole point of reaching for this instead of a search tool: if the user wants
public information, a web search is the right tool and this is the wrong one.

Query history persists into the NotebookLM web UI, so the user can pick up the
same conversation there. Mention that only if relevant.

## Aliases — use them, UUIDs are unusable

Notebook ids are UUIDs. Set an alias once and use it everywhere after:

```bash
nlm alias set myproject <uuid>
nlm alias list
nlm notebook query myproject "question"
```

When the user names a notebook in prose, resolve it with `nlm alias list` or
`nlm notebook list --title` before assuming an id.

## Artifacts are asynchronous — three steps, not one

Generation does not return a file. Never promise the user an artifact until
you have downloaded it.

```bash
# 1. generate (--confirm is required; it is a spend gate, not decoration)
nlm audio create <notebook> --confirm            # also: video, report, mindmap
# 2. poll until the status says completed
nlm studio status <notebook>
# 3. download, by artifact id from the status output
nlm download audio <notebook> --id <artifact-id>
```

Formats: audio `.mp3`, video `.mp4`, report `.txt`/`.md`, mind map `.txt`,
slide deck `.txt` (or `--format pptx`), infographic `.png`, data table `.csv`.

Report formats include "Briefing Doc", "Study Guide", "Blog Post", and
"Create Your Own" with `--prompt`.

**Write artifacts to a temporary directory or a path the user names** — never
into a git repo by default, and say where the file landed.

## Check the budget before generating

Artifact generation is rate-limited on a rolling ~5-hour window with a weekly
cap, and an audio or video is expensive:

```bash
nlm usage            # human-readable; reset times in local timezone
nlm usage --json     # ISO 8601 UTC
```

Check this before generating anything heavy, and before telling the user a
generation failed — "rate limited" and "broken" look identical otherwise.

## Auth — and what not to panic about

Credentials are a live Google session cookie extracted from a browser, stored
in `~/.notebooklm-mcp-cli/` (mode 0700). That path is **outside** the Syncthing
folders, so each host is authenticated separately — p620 being logged in says
nothing about razer.

```bash
nlm login --check     # validates by making a real API call
nlm login             # interactive: opens a browser, extracts cookies
nlm auth refresh      # non-interactive headless refresh, for unattended use
```

Three traps, in the order they bite:

- **`nlm login` needs a browser and a human.** It cannot be completed for the
  user from a non-interactive shell — ask them to run it and stop.
- **An `unverified` auth health result is not expiry.** Cookies usually stay
  good for weeks. The CLI also self-recovers: CSRF refresh on 401, token
  reload from disk, headless re-auth, and retries on 429/500/502/503/504 with
  backoff. So a single failure is not a reason to re-authenticate — only run
  `nlm login` when `--check` actually fails.
- Cookies **do** expire every few weeks, per host. That is the real cause when
  everything suddenly fails.

## Safety

- This is an **unofficial** client against undocumented internal APIs. It
  breaks on Google's schedule. Report a failure plainly rather than working
  around it with invented flags.
- The cookie carries full account power. **Never print it**, and never cat
  anything under `~/.notebooklm-mcp-cli/`.
- Creating notebooks and adding sources is cheap and reversible. **Deleting a
  notebook or a source is not** — confirm with the user first, every time.
- `--confirm` on a generate command means real compute against the user's
  quota. Do not add it speculatively to "see if it works".

## Output discipline

Answer the user's question in prose, with the notebook's own wording where it
matters. Don't dump raw JSON, don't paste a whole report when asked for a
summary, and always say which notebook an answer came from.
