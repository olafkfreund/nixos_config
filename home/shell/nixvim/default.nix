{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./config
    ./plugins
  ];

  programs.nixvim = {
    enable = true;

    # Default global settings
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    # Basic Neovim options
    options = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      smartindent = true;
      wrap = false;
      swapfile = false;
      backup = false;
      undofile = true;
      ignorecase = true;
      smartcase = true;
      termguicolors = true;
      clipboard = "unnamedplus";
      completeopt = "menu,menuone,noselect";
      conceallevel = 3; # For markdown, latex
      updatetime = 100; # Faster completion
      timeoutlen = 300; # Faster key sequence completion
    };

    # Custom Lua code that doesn't fit into nixvim's structure
    extraConfigLua = ''
      -- Additional Lua code
      -- This section can be used for complex custom logic that doesn't fit well in Nix
    '';
  };
}
