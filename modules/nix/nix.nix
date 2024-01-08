
{ self, config, pkgs, ... }: {

nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 2d";
};

system.autoUpgrade = {
  enable = true;
  channel = "https://nixos.org/channels/nixos-23.11";
};

nix = {
  package = pkgs.nixFlakes;
  extraOptions = ''
    experimental-features = nix-command flakes
  '';
};

nix = {
  trustedUsers = [ "root" "olafkfreund" ];
};

# Allow unfree packages
nixpkgs.config.allowUnfree = true;
nixpkgs.config.allowInsecure = true;
nixpkgs.config.joypixels.acceptLicense = true;
nixpkgs.config.permittedInsecurePackages = [ "electron-25.9.0" ];


environment.systemPackages = with pkgs; [
 	wget
  nixos-container
  nixos-generators
  nix-zsh-completions
  nix-bash-completions
  ];
}
