{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    globals = {
      # Disable useless providers
      loaded_ruby_provider = 0; # Ruby
      loaded_perl_provider = 0; # Perl
      loaded_python_provider = 0; # Python 2

      mapleader = " "; # Set leader key to space
      maplocalleader = " ";
    };

    clipboard = {
      # Use system clipboard
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };

    options = {
      updatetime = 100; # Faster completion

      # Line numbers
      number = true; # Show current line number
      relativenumber = true; # Show relative line numbers
      hidden = true; # Keep closed buffer open in background

      # Mouse settings
      mouse = "a"; # Enable mouse control
      mousemodel = "extend"; # Right-click extends selection

      # Window splitting
      splitbelow = true; # New window below current one
      splitright = true; # New window right of current one

      # File handling
      swapfile = false; # Disable swap file
      backup = false; # Disable backup
      undofile = true; # Persistent undo history

      # Search settings
      incsearch = true; # Incremental search
      inccommand = "split"; # Preview replacements in split window
      ignorecase = true; # Case-insensitive search
      smartcase = true; # Case-sensitive if uppercase present

      # Visual settings
      scrolloff = 8; # Lines of context
      cursorline = false; # Don't highlight current line
      cursorcolumn = false; # Don't highlight current column
      signcolumn = "yes"; # Always show sign column
      laststatus = 3; # Global status line
      cmdheight = 1; # Command line height
      showmode = false; # Don't show mode (handled by status line)
      fileencoding = "utf-8";
      termguicolors = true; # True color support

      # Editor behavior
      expandtab = true; # Use spaces instead of tabs
      shiftwidth = 2; # Indent size
      tabstop = 2; # Tab size
      softtabstop = 2; # Soft tab size
      smartindent = true; # Smart indentation
      wrap = false; # No line wrapping
      completeopt = "menu,menuone,noselect"; # Completion options
      wildmode = "longest:full,full"; # Command-line completion mode

      # Text display
      conceallevel = 3; # Hide markup
      list = true; # Show whitespace
      listchars = {
        tab = "→ ";
        extends = "⟩";
        precedes = "⟨";
        trail = "·";
        nbsp = "␣";
      };

      # Folding
      foldmethod = "expr";
      foldexpr = "nvim_treesitter#foldexpr()";
      foldlevel = 99;
      foldenable = true;
    };

    # Global key mappings
    maps = {
      normal = {
        # Window navigation
        "<C-h>" = "<C-w>h";
        "<C-j>" = "<C-w>j";
        "<C-k>" = "<C-w>k";
        "<C-l>" = "<C-w>l";

        # Buffer navigation
        "<S-h>" = ":bprevious<CR>";
        "<S-l>" = ":bnext<CR>";

        # Stay in indent mode
        "<" = "<gv";
        ">" = ">gv";

        # Move text up and down
        "<A-j>" = ":m .+1<CR>==";
        "<A-k>" = ":m .-2<CR>==";
      };

      insert = {
        # Easy escape
        "jk" = "<ESC>";
        "kj" = "<ESC>";

        # Move text up and down
        "<A-j>" = "<ESC>:m .+1<CR>==gi";
        "<A-k>" = "<ESC>:m .-2<CR>==gi";
      };

      visual = {
        # Stay in indent mode
        "<" = "<gv";
        ">" = ">gv";

        # Move text up and down
        "<A-j>" = ":m '>+1<CR>gv=gv";
        "<A-k>" = ":m '<-2<CR>gv=gv";
      };
    };
  };
}
