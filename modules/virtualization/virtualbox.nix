{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.virtualization.virtualbox = {
    enable = lib.mkEnableOption "VirtualBox virtualization";

    host = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable VirtualBox host support";
    };

    guest = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable VirtualBox guest additions";
    };

    extensionPack = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable VirtualBox extension pack (unfree)";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.modules.virtualization.virtualbox.enable {
      virtualisation.virtualbox.host = lib.mkIf config.modules.virtualization.virtualbox.host {
        enable = true;
        enableExtensionPack = config.modules.virtualization.virtualbox.extensionPack;
      };

      virtualisation.virtualbox.guest = lib.mkIf config.modules.virtualization.virtualbox.guest {
        enable = true;
        x11 = true;
      };

      users.users = lib.mkMerge [
        (lib.mkIf (config.users.users ? "olafkfreund" && config.modules.virtualization.virtualbox.host) {
          olafkfreund.extraGroups = ["vboxusers"];
        })
      ];

      nixpkgs.config.allowUnfree = lib.mkIf config.modules.virtualization.virtualbox.extensionPack true;
    })
  ];
}
