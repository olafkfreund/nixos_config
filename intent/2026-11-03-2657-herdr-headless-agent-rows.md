---
status: draft
issue: 2657
author: olafkfreund
---

# Intent: Codex and agy runs show in the herdr sidebar under their Claude lead

## Problem

A Claude session in herdr starts Codex and agy in the background: the
`second-opinion` reviews (`codex exec`, `codex review`, `agy --mode plan`) and
the `handoff` implementations through `agent-run` (`codex-implement`,
`agy-implement`). These runs have no pane, so the herdr sidebar never shows
them. While one runs, which can take up to 15 minutes, the user cannot see
that it exists, whether it is still working, or watch its output. Claude
agent-team teammates already appear as `↳ <name>` rows under their lead
(#2616, #2633). Codex and agy runs do not.

Agent-tool subagents are out of scope. They run inside the Claude process,
and zoetrope already shows them.

## Proposed outcome

When a Claude session running inside herdr starts a headless Codex or agy run:

- A row labelled `↳ codex` or `↳ agy` appears directly under the lead's row,
  with that tool's logo, and shows working while the run lasts and done after.
- The run's live output can be watched in its own tab, and that tab never
  takes focus.
- The lead gets back exactly what it gets today: the same output files and
  exit code, and the same failure when a run times out or fails.
- When the run ends, the tab closes. A run interrupted with Ctrl-C or killed by
  its timeout closes its tab too.

Outside herdr, the commands behave exactly as they do now.

## Affected users and systems

- p620 and razer: the hosts where Claude runs inside herdr. p510 runs
  claude-code but is not deployed without asking.
- `~/.claude/skills/second-opinion` and `~/.claude/skills/handoff`, and
  `home/development/agent-run.sh`.
- The herdr sidebar configuration in `home/development/herdr.nix`, only if the
  spec needs it.

## Constraints

- The review safety guards stay exactly as they are: `-s read-only`,
  `-c sandbox_mode="read-only"`, `--mode plan`, the `env -u` API-key guards and
  `forced_login_method=chatgpt`. `codex-implement` and `agy-implement` keep
  their own guards unchanged.
- Close only panes and tabs this mechanism created, identified by the ID herdr
  returned when it created them.
- Showing a row is cosmetic. If herdr is missing or a call fails, the run goes
  ahead headless as it does today.
- The prompt never travels as text typed into a pane: agy's prompt can be up
  to about 100 KB.

## Findings from the 2026-11-03 spike (live on p620)

- A headless `codex exec` in a pane is **not** detected as an agent
  (`agent: null`). It needs `herdr pane report-agent --agent codex --state
  working|idle`, which then shows as working, then done.
- herdr-radar overwrites a `split_mark` token sent once. Re-sending it at
  about 2, 6 and 15 seconds keeps it, as the teammate shim's `relabel.py`
  already does.
- `tab.move` (socket only, not in the CLI) places the tab right after the
  lead's, and the row then sorts under the lead.
- The row's title is the terminal title. An OSC 0 escape from the runner sets
  it.
- A command sent with `herdr pane run` before the new shell shows its prompt
  is lost. The run must wait for the prompt.
- The exit code is passed back through a status file written last. `pane
  wait-output` matches screen text and cannot report success or failure.

## Open questions

1. Should the tab close as soon as the run ends, or stay for a few seconds
   so the result can be read? The draft says close it at once: the output is
   in the lead's files anyway.
2. Two parallel reviews means two tabs. Is that acceptable, or should both
   reviewers share one tab as two split panes?
