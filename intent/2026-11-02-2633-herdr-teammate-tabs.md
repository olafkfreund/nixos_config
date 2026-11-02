---
status: draft
issue: 2633
author: olafkfreund
---

# Intent: Claude teammates open in a new herdr tab

## Problem

Since #2616, a Claude lead running in herdr starts each teammate (agent
teams) with a tmux `split-window`. The herdr-claude-teams shim turns that
into a herdr `pane.split` in the lead's own tab. Every teammate takes a
slice of that tab. Two or three teammates leave the managing pane, where
the user talks to the lead, too small to work in.

## Proposed outcome

- **Teammates get tabs:** each teammate opens in a new herdr tab in the
  lead's workspace. The lead's pane keeps its full size.
- **No focus steal:** creating a teammate tab does not take focus away from
  the lead.
- **Everything else from #2616 still works:**
  - the teammate is labelled `↳ <name>`;
  - it is recorded as owned;
  - its tab closes when the lead stops it;
  - the idle reaper closes it when it is left idle;
  - the user's own panes and tabs are never touched.
- **Same on both hosts:** p620 and razer, the two hosts that run
  herdr-claude-teams.

## Affected users and systems

- Hosts: p620 and razer. p510 is not affected.
- Code: the herdr-claude-teams package (`pkgs/herdr-claude-teams`, the
  pinned fork plus the local `ownership.patch`), specifically its
  `split-window` handling in `verbs.py`.
- Possibly `pkgs/claude-swarm-reaper`, if closing the last pane of a tab
  needs `tab.close` rather than `pane.close`.
- Docs: the herdr page that documents #2616.

## Constraints

- **Only owned objects:** the shim may close only panes and tabs it
  created.
- **Lead keeps focus:** Claude Code tracks teammate pane ids itself, and
  the shim must keep returning a pane id that later `send-keys`,
  `kill-pane` and `respawn-pane` calls resolve.
- **Build-time tests:** the fork's suite and the ownership tests keep
  running in the build, and the new behaviour gets its own test.
- **No other herdr users affected:** the herdr config stays as it is, and
  plain `claude` outside herdr is unchanged.
- **Deploys:** go through the agent-bus announcement. razer builds on
  p620.

## Open questions

- **The sidebar tree.** herdr-radar nests a teammate under its lead only
  when both are in the same tab. In separate tabs, the sidebar shows each
  teammate as its own tab row. With `agent_panel_sort = "spaces"`, those
  rows sit in tab order, and the `↳ <name>` label is kept. Is losing the
  indent under the lead acceptable, or should the tab be placed right
  after the lead's tab so the rows stay together?
- **Tabs everywhere?** Should tabs be the only behaviour, or a switch,
  with tab as the default and split still available?
