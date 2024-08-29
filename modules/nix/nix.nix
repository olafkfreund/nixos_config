
{ self, config, pkgs, lib, ... }: {

nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

system.autoUpgrade = {
  enable = true;
  channel = "https://nixos.org/channels/nixos-24.11";
};

nix = {
  package = pkgs.nixFlakes;
  extraOptions = ''
    experimental-features = nix-command flakes
  '';
};

nix.settings.trusted-users = [ "root" "olafkfreund" ];
nix.settings.http-connections = 50;
nix.settings.warn-dirty = false;
nix.settings.log-lines = 50;
nix.settings.sandbox = "relaxed";
nix.settings.auto-optimise-store = true;

# Allow unfree packages
nixpkgs.config.allowUnfree = true;
nixpkgs.config.allowInsecure = true;
nixpkgs.config.joypixels.acceptLicense = true;
nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "slack-4.36.140"
    ];
nixpkgs.config.permittedInsecurePackages = [ 
  "electron-25.9.0"
  "electron-29.4.6"
  "nix-2.15.3"
  "jitsi-meet-1.0.8043"
  "olm-3.2.16"
];
programs.nix-index = {
    enable = true;
    package = pkgs.nix-index;
    enableBashIntegration = false;
    enableZshIntegration = false;
};


environment.systemPackages = with pkgs; [
 	wget
  home-manager
  gnupg
  ];
}
