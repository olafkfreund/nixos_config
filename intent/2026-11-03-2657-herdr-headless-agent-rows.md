---
status: draft
issue: 2657
author: olafkfreund
---

# Intent: Codex and agy runs show in the herdr sidebar under their Claude lead

## Problem

A Claude session in herdr starts Codex and agy in the background, in these
ways:

- `second-opinion` reviews: `codex exec`, `codex review`, `agy --mode plan`
  and `agy --agent <name> --mode plan`.
- `handoff` implementations: `agent-run` (`codex-implement`,
  `agy-implement`), and `agy-implement --model <name>` run directly.

These runs have no pane, so the herdr sidebar never shows them. A review
takes up to 15 minutes. An implementation can take over 40: `agent-run`
gives agy 20 minutes per attempt and retries once, and a new agy version
adds a guard probe of about 90 seconds. All that time the user cannot see
that the run exists or whether it is still working. Claude agent-team
teammates already appear as `↳ <name>` rows under their lead (#2616, #2633).
Codex and agy runs do not.

Agent-tool subagents are out of scope. They run inside the Claude process,
and zoetrope already shows them.

## Proposed outcome

When a Claude session running inside herdr starts any of the runs above:

- A row labelled `↳ codex` or `↳ agy` appears directly under the lead's row,
  after any teammate rows already there, and shows working while the run lasts.
- When the run ends, the row shows done for a few seconds, so the end can be
  seen, and then its tab closes.
- The run's tab shows whatever progress the tool prints while it works.
  Output the lead captures as a file today (agy's JSON, Codex's final message)
  is not promised on screen. The tab never takes focus.
- The lead gets back exactly what it gets today: the same output files and
  exit code, and the same failure when a run times out or fails.
- A run interrupted with Ctrl-C or killed by its timeout stops the Codex or
  agy process too, not just its tab, and closes the tab.
- Two runs at once, such as a parallel Codex and agy review, each get their
  own row, and neither lands somewhere else or replaces the other.

Outside herdr, the commands behave exactly as they do now.

## Affected users and systems

- p620 and razer: the hosts where Claude runs inside herdr. p510 runs
  claude-code but is not deployed without asking.
- The `second-opinion` and `handoff` skills, which are Nix-managed under
  `home/development/claude-code-skills/` (not edited in `~/.claude/skills`).
- `home/development/agent-run.sh`.
- The herdr sidebar configuration in `home/development/herdr.nix`, only if
  codex or agy rows need their own row style or logo.

## Constraints

- The review safety guards stay exactly as they are: `-s read-only`,
  `-c sandbox_mode="read-only"`, `--mode plan`, the `env -u` API-key guards and
  `forced_login_method=chatgpt`. `codex-implement` and `agy-implement` keep
  their own guards unchanged.
- **Each run happens exactly once.** A herdr failure at any point, before or
  after the run starts, must never cause it to run a second time, and must not
  skip `agent-run`'s retry rule or its six result checks.
- Close only panes and tabs this mechanism created, identified by the ID herdr
  returned when it created them.
- Showing a row is cosmetic. If herdr is missing or a call fails before the
  run starts, the run goes ahead headless as it does today.
- The prompt never travels as text typed into a pane: agy's prompt can be up
  to about 100 KB.

## Evidence from the 2026-11-03 spike (live on p620)

These are observations, for the spec to use or replace. They are not design
decisions.

- A headless `codex exec` in a pane is **not** detected as an agent
  (`agent: null`). After `herdr pane report-agent --agent codex --state
  working`, it showed as working, then done after `--state idle`. The same
  worked with `--agent agy`. Whether herdr draws a real logo for either was
  not checked on screen.
- herdr-radar overwrote a `split_mark` token sent once. Re-sending it at
  about 2, 6 and 15 seconds kept it, as the teammate shim's `relabel.py`
  does.
- Moving the tab with the socket's `tab.move` to just after the lead's tab
  sorted the row under the lead.
- The row's title is the terminal title, which an OSC 0 escape set.
- A command sent with `herdr pane run` before the new shell showed its
  prompt was lost.
- `pane wait-output` matches screen text and cannot report success or
  failure, so the exit code came back through a file the runner wrote last.

## Open questions

1. How long should the done row stay visible before its tab closes? The draft
   says a few seconds.
