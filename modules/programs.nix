_: {
  # Program-specific modules
  # Only load on hosts that need these specific programs
  imports = [
    ./programs/default.nix
    ./webcam/default.nix
    ./obsidian/default.nix
    ./office/default.nix
    ./funny/funny.nix
    ./spell/spell.nix
  ];
}
