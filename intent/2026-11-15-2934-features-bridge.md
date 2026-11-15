---
status: draft
issue: 2934
author: olafkfreund
---

# Intent: one option layer for fleet features

## Problem

Feature switches exist twice. `modules/common/features.nix` declares bare booleans (`features.development.go`), and
`modules/common/features-impl.nix:27-77` copies each into a second option in another namespace that the module
actually reads: `go.development.enable`, `modules.development.python.enable`, `aws.packages.enable`,
`services.podman.enable`, `modules.containers.docker.enable`, `media.droidcam.enable`, and more. Hosts set both
layers (`features.virtualization.docker` and `modules.containers.docker.enable`). Several of those second options sit
under upstream roots (`services.podman`, `programs.obsidian`, `security.gnupg`, `nix.development`,
`system.logging`, `networking.profile`), where a future nixpkgs or Home Manager option at the same path would
collide. Home Manager repeats the pattern (`Users/common/features{,-impl}.nix` → bare `alacritty`, `editor.*`,
`browsers.*`, `cli.*`). A reader has to follow two hops to learn what a switch does, and `features-impl.nix` is
imported twice on the Home Manager side.

## Proposed outcome

Each bridged module reads its `features.*` switch directly; the bridge files are gone; the custom options found
under upstream roots in these modules (`services.{podman,incus,libvirt,spice,print}`, `programs.{obsidian,office,webcam,winboat,aerion}`,
`security.{gnupg,onepassword}`, `nix.development`, `system.logging`, `networking.{profile,stableConnection}`) move to
`features.*`. Docker and unbridged modules are out of scope. Every host builds exactly the same system.

## Affected users and systems

`modules/`, `home/`, `Users/common/`, the three host files (only where they set an old path).

## Constraints

- Behaviour-preserving: `scripts/config-snapshot.sh` `IDENTICAL` on p620, razer and p510 after every slice.
- Lands after #2932 and #2933 (they edit the same host files).
- Old paths that a host or user file still sets are migrated in the same slice; `mkRenamedOptionModule` only where an
  old path must keep working.

## Open questions

None.
