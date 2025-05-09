{
  description = "NixOS in MicroVMs with K3s";

  nixConfig = {
    extra-substituters = ["https://microvm.cachix.org"];
    extra-trusted-public-keys = ["microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    microvm,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    username = "k3suser";
    k3sToken = "7j2hK6sVjkzN5sE8sF+pQyXlJd3w8bX0y5ZvX7K9KAo="; # Replace with your generated token
  in {
    packages.${system} = {
      default = self.packages.${system}.k3s-master;
      k3s-master = self.nixosConfigurations.k3s-master.config.microvm.declaredRunner;
      k3s-agent = self.nixosConfigurations.k3s-agent.config.microvm.declaredRunner;
    };

    nixosConfigurations = {
      k3s-master = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          {
            networking.hostName = "k3s-master";
            users.users.root.password = "";
            users.users.${username} = {
              isNormalUser = true;
              extraGroups = ["wheel" "video"];
              initialPassword = "changeme";
            };
            security.sudo.wheelNeedsPassword = false;
            services.getty.autologinUser = username;

            services.k3s = {
              enable = true;
              role = "server";
              extraFlags = [
                "--disable-cloud-controller"
                "--disable=traefik"
                "--disable=servicelb"
                "--disable=local-storage"
              ];
              token = k3sToken;
            };

            networking.firewall.enable = false;
            networking.useDHCP = false;
            networking.interfaces.eth0.useDHCP = true;

            nix.settings.trusted-users = ["root" username];

            system.stateVersion = "25.05";

            # environment.systemPackages = with nixpkgs; [
            #   pkgs.vim
            #   pkgs.k3s
            #   pkgs.kubectl
            # ];

            environment.etc."k3s-token".text = k3sToken;

            microvm = {
              interfaces = [
                {
                  type = "tap";
                  id = "k3s-master";
                  mac = "00:00:00:00:00:02";
                }
              ];
              volumes = [
                {
                  mountPoint = "/var";
                  image = "var.img";
                  size = 256;
                }
              ];
              shares = [
                {
                  proto = "9p";
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                }
              ];
              hypervisor = "qemu";
              socket = "control.socket";
            };
          }
        ];
      };

      k3s-agent = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          {
            networking.hostName = "k3s-agent";
            users.users.root.password = "";
            users.users.${username} = {
              isNormalUser = true;
              extraGroups = ["wheel" "video"];
              initialPassword = "changeme";
            };
            security.sudo.wheelNeedsPassword = false;
            services.getty.autologinUser = username;

            services.k3s = {
              enable = true;
              role = "agent";
              serverAddr = "https://k3s-master:6443"; # Adjust if necessary
              token = k3sToken;
            };

            networking.firewall.enable = false;
            networking.useDHCP = false;
            networking.interfaces.eth0.useDHCP = true;

            nix.settings.trusted-users = ["root" username];

            system.stateVersion = "25.05";
            # environment.systemPackages = with nixpkgs; [
            #   pkgs.vim
            #   pkgs.k3s
            #   pkgs.kubectl
            # ];

            environment.etc."k3s-token".text = k3sToken;

            microvm = {
              interfaces = [
                {
                  type = "tap";
                  id = "k3s-agent";
                  mac = "00:00:00:00:00:02";
                }
              ];
              volumes = [
                {
                  mountPoint = "/var";
                  image = "var.img";
                  size = 256;
                }
              ];
              shares = [
                {
                  proto = "9p";
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                }
              ];
              hypervisor = "qemu";
              socket = "control.socket";
            };
          }
        ];
      };
    };
  };
}
