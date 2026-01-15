{ config, lib, pkgs, ... }:

let
  cfg = config.features.virtualization.waydroid;
in
{
  options.features.virtualization.waydroid = {
    enable = lib.mkEnableOption "Waydroid Android emulation";

    disableGbm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Disable GBM and mesa-drivers (required for NVIDIA GPUs).

        Set to true for systems with NVIDIA graphics cards or RX 6800 series.
        This is a critical requirement for Waydroid compatibility with NVIDIA.
      '';
    };

    enableWaydroidHelper = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable waydroid-helper systemd service for automated filesystem setup.

        Waydroid-helper provides the waydroid-mount service which automatically
        manages Waydroid's filesystem mounts. Available in NixOS 25.11+.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.waydroid-nftables;
      description = ''
        Waydroid package to use.

        Default is waydroid-nftables which includes patches for compatibility
        with newer Linux kernels that use nftables instead of iptables.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Waydroid virtualization
    virtualisation.waydroid = {
      enable = true;
      inherit (cfg) package;
    };

    # Install Waydroid and helper packages
    environment.systemPackages = with pkgs; [
      waydroid
    ] ++ lib.optionals cfg.enableWaydroidHelper [
      waydroid-helper
    ];

    # Enable waydroid-helper systemd service
    systemd = lib.mkIf cfg.enableWaydroidHelper {
      packages = [ pkgs.waydroid-helper ];
      services.waydroid-mount.wantedBy = [ "multi-user.target" ];
    };

    # NVIDIA-specific configuration
    # Disable GBM and set environment variables for NVIDIA compatibility
    environment.sessionVariables = lib.mkIf cfg.disableGbm {
      WLR_NO_HARDWARE_CURSORS = "1";
      WAYDROID_DISABLE_GBM = "1";
    };

    # Ensure required kernel modules are loaded
    boot.kernelModules = [
      "binder_linux"
      "ashmem_linux"
    ];

    # Security: Waydroid requires access to certain device nodes
    # This is managed automatically by the Waydroid package

    # Assertions for common configuration issues
    assertions = [
      {
        assertion = config.services.xserver.enable -> (config.services.displayManager.gdm.wayland or true);
        message = ''
          Waydroid requires a Wayland session to function properly.

          If using GDM, ensure Wayland is not disabled. Check that
          services.displayManager.gdm.wayland is not set to false.

          Waydroid cannot run in X11 sessions directly, but can run in
          a nested Wayland session using cage or weston.
        '';
      }
    ];

    # Warnings for optimal configuration
    warnings = lib.optional (!cfg.enableWaydroidHelper) ''
      Waydroid-helper is disabled. You will need to manually manage
      Waydroid filesystem mounts. Enable waydroid-helper for automatic
      mount management.
    '';
  };
}
