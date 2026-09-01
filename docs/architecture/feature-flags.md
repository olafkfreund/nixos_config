# Feature Flags

## The problem

Enabling a capability often means configuring several services together. Doing
that inline in each host file produces copy-paste, drift, and no way to validate
that prerequisites are met.

## The solution

Capabilities are exposed as **typed feature flags** under `features.*`. A host
turns a dial; the module behind it wires up the actual services. The shared
option declarations live in
[`modules/common/features.nix`](https://github.com/olafkfreund/nixos_config/blob/main/modules/common/features.nix),
which groups them as `development`, `virtualization`, `cloud`, `security`,
`networking`, `ai`, `programs`, `media` and `quickshell`. Individual services
declare their own flag in their own module instead.

```nix
# In a host configuration.nix — declarative intent, not implementation
features = {
  development.enable = true;
  virtualization = {
    enable = true;
    docker = true;
  };
  ai.enable = true;
  media.enable = true;
  syncthing.enable = true;
};
```

## How a feature module is shaped

Every module follows the same contract: declare options, then apply config only
when enabled.

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.features.myservice;
in
{
  options.features.myservice = {
    enable = lib.mkEnableOption "MyService";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port MyService listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.myservice = {
      enable = true;
      port = cfg.port;
    };
  };
}
```

!!! warning "Never configure services directly in a host"
    `services.foo = { … }` in `hosts/*/configuration.nix` defeats reuse and
    testing. Wrap it in a module under `modules/` and expose a feature flag.
    This is a hard rule — see [Anti-Patterns](../NIXOS-ANTI-PATTERNS.md).

## Host types

There is no central registry of feature dependencies or conflicts, and no
cross-feature validation pass — a module that needs a prerequisite asserts it
itself, with `assertions`.

What does exist is
[`lib/hostTypes.nix`](https://github.com/olafkfreund/nixos_config/blob/main/lib/hostTypes.nix),
which pre-composes flags for a role. Two types are defined:

| Type | Sets |
| --- | --- |
| `workstation` | `development`, `desktop`, `virtualization` |
| `laptop` | `development`, `desktop`, `virtualization` (no Docker), `powerManagement` |

Both are set with `lib.mkDefault`, so a host that assigns the flag directly
always wins:

```nix
# hosts/razer/configuration.nix — overrides the laptop default
features.virtualization.docker = true;
```

Each host imports one type plus its own hardware configuration.

## Browsing what exists

The full set of feature-flagged modules — every option, with its description
and the source — is in the generated [Modules reference](../reference/modules/index.md).
