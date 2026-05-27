# Host Template System

## The problem

Three hosts, each historically carrying its own near-identical import list and
boilerplate. Adding a module meant editing every host; the lists drifted.

## The solution

A **single parameterised template** at `hosts/templates/desktop.nix`, surfaced
through `lib/hostTypes.nix` as two entry points:

- `hostTypes.workstation` — used by **p620** and **p510**
- `hostTypes.laptop` — used by **razer**

The template takes one argument, `profile`, and imports the entire module tree.
Profile-specific behaviour is applied with `lib.mkIf`.

```nix
{ profile ? "workstation" }:
{ lib, ... }:
{
  imports = [
    ../../modules/core.nix
    ../../modules/development.nix
    ../../modules/desktop.nix
    ../../modules/virtualization.nix
    ../../modules/performance.nix
    ../../modules/email.nix
    ../../modules/cloud.nix
    ../../modules/programs.nix
    ../../modules/common/ai-defaults.nix
    ../../modules/windows/winboat.nix
  ];

  config = lib.mkMerge [
    {
      aiDefaults.enable = lib.mkDefault true;
      services.openssh.enable = lib.mkDefault true;
    }
    (lib.mkIf (profile == "laptop") {
      services.thermald.enable = lib.mkDefault true;
      powerManagement = {
        enable = lib.mkDefault true;
        cpuFreqGovernor = lib.mkDefault "powersave";
      };
    })
  ];
}
```

## How a host wires in

`lib/hostTypes.nix` wraps the template and layers on sensible feature defaults
that a host can still override with `mkForce`:

```nix
workstation = {
  imports = [ (desktopTemplate "workstation") ];
  config = {
    aiDefaults.profile = "workstation";
    features = {
      development.enable = lib.mkDefault true;
      desktop.enable = lib.mkDefault true;
      virtualization.enable = lib.mkDefault true;
    };
  };
};
```

A host's `configuration.nix` then imports the host type and declares only what
is unique to it.

!!! note "Why `mkDefault` everywhere"
    The template sets defaults, not hard values. A host that needs something
    different (e.g. p510 running headless with no display manager) overrides
    cleanly without fighting the template.

## Headless from the same template

p510 is a server, yet it uses the **workstation** template. Rather than
maintain a separate `server` template (the old `server`/`hybrid`/`base`
templates were removed), p510 simply:

- sets `host.class = "workstation"`,
- disables the display manager and desktop compositor,
- enables GNOME Remote Desktop for the rare time a GUI is needed.

This keeps one template instead of three and avoids the divergence that the
template system exists to prevent.

## Adding a new host

1. Create `hosts/<name>/` with `variables.nix` and
   `hardware-configuration.nix`.
2. Import the appropriate host type (`hostTypes.workstation` or
   `hostTypes.laptop`).
3. Declare host-unique bits (GPU profile, monitors, host-specific features).
4. Register it in `flake.nix` (`hostUsers`, `hardwareProfiles`).
5. Add the host SSH key to `secrets/secrets.nix` and rekey.

Full procedure: [Adding a Host](../guides/HOST_SETUP.md).
