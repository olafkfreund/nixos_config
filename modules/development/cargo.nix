{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.development;
in
{
  config = mkIf (cfg.enable && cfg.cargo) {
    environment.systemPackages =
      [
        pkgs.cargo
        pkgs.rust-analyzer
        pkgs.cargo-ui
        pkgs.cargo-update
        pkgs.slumber
        # pkgs.openapi-tui  # Temporarily disabled - build fails with GCC 15 (onig_sys compatibility issue)
        pkgs.clipse
        pkgs.systemctl-tui
        pkgs.rustfmt
        pkgs.rustc
      ];
  };
}
