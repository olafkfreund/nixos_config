---
status: draft
issue: 1995
intent: intent/2026-09-23-1995-plugin-browser-key.md
---

# Spec: Super+Alt+U opens the Plugin Browser again on p620 and razer

## Decision on the intent's open question

**A key-only module**, `hosts/common/nixos/omarchy-plugin-browser.nix`,
imported again by p620 and razer. This is the shape of `omarchy-gog.nix`,
which does the same job for its own keys: one place, found by name.

## Design

`hosts/common/nixos/omarchy-plugin-browser.nix`, new, in full:

```nix
# Super+Alt+U for the Plugin Browser, on homes whose bindings.lua predates it.
#
# nixarchy ships the plugin and its Setup > Plugins > Add Plugin row
# (olafkfreund/nixarchy#915), and seeds Super+Alt+U into bindings.lua, but
# only for NEW homes: nixarchy never edits an existing bindings.lua. #1991
# dropped this file on the belief that nixarchy binds the key everywhere;
# that left p620 and razer with none (#1995).
#
# Only the key lives here. The menu row is nixarchy's own, and overriding
# it again would lose its `when` guard and aliases.
#
# The key rides in its own lua file for the reason omarchy-gog.nix gives:
# bindings.lua stays user-owned and keeps one hand-written
#   pcall(require, "hypr.plugin-browser-binds")
# (already there on p620 and razer), and pcall, not require, so a rollback
# that drops this file cannot take the whole Hyprland config down.
# `nixarchy-plugin` rather than a bare toggle, as nixarchy's own binds: a
# turned-off plugin is named in a notification, not toggled silently.
{ ... }:
{
  home-manager.users.olafkfreund.home.file.".config/hypr/plugin-browser-binds.lua".text = ''
    -- Managed by hosts/common/nixos/omarchy-plugin-browser.nix -- edits here
    -- are overwritten on the next deploy.
    o.bind("SUPER + ALT + U", "Plugin browser", "nixarchy-plugin io.github.olafkfreund.nixarchy-plugin-browser")
  '';
}
```

`hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix` each
get the import back, beside `../../common/nixos/omarchy-gog.nix`. That is
exactly the line #1991 removed.

This is the same module that ran on razer during the #915 test earlier
today (`x7g7i72b…`): the key file was written, and it bound
`nixarchy-plugin <id>`.

## Alternatives rejected

- **A `home.file` line in each host file.** Two copies of one comment and
  one line, which drift apart. The module is also the place a later reader
  looks, by name.
- **Edit `bindings.lua` on each host.** That file is user-owned and not
  generated, and it would sit outside the flake. The existing `pcall` line
  already makes it unnecessary.
- **Restore the old module whole,** with the `extraEntries` row. That brings
  back the override #1991 was right to drop.
- **Fix it in nixarchy** (have nixarchy write a binds file for every home).
  That is a real gap for any existing nixarchy home, but a nixarchy design
  change, not this repo's. It can be raised there separately, and this file
  goes away if it lands.

## Risks

- **A double bind** if a host's `bindings.lua` also had the seeded line.
  p620 and razer don't (checked: `hyprctl binds` shows 0 for Super+Alt+U on
  razer; p620's `bindings.lua` has only the `pcall`). If one ever does,
  Hyprland binds the key twice and it toggles twice (open, then close).
  The comment says so.
- **Home Manager collision:** none. The path is free on both hosts since
  #1991's deploy (checked on p620 and razer).
- **The key needs a re-login** to take effect, like every bind change.

## Verification

- `nix eval` of both hosts' Home Manager `home.file` shows
  `.config/hypr/plugin-browser-binds.lua` with the `nixarchy-plugin` line;
  p510 does not have it.
- `nix build` of both toplevels. A closure diff by name against the running
  system shows only the Home Manager file.
- Deploy (announced, diffed): the file exists on both hosts. After a
  re-login, `hyprctl binds` shows Super+Alt+U → `nixarchy-plugin …` on razer,
  and pressing it opens the panel (ai-mirror, owner-granted).
