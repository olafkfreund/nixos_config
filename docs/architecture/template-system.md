# Host Template System

## The problem

Three hosts, each historically carrying its own near-identical import list and
boilerplate. Adding a module meant editing every host; the lists drifted.

## The solution

A **single parameterised template** at `hosts/templates/desktop.nix`, surfaced
through `lib/hostTypes.nix` as two entry points:

- `hostTypes.workstation` — used by **p620** and **p510**
- `hostTypes.laptop` — used by **razer**

The template takes one argument, `profile`, and imports the entire module tree
plus the five `hosts/common/nixos` fragments every host needs (`i18n`, `envvar`,
`host-class`, `zfs-import`, `inotify-limits`). Profile-specific behaviour is
applied with `lib.mkIf`.

```nix
{ profile ? "workstation" }:
{ lib, ... }:
{
  imports = [
    ../common/nixos/i18n.nix
    # ... the other four common fragments and ../../modules/*.nix
  ];

  config = lib.mkMerge [
    {
      features.security.enable = lib.mkDefault true;
      services.displayManager.defaultSession = lib.mkDefault "omarchy";
      system.stateVersion = lib.mkDefault "25.11";
      # ... every setting the three hosts share, each at mkDefault
    }
    (lib.mkIf (profile == "laptop") {
      services.thermald.enable = lib.mkDefault true;
    })
  ];
}
```

## Three shared places

Configuration that two or three hosts set identically lives in one file
(Issue #2932). A host file lists only what is its own.

| File | Imported by | Holds |
| ---- | ----------- | ----- |
| `hosts/templates/desktop.nix` | all hosts | security, Syncthing, GNOME Remote Desktop, SDDM + Omarchy session, GNOME, X server, `system.stateVersion`, API keys, `features.ai`, droidcam off |
| `hosts/common/nixos/dev-workstation.nix` | p620, razer | development, virtualization, cloud, MCP servers, desktop programs, Claude Code, agent voice, craft apps, screenshot MCP, playerctld, fwupd, ydotool |
| `hosts/common/nixos/omarchy-desktop.nix` | `hosts/{p620,razer}/nixos/nixarchy.nix` | the identical `programs.nixarchy` settings, the Hyprland portal override, plugin sources and companion plugins |

Stays per host, on purpose:

- Every `environment.systemPackages` list and other list values whose order
  matters: a list moved into another file merges at that file's position and
  can change the system.
- Module imports whose move changed a host's derivation:
  `modules/development/default.nix`, `modules/secrets/api-keys.nix`, and on
  p620/razer the secrets, meeting-transcribe, agent-voice and swarm-reaper
  imports.
- Hardware, GPU, network, firewall, NFS, users, `age.identityPaths`, signing
  keys, `nixpkgs.config`, the `omarchy-*` import lists, and anything only one
  host sets (all of p510's service selection).
- A host that differs from a shared value overrides it in its own file
  (the template uses `mkDefault`; `dev-workstation.nix` leaves differing
  options out).

Every move was proven with `scripts/config-snapshot.sh` (see
`scripts/README.md`): the revision-pinned system `.drv` of each host was
identical before and after.

## How a host wires in

`lib/hostTypes.nix` wraps the template as an `imports` list:

```nix
workstation.imports = [ (desktopTemplate "workstation") ];
```

A host's `configuration.nix` then imports the host type and declares only what
is unique to it.

!!! note "Why `mkDefault` everywhere"
    The template sets defaults, not hard values. A host that needs something
    different (e.g. p510 disabling Omarchy's desktop preinstalls to save disk)
    overrides cleanly without fighting the template.

## A server from the same template

p510 is the always-on media server, yet it uses the **workstation** template.
Rather than maintain a separate `server` template (the old
`server`/`hybrid`/`base` templates were removed), it sets
`host.class = "workstation"` and overrides only the handful of things that
genuinely differ — currently `programs.nixarchy.preinstalls = false` and
autologin on.

It was headless until 2026-08-31, when it gained a monitor and the Omarchy
session; the `headless-rdp` value of `host.class` remains in the enum but no host
uses it. See [p510](../hosts/p510.md).

This keeps one template instead of three and avoids the divergence that the
template system exists to prevent.

## Adding a new host

1. Create `hosts/<name>/` with `variables.nix` and
   `hardware-configuration.nix`.
2. Import the appropriate host type (`hostTypes.workstation` or
   `hostTypes.laptop`).
3. Declare host-unique bits (GPU profile, monitors, host-specific features).
   A development desktop like p620 or razer also imports
   `hosts/common/nixos/dev-workstation.nix`.
4. Register it in `flake.nix` (`hostUsers`).
5. Add the host SSH key to `secrets.nix` and rekey.

Full procedure: [Adding a Host](../guides/HOST_SETUP.md).
