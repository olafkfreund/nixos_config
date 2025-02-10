{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.microvm.nixosModules.microvm
  ];
  # Enable microvm
  microvm = {
    # enable = true;
    hypervisor = "qemu";
    socket = "control.socket";
    mem = 8192;
    vcpu = 4;
    interfaces = [
      {
        type = "tap";
        id = "k3sserver";
        mac = "02:00:00:00:00:01";
      }
    ];
    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
    volumes = [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 2048;
      }
    ];
  };

  system.stateVersion = "24.11";

  # Enable K3s
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable-cloud-controller"
      "--disable=traefik"
    ];
    token = "7j2hK6sVjkzN5sE8sF+pQyXlJd3w8bX0y5ZvX7K9KAo=";
  };

  # Networking
  systemd.network.enable = true;
  networking.defaultGateway.address = "192.168.1.254";
  networking.interfaces = {
    eth0.ipv4.addresses = [
      {
        address = "192.168.1.201";
        prefixLength = 24;
      }
    ];
  };
  networking.firewall.enable = false;
  networking.hostName = "k3sserver";
  nix.enable = true;
  nix.settings = {
    extra-experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "olofkfreund"];
  };
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = "yes";
    };
  };
  users.users.olafkfreund = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable 'sudo' for the user.
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMqMzUgRe2K350QBbQXbJFxVomsQbiIEw/ePUzjbyALklt5gMyo/yxbCWaKV1zeL4baR/vS5WOp9jytxceGFDaoJ7/O8yL4F2jj96Q5BKQOAz3NW/+Hmj/EemTOvVJWB1LQ+V7KgCbkxv6ZcUwL5a5+2QoujQNL5yVL3ZrIXv6LuKg8w8wykl57zDcJGgYsF+05oChswAmTFXI7hR5MdQgMGNM/eN78VZjSKJYGgeujoJg4BPQ6VE/qfIcJaPmuiiJBs0MDYIB8pKeSImXCDqYWEL6dZkSyro8HHHMAzFk1YP+pNIWVi8l3F+ajEFrEpTYKvdsZ4TiP/7CBaaI+0yVIq1mQ100AWeUiTn89iF8yqAgP8laLgMqZbM15Gm5UD7+g9/zsW0razyuclLogijvYRTMKt8vBa/rEfcx+qs8CuIrkXnD/KGfvoMDRgniWz8teaV1zfdDrkd6BhPVc5P3hI6gDY/xnSeijyyXL+XDE1ex6nfW5vNCwMiAWfDM+6k= olafkfreund@razer"
    ];
  };
  # Users
  users.users.root.password = "";

  # Install some useful packages
  environment.systemPackages = with pkgs; [
    kubectl
    k3s
    vim
    k9s
  ];
}
