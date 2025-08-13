{ config, lib, pkgs, inputs, ... }:

with lib;
let
  cfg = config.features.desktop.hyprlandStack3d;
in
{
  options.features.desktop.hyprlandStack3d = {
    enable = mkEnableOption "Hyprland 3D Stack Animation Plugin";

    transitionDuration = mkOption {
      type = types.float;
      default = 0.8;
      description = "Duration of 3D transition animations in seconds";
    };

    transitionStyle = mkOption {
      type = types.enum [ "smooth_slide" "bounce" "elastic" ];
      default = "smooth_slide";
      description = "Style of transition animation";
    };

    defaultLayout = mkOption {
      type = types.enum [ "grid" "circular" "spiral" "fibonacci" ];
      default = "grid";
      description = "Default layout arrangement for 3D stack";
    };

    enablePhysics = mkOption {
      type = types.bool;
      default = true;
      description = "Enable physics-based motion animations";
    };

    perspectiveStrength = mkOption {
      type = types.float;
      default = 1.0;
      description = "Strength of 3D perspective effect (0.0-2.0)";
    };
  };

  config = mkIf cfg.enable {
    # Make the plugin package available to the system
    # The actual plugin configuration is done in Home Manager
    environment.systemPackages = [
      inputs.hyprland-stack3d.packages.${pkgs.system}.default
    ];

    # Pass plugin configuration to Home Manager via specialArgs
    home-manager.extraSpecialArgs = {
      hyprlandStack3dPlugin = inputs.hyprland-stack3d.packages.${pkgs.system}.default;
      hyprlandStack3dConfig = {
        enable = true;
        transition_duration = cfg.transitionDuration;
        transition_style = cfg.transitionStyle;
        default_layout = cfg.defaultLayout;
        enable_physics = cfg.enablePhysics;
        perspective_strength = cfg.perspectiveStrength;
      };
    };
  };
}
