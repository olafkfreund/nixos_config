{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    enable = true;
    
    # Basic vim options
    globals = {
      mapleader = " ";
    };

    options = {
      number = true;           # Show line numbers
      relativenumber = true;   # Show relative line numbers
      shiftwidth = 2;         # Number of spaces for auto indent
      tabstop = 2;           # Number of spaces for tab
      expandtab = true;      # Use spaces instead of tabs
      smartindent = true;    # Auto indent new lines
      wrap = false;          # Don't wrap lines
      swapfile = false;     # Don't create swap files
      backup = false;       # Don't create backup files
      undofile = true;     # Persistent undo
      hlsearch = true;     # Highlight search results
      incsearch = true;    # Incremental search
      termguicolors = true; # True color support
      updatetime = 50;     # Faster completion
    };

    # Basic keymaps
    maps = {
      normal = {
        # Quick save
        "<leader>w" = ":w<CR>";
        # Quick quit
        "<leader>q" = ":q<CR>";
        # Clear search highlighting
        "<leader>h" = ":nohl<CR>";
      };
    };
  };
}