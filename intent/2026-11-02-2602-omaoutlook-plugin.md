---
status: draft
issue: 2602
author: olafkfreund
---

# Intent: Microsoft Outlook as an Omarchy plugin on p620 and razer

## Problem

Outlook on p620 and razer is a browser tab or web app with no unread badge in
the bar, no Omarchy look, and nothing that joins it to Omateams. The same
author has published [omaoutlook](https://github.com/Divanyx/omaoutlook) (MIT,
1.0.7, `ad934b6`, 2026-10-23). It is the Outlook web client in its own
Omarchy-themed window, with:

- an unread badge in the bar and new-mail and reminder notifications,
- links routed to the browser, and Teams join links routed to Omateams,
- a memory watchdog meant for weeks of uptime.

Upstream installs it by compiling the host app into `~/.local/share` at
runtime (`install.sh` and `ensureHost()`). That does not fit a declarative
NixOS setup, and it breaks on NixOS anyway.

## Proposed outcome

On p620 and razer, after a rebuild and one login:

- Omaoutlook shows in the bar with an unread badge.
- It starts hidden at login, so notifications and reminders work before you
  open it.
- Clicking the badge, or running `omaoutlook toggle`, opens Outlook in an
  Omarchy-themed window.
- Teams links in invitations open in Omateams, which is already installed.
- You sign in once per host. The login stays yours.
- Upgrades are a pinned rev and hash bump in this repo, never a runtime
  self-update.

This follows the omateams pattern (#2505) exactly.

## Affected users and systems

- The user, on p620 and razer. Not p510.
- New `pkgs/omaoutlook` and `hosts/common/nixos/omarchy-omaoutlook.nix`,
  imported from each host's `nixos/nixarchy.nix`.
- Reuses the shared `local.omarchy.enableOnce` module (#2503), so the plugin
  is enabled once at first login.
- `.claude/commands/check-updates.md` gains a row so bumps are tracked.

## Constraints

- Same shape as `pkgs/omateams`: the host app is built by Nix with qmake and
  Qt 6 WebEngine, the plugin never compiles anything, and `Service.qml` is
  patched to the store binary.
- No secrets in the Nix store. The Outlook login lives only in the user's
  data directory.
- Must not touch Chrome profiles or the existing Omateams login.
- p510 is never built or deployed without asking.

## Open questions

1. **mailto links.** Omaoutlook can make itself the desktop's `mailto:`
   handler. Today `mailto:` goes to the HEY web app (`home/browsers/chrome.nix`),
   and the MIME associations are managed by home-manager. A runtime toggle
   would therefore fail or fight the rebuild. Options: (a) keep HEY, and
   leave the setting off (upstream default); (b) make Omaoutlook the handler
   declaratively in home-manager.
2. **Which account and URL.** The default is
   `https://outlook.cloud.microsoft/mail/` (work or school, Microsoft 365).
   Is this the Synechron account, like Omateams, or something else (for
   example `outlook.live.com` for a personal account)?
3. **Bar icon.** Show the icon with the unread count (upstream default), or
   run hidden with a key binding only?
