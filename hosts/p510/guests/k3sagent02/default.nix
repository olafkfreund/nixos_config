{
  pkgs,
  config,
  ...
}: let
  # Define variables here
  username = "olafkfreund";
  k3sToken = "7j2hK6sVjkzN5sE8sF+pQyXlJd3w8bX0y5ZvX7K9KAo="; # Replace with your custom token
in {
  nix.settings.experimental-features = ["nix-command" "flakes"];
  imports = [
    ./microvm.nix
  ];

  networking.hostName = "k3sagent02";
  environment.noXlibs = false;

  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";

  systemd.network.enable = true;
  systemd.network.networks."20-tap" = {
    matchConfig.Type = "ether";
    matchConfig.MACAddress = "5E:6D:F8:D1:E8:2A";
    networkConfig = {
      Address = ["192.168.1.203/24"];
      Gateway = "192.168.1.254";
      DNS = ["8.8.8.8" "1.1.1.1"];
      IPv6AcceptRA = true;
      DHCP = "no";
    };
  };
  services.resolved.enable = true;
  services.resolved.extraConfig = ''
    MulticastDNS=true
  '';

  networking.extraHosts = ''
    192.168.1.201 k3sserver.local
    192.168.1.202 k3sagent01.local
    192.168.1.203 k3sagent02.local
  '';

  time.timeZone = "Europe/London";

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable-cloud-controller"
      "--disable=traefik"
      "--disable=servicelb"
      "--disable=local-storage"
    ];
    token = k3sToken;
  };
  environment.systemPackages = with pkgs; [
    kubectl
    k3s
    vim
  ];
  # Users
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable 'sudo' for the user.
    initialHashedPassword = "$y$j9T$BG0c0RpL47BPIrgHJsNV.0$bbU2swVEq7wfL2NfKZXqs4gKD7LwDAMr7au1JlrEec1";
    openssh.authorizedKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMqMzUgRe2K350QBbQXbJFxVomsQbiIEw/ePUzjbyALklt5gMyo/yxbCWaKV1zeL4baR/vS5WOp9jytxceGFDaoJ7/O8yL4F2jj96Q5BKQOAz3NW/+Hmj/EemTOvVJWB1LQ+V7KgCbkxv6Zc
       UwL5a5+2QoujQNL5yVL3ZrIXv6LuKg8w8wykl57zDcJGgYsF+05oChswAmTFXI7hR5MdQgMGNM/eN78VZjSKJYGgeujoJg4BPQ6VE/qfIcJaPmuiiJBs0MDYIB8pKeSImXCDqYWEL6dZkSyro8HHHMAzFk1YP+pNIWVi8l3F+ajEFrEpTYKvds
       Z4TiP/7CBaaI+0yVIq1mQ100AWeUiTn89iF8yqAgP8laLgMqZbM15Gm5UD7+g9/zsW0razyuclLogijvYRTMKt8vBa/rEfcx+qs8CuIrkXnD/KGfvoMDRgniWz8teaV1zfdDrkd6BhPVc5P3hI6gDY/xnSeijyyXL+XDE1ex6nfW5vNCwMiAWf
       DM+6k= olafkfreund@razer"
    ];
  };
  # Nix settings
  nix.settings = {
    trusted-users = ["root" username];
  };
  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "24.11";
}
