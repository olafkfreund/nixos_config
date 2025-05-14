{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    # UI related options
    options = {
      # Line numbers
      number = true;
      relativenumber = true;
      numberwidth = 2;

      # Display
      showmode = false; # Don't show mode in command line
      showcmd = false; # Don't show command in bottom bar
      cmdheight = 1; # Height of command bar
      pumheight = 10; # Pop up menu height
      showtabline = 2; # Always show tabs
      title = true; # Set terminal title
      titlestring = "%<%F%=%l/%L - nvim"; # Title format
      winbar = "%=%m %f"; # Window bar format

      # Colors and styling
      termguicolors = true;
      background = "dark";
      cursorline = true; # Highlight current line
      signcolumn = "yes"; # Always show sign column
      fillchars = {
        eob = " "; # No ~ for empty lines
        fold = " ";
        foldopen = "";
        foldsep = " ";
        foldclose = "";
      };

      # Splits
      splitbelow = true; # Put new windows below current
      splitright = true; # Put new windows right of current
      equalalways = true; # Make splits equal size

      # Search and completion
      showmatch = true; # Show matching brackets
      mat = 2; # How many tenths of a second to blink
      wildmode = "longest:full,full"; # Command-line completion mode
      completeopt = "menu,menuone,noselect";

      # Visual decorations
      list = true; # Show invisible characters
      listchars = {
        tab = "→ ";
        extends = "⟩";
        precedes = "⟨";
        trail = "·";
        nbsp = "␣";
      };

      # Folds
      foldcolumn = "1";
      foldlevel = 99;
      foldlevelstart = 99;
      foldenable = true;

      # Scrolling
      scrolloff = 8; # Lines of context
      sidescrolloff = 8; # Columns of context
      wrap = false; # Don't wrap long lines
      linebreak = true; # Break lines at convenient points
      breakindent = true; # Preserve indentation in wrapped text
    };

    # Hide certain files in netrw
    globals.netrw_list_hide = "^.git/";

    # Better split navigation
    extraConfigLua = ''
      -- Better split navigation
      local opts = { noremap = true, silent = true }
      vim.keymap.set('n', '<C-h>', '<C-w>h', opts)
      vim.keymap.set('n', '<C-j>', '<C-w>j', opts)
      vim.keymap.set('n', '<C-k>', '<C-w>k', opts)
      vim.keymap.set('n', '<C-l>', '<C-w>l', opts)

      -- Highlight on yank
      vim.api.nvim_create_autocmd("TextYankPost", {
        callback = function()
          vim.highlight.on_yank({ timeout = 200 })
        end,
      })

      -- UI Customizations
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          -- Set up initial UI look
          vim.opt.shortmess:append "I"  -- Don't show intro message
        end,
      })

      -- Better window splits
      vim.api.nvim_create_autocmd("WinEnter", {
        callback = function()
          -- Equal size splits on window resize
          if vim.fn.winnr('$') > 1 then
            vim.cmd('wincmd =')
          end
        end,
      })
    '';
  };
}
