{ config, pkgs, lib, modulesPath, ... }:

{
  imports =
    [
      # Need to load some defaults for running in an lxc container.
      # This is explained in:
      # https://github.com/nix-community/nixos-generators/issues/79
      "${modulesPath}/virtualisation/lxc-container.nix"

    ];

  # This doesn't do _everything_ we need, because `boot.isContainer` is
  # specifically talking about light-weight NixOS containers, not LXC. But it
  # does at least gives us something to start with.
  boot.isContainer = true;

  # These are the locales that we want to enable.
  i18n.supportedLocales = [ "C.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];

  # Make sure Xlibs are enabled like normal.  This is disabled by
  # lxc-container.nix in imports.
  environment.noXlibs = false;

  # Make sure command-not-found is enabled.  This is disabled by
  # lxc-container.nix in imports.
  programs.command-not-found.enable = true;

  # Disable nixos documentation because it is annoying to build.
  documentation.nixos.enable = false;

  # Make sure documentation for NixOS programs are installed.
  # This is disabled by lxc-container.nix in imports.
  documentation.enable = true;

  # `boot.isContainer` implies NIX_REMOTE = "daemon"
  # (with the comment "Use the host's nix-daemon")
  # We don't want to use the host's nix-daemon.
  environment.variables.NIX_REMOTE = lib.mkForce "";

  # Suppress daemons which will vomit to the log about their unhappiness
  systemd.services."console-getty".enable = false;
  systemd.services."getty@".enable = false;

  # Use flakes
  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # We assume that LXD will create this eth1 interface for us.  But we don't
  # use DHCP, so we configure it statically.
  networking.interfaces.eth1.ipv4.addresses = [{
    address = "192.168.57.50";
    prefixLength = 24;
  }];

  # We can access the internet through this interface.
  networking.defaultGateway = {
    address = "192.168.57.1";
    interface = "eth1";
  };

  networking.nftables.enable = true;

  # The eth1 interface in this container can only be accessed from my laptop
  # (the host).  Unless the host in compromised, I should be able to trust all
  # traffic coming over this interface.
  networking.firewall.trustedInterfaces = [
    "eth1"
  ];

  # Since we don't use DHCP, we need to set our own nameservers.
  networking.nameservers = [ "8.8.4.4" "8.8.8.8" ];

  networking.hostName = "lxc-nixos";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "24.05"; # Did you read the comment?
}
