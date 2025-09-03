# Virtualization Packages
# Container and VM management tools
# Compliant with NIXOS-ANTI-PATTERNS.md
{ config, lib, pkgs, ... }:
let
  cfg = config.packages.virtualization;
  # Import existing virtualization package sets
  packageSets = import ../../packages/sets.nix { inherit pkgs lib; };
in
{
  options.packages.virtualization = {
    enable = lib.mkEnableOption "Virtualization packages";

    docker = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Docker tools (headless-compatible)";
    };

    vm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable VM management tools";
    };

    kubernetes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Kubernetes tools (headless-compatible)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      # Docker tools (headless-compatible)
      lib.optionals cfg.docker packageSets.virtualization.docker

      # Kubernetes tools (headless-compatible)
      ++ lib.optionals cfg.kubernetes packageSets.virtualization.kubernetes

      # VM management tools (mix of headless and GUI)
      ++ lib.optionals cfg.vm (
        # Headless VM tools
        [ qemu libvirt spice spice-protocol ]
        # GUI VM tools (only if desktop enabled)
        ++ lib.optionals (config.packages.desktop.enable or false) [ virt-manager spice-gtk ]
      );
  };
}
