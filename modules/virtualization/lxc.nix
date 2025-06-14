{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.virtualization.lxc = {
    enable = lib.mkEnableOption "LXC/LXD containerization";

    lxd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable LXD daemon";
    };

    incus = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Incus (LXD fork)";
    };
  };

  config = lib.mkIf config.modules.virtualization.lxc.enable {
    virtualisation = {
      lxd = lib.mkIf config.modules.virtualization.lxc.lxd {
        enable = true;
        recommendedSysctlSettings = true;
      };

      incus = lib.mkIf config.modules.virtualization.lxc.incus {
        enable = true;
      };

      lxc = {
        enable = true;
        lxcfs.enable = true;
      };
    };

    environment.systemPackages = with pkgs;
      [
        lxc
      ]
      ++ lib.optionals config.modules.virtualization.lxc.lxd [
        lxd
      ]
      ++ lib.optionals config.modules.virtualization.lxc.incus [
        incus
      ];

    users.users = lib.mkMerge [
      (lib.mkIf (config.users.users ? "olafkfreund") {
        olafkfreund.extraGroups = ["lxd"] ++ lib.optionals config.modules.virtualization.lxc.incus ["incus-admin"];
      })
    ];
  };
}
