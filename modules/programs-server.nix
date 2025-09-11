_: {
  # Server-specific programs - minimal subset without desktop apps
  # Only includes modules that define options used by server configs
  imports = [
    ./programs/default.nix # Core program modules (SSH, 1Password, etc.)
    ./webcam/default.nix # Provides programs.webcam option
    ./obsidian/default.nix # Provides programs.obsidian option (disabled on servers)
    ./office/default.nix # Provides programs.office option (disabled on servers)
    ./spell/spell.nix # Spell checking - might be useful for servers
    # ./funny/funny.nix     # Desktop apps - not needed on servers (no option dependencies)
  ];
}
