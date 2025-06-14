{
  inputs,
  nixpkgs,
  lib,
}: let
  inherit (inputs) home-manager nixos-hardware;

  # Host type definitions with their default modules
  hostTypes = {
    workstation = {
      description = "High-performance desktop workstation";
      modules = [
        ../profiles/base.nix
        ../profiles/desktop.nix
        ../profiles/development.nix
        ../modules/hardware/desktop.nix
      ];
    };

    laptop = {
      description = "Mobile laptop configuration";
      modules = [
        ../profiles/base.nix
        ../profiles/desktop.nix
        ../modules/hardware/laptop.nix
        ../modules/hardware/power-management.nix
      ];
    };

    server = {
      description = "Server configuration";
      modules = [
        ../profiles/base.nix
        ../profiles/server.nix
        ../modules/hardware/server.nix
      ];
    };

    htpc = {
      description = "Home Theater PC";
      modules = [
        ../profiles/base.nix
        ../profiles/desktop.nix
        ../modules/hardware/htpc.nix
      ];
    };
  };

  # Standard host builder function
  mkHost = {
    hostname,
    hostType,
    system ? "x86_64-linux",
    users ? ["olafkfreund"],
    hardwareProfile ? null,
    extraModules ? [],
    enableHomeManager ? true,
    ...
  }: let
    hostTypeConfig = hostTypes.${hostType} or (throw "Unknown host type: ${hostType}");

    # Import overlays
    overlays = [
      (final: prev: {
        customPkgs = import ../pkgs {pkgs = final;};
      })
      (final: prev: {
        zjstatus = inputs.zjstatus.packages.${prev.system}.default or prev.zjstatus;
      })
    ];

    # Package imports helper
    mkPkgs = pkgs: {
      inherit system;
      config = {
        allowUnfree = true;
        allowInsecure = true;
      };
    };
  in
    nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        pkgs-stable = import inputs.nixpkgs-stable (mkPkgs inputs.nixpkgs-stable);
        pkgs-unstable = import inputs.nixpkgs (mkPkgs inputs.nixpkgs);
        inherit inputs hostname users hardwareProfile;

        # Legacy compatibility
        hostUsers = users;
        username = builtins.head users;
        host = hostname;
      };

      modules =
        [
          # Core system configuration
          {
            # Host options declarations
            options.custom.host = {
              name = nixpkgs.lib.mkOption {
                type = nixpkgs.lib.types.str;
                description = "The hostname of this system";
              };

              type = nixpkgs.lib.mkOption {
                type = nixpkgs.lib.types.enum ["workstation" "laptop" "server" "htpc"];
                description = "The type of host system";
              };

              users = nixpkgs.lib.mkOption {
                type = nixpkgs.lib.types.listOf nixpkgs.lib.types.str;
                default = [];
                description = "List of users for this host";
              };

              hardwareProfile = nixpkgs.lib.mkOption {
                type = nixpkgs.lib.types.nullOr nixpkgs.lib.types.str;
                default = null;
                description = "Hardware profile name for this host";
              };
            };

            # Enable our custom options system
            config = {
              nixpkgs.overlays = overlays;
              networking.hostName = hostname;

              custom = {
                host = {
                  name = hostname;
                  type = hostType;
                  users = users;
                  hardwareProfile = hardwareProfile;
                };
              };
            };
          }

          # Host-specific hardware configuration
          (
            if builtins.pathExists ../hosts/${hostname}/nixos/hardware-configuration.nix
            then ../hosts/${hostname}/nixos/hardware-configuration.nix
            else ../hosts/${hostname}/hardware-configuration.nix
          )

          # Load host type modules
        ]
        ++ hostTypeConfig.modules
        ++ extraModules
        ++ lib.optionals (hardwareProfile != null) [
          ../modules/hardware/profiles/${hardwareProfile}.nix
        ]
        ++ lib.optionals enableHomeManager [
          # Home Manager configuration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";

              extraSpecialArgs = {
                pkgs-stable = import inputs.nixpkgs-stable (mkPkgs inputs.nixpkgs-stable);
                pkgs-unstable = import inputs.nixpkgs (mkPkgs inputs.nixpkgs);
                inherit inputs hostname users;
                # Legacy compatibility
                hostUsers = users;
                username = builtins.head users;
                host = hostname;
              };

              users = builtins.listToAttrs (map (user: {
                  name = user;
                  value =
                    if builtins.pathExists ../Users/${user}/${hostname}_home.nix
                    then import ../Users/${user}/${hostname}_home.nix
                    else import ../Users/${user}/home.nix;
                })
                users);

              sharedModules = [
                inputs.stylix.homeManagerModules.stylix
                inputs.nixvim.homeManagerModules.nixvim or {}
                inputs.nixai.homeManagerModules.default or {}
                {
                  # Disable stylix targets that we handle manually
                  stylix.targets = builtins.listToAttrs (map (name: {
                      inherit name;
                      value.enable = false;
                    }) [
                      "waybar"
                      "yazi"
                      "vscode"
                      "dunst"
                      "rofi"
                      "xresources"
                      "neovim"
                      "hyprpaper"
                      "hyprland"
                      "spicetify"
                      "sway"
                      "qt"
                    ]);
                }
              ];
            };
          }
        ];
    };

  # Simplified host builder for quick setups
  mkSimpleHost = hostname: hostType: users:
    mkHost {
      inherit hostname hostType users;
    };
in {
  inherit mkHost mkSimpleHost hostTypes;
}
