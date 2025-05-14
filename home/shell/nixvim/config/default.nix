{...}: {
  imports = [
    ./autocmds.nix
    ./filetypes.nix
    ./keymaps.nix
    ./ui.nix
    ./options.nix
  ];

  programs.nixvim = {
    # Core configuration settings that don't fit elsewhere
  };
}
