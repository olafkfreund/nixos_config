{
  config,
  lib,
  pkgs,
  ...
}: let
  username = "olafkfreund";
  hostname = "k3sagent2";
  masterIP = "192.168.1.127";
  k3sToken = "7j2hK6sVjkzN5sE8sF+pQyXlJd3w8bX0y5ZvX7K9KAo=";
in {
  # Enable microvm
  microvm = {
    enable = true;
    hypervisor = "qemu";
    interfaces = [
      {
        type = "user";
        id = "default";
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
        mountPoint = "/mnt/img_pool";
        image = "k3sagent2.img";
        size = 2048;
      }
    ];
  };

  # Basic system configuration
  boot.isContainer = true;
  system.stateVersion = "24.11";

  # Enable K3s as agent
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://${masterIP}:6443"; # Replace MASTER_IP with your master node's IP
    token = k3sToken; # Replace with your actual K3s token
  };

  # Networking
  networking.firewall.enable = false;
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.hostName = hostname;
  nix.enable = true;
  nix.settings = {
    extra-experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" username];
  };
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  services.getty.autologinUser = username;
  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable 'sudo' for the user.
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMqMzUgRe2K350QBbQXbJFxVomsQbiIEw/ePUzjbyALklt5gMyo/yxbCWaKV1zeL4baR/vS5WOp9jytxceGFDaoJ7/O8yL4F2jj96Q5BKQOAz3NW/+Hmj/EemTOvVJWB1
       LQ+V7KgCbkxv6ZcUwL5a5+2QoujQNL5yVL3ZrIXv6LuKg8w8wykl57zDcJGgYsF+05oChswAmTFXI7hR5MdQgMGNM/eN78VZjSKJYGgeujoJg4BPQ6VE/qfIcJaPmuiiJBs0MDYIB8pKeSImXCDqYWEL6dZkSyro8HHHMAz
       Fk1YP+pNIWVi8l3F+ajEFrEpTYKvdsZ4TiP/7CBaaI+0yVIq1mQ100AWeUiTn89iF8yqAgP8laLgMqZbM15Gm5UD7+g9/zsW0razyuclLogijvYRTMKt8vBa/rEfcx+qs8CuIrkXnD/KGfvoMDRgniWz8teaV1zfdDrkd6B
       hPVc5P3hI6gDY/xnSeijyyXL+XDE1ex6nfW5vNCwMiAWfDM+6k= olafkfreund@razer"
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
