---
status: approved
issue: 2019
intent: intent/2026-09-24-2019-nixarchy-menu-razer-p620.md
---

# Spec: nixarchy-menu is the menu on razer and p620, declared rather than hand-copied

## Decisions on the intent's open questions

The intent was approved without answers, so these are the defaults it
proposed. Either can be changed at this gate.

1. **One PR** for both hosts, sharing the one lock bump. Deployed razer first,
   then p620 once razer checks out.
2. **Bump now to nixarchy `8333f23`.** nixarchy main's `build` job is red on a
   pre-existing ledger row (`omarchy-shell`, from nixarchy#975). That is a
   repository check, not part of the system build. Hosts on 8333f23 build and
   behave the same whether or not that row lands.

## Design

### 1. The lock (`flake.lock`)

Run `nix flake update nixarchy`, which moves the input a5460e2 → 8333f23 and
nothing else. That brings in nine nixarchy commits:

| Commit | Change | Effect here |
|---|---|---|
| 8333f23 | nixarchy#946: nixarchy-menu as an opt-in default | the point of this change |
| 82b144a | plugin-browser 0.5.1 | a default plugin's pin |
| 26de44c | herdr 3b789dd (#973) | a default plugin's pin; 53759c has a razer deploy queued for exactly this |
| d9fc8b0 / c7b9aad | apply confirmation, then reverted (#970, #977) | net: no change |
| 23fabd7 | shell IPC finds the running shell (#975) | the `omarchy-shell` fix whose ledger row is missing |
| 88e9665 | each Default Agent row records its agent (#972) | the menu picker |
| 13a0083 | a user plugin directory shadowing a declared one is named, not moved (#968) | matches razer's hand copy: reported, not replaced |
| 5bfea6c | apply's flake can be read without the module system (#969) | tooling |

The bump also creates the nixarchy-menu lock node that nixarchy#946 added. Its
`nixpkgs` and `omarchy` follow nixarchy's own, so no second nixpkgs appears.

### 2. The opt-in, one line per host

`hosts/razer/nixos/nixarchy.nix` and `hosts/p620/nixos/nixarchy.nix` each get
this, next to `programs.nixarchy.user = "olafkfreund";`:

```nix
# nixarchy-menu as the Omarchy menu (#2019, nixarchy#946). Remove to go back
# to the stock menu at the next login.
home-manager.users.olafkfreund.programs.nixarchy.defaultPlugins.menu = true;
```

This is the exact line tested on razer. Other `defaultPlugins` names keep
their defaults, because nixarchy#946 made the default per entry.

### 3. razer's hand copy (manual, once, during the razer deploy)

`~/.config/omarchy/plugins/nixarchy.menu` is a real directory, and nixarchy
leaves a real directory at a declared id alone (#968 names it in the log). So
during the razer deploy:
- `mv` it to `~/dev/nixarchy-menu-hand-copy.bak`, a backup rather than a
  delete
- restart `home-manager-olafkfreund`, which places the store link
- the default-plugins hook enables it in the menu's slot, which the next login
  or a manual run of the hook triggers

`evindor.keystroke` is already disabled there, and the hook would turn it off
anyway. p620 has no copy, so there is nothing to do there.

## Alternatives rejected

- **Two PRs, one per host:** both share one lock bump, so two PRs would either
  duplicate it or order one behind the other for no gain.
- **Wait for nixarchy main to go green:** that blocks on an unrelated ledger
  row. The system closure is the same either way.
- **Leave razer's hand copy and rely on the log hint:** the intent requires
  that nothing outranks the declared plugin.
- **A host-independent module turning it on for every nixarchy host:** out of
  scope. The intent names razer and p620, and p510 is never deployed without
  asking.

## Risks

- **The bump brings eight other commits.** All are merged and CI-checked in
  nixarchy apart from the ledger row. The herdr and plugin-browser pins change
  panels on both hosts. `just test-host` builds both before anything deploys.
- **53759c's queued razer deploy of nixarchy main** (herdr 3b789dd) overlaps
  this bump. The bus says who goes first, and whoever deploys second finds the
  bump already applied.
- **p620 is the user's working desktop.** The switch restarts HM and the
  default-plugins hook changes the menu at login. It is deployed only after
  razer passes and with the user's go-ahead, and it rolls back with
  `nixos-rebuild switch --rollback` or by removing the line.
- **Closure.** The plugin, the Smart Match engine and both models add about
  84.7 MiB per host.

## Verification

1. **Build:** `just validate`, `just test-host razer` and `just test-host p620`
   all pass on the branch, and the PR's CI is green.
2. **razer** (claimed on the bus, deployed with `just deploy-via-p620 razer`
   after merge):
   - The plugin path is a `/nix/store` link.
   - `omarchy-plugin-list` shows `nixarchy.menu` enabled and `omarchy.menu`
     and `evindor.keystroke` disabled.
   - The bar's menu button is in the same slot.
   - `omarchy-menu toggle root` opens nixarchy-menu.
   - 0 failed units, and exactly one new generation.
3. **p620** (after razer, with the user's go-ahead, `just p620`): the same
   checks, where "before" is the stock menu button's slot.
