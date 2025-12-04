{ pkgs
, lib
, config
, ...
}:
with lib; let
  cfg = config.virt.nemu;
in
{
  options.virt.nemu = {
    enable = mkEnableOption "Nemu virtualization";

    users = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          autoAddVeth = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically add virtual ethernet interfaces for this user";
          };
          autoStartDaemon = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically start the Nemu daemon for this user";
          };
        };
      });
      default = { };
      description = "Users allowed to use Nemu";
    };

    vhostNetGroup = mkOption {
      type = types.str;
      default = "vhost";
      description = "Group for vhost-net access";
    };

    macvtapGroup = mkOption {
      type = types.str;
      default = "vhost";
      description = "Group for macvtap access";
    };

    usbGroup = mkOption {
      type = types.str;
      default = "usb";
      description = "Group for USB passthrough access";
    };
  };

  config = mkIf cfg.enable {
    # Ensure the package exists in nixpkgs or provide a default
    assertions = [
      {
        assertion = pkgs ? _nemu;
        message = "The _nemu package is not available. Please make sure it's defined in your nixpkgs overlay.";
      }
    ];

    programs.nemu = {
      enable = true;
      package = pkgs._nemu;
      inherit (cfg) vhostNetGroup macvtapGroup usbGroup;
      inherit (cfg) users;
    };

    # Create required groups if they don't exist
    users.groups = {
      "${cfg.vhostNetGroup}" = { };
      "${cfg.macvtapGroup}" = { };
      "${cfg.usbGroup}" = { };
    };

    # Add users to the required groups
    users.users =
      mapAttrs
        (_name: _: {
          extraGroups = [ cfg.vhostNetGroup cfg.macvtapGroup cfg.usbGroup ];
        })
        cfg.users;

    # Load kernel modules required by Nemu
    boot.kernelModules = [
      "kvm"
      "vhost_net"
      "tun"
    ];

    # Set up udev rules for macvtap and usb devices
    services.udev.extraRules = ''
      # Give permissions for macvtap devices
      KERNEL=="macvtap*", GROUP="${cfg.macvtapGroup}", MODE="0660"

      # Give permissions for /dev/kvm
      KERNEL=="kvm", GROUP="kvm", MODE="0660"

      # Give permissions for vhost-net
      KERNEL=="vhost-net", GROUP="${cfg.vhostNetGroup}", MODE="0660"
    '';
  };
}
