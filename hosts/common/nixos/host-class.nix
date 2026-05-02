{ lib, ... }:
let inherit (lib) mkOption types;
in {
  options.host.class = mkOption {
    type = types.enum [ "workstation" "laptop" "headless-rdp" ];
    description = ''
      The role this host plays. Modules consume this to gate decisions
      that should track host purpose rather than be set per-host.

      - workstation: full desktop, AC-only, no battery extensions
      - laptop:      full desktop, battery-aware, mobile features
      - headless-rdp: no interactive session; remote-only
    '';
    # No default — every host must declare its class explicitly. This
    # is intentional; getting it wrong silently is worse than a build
    # failure.
  };
}
