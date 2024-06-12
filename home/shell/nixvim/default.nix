{ ... }:{
  programs.nixvim = {
    enable = true;
    enableMan = true;
    colorschemes = {
      gruvbox = {
        enable = false;
        };
    };
    globals = {
      mapleader = " ";
    };
    options = {
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      wrap = false;

    };

    plugins = {
      nvim-cmp = {
        enable = true;
        autoEnableSources = true;
      };
      nvim-autopairs = {
        enable = true;
      };
      lsp = {
        enable = true;
        servers = {
          nil_ls = {
            enable = true;
          };
          nixd = {
            enable = true;
          };
          bashls = {
            enable = true;
          };
          dockerls = {
            enable = true;
          };
          jsonls = {
            enable = true;
          };
          tsserver = {
            enable = true;
          };
          yamlls = {
            enable = true;
          };
        };
      };
      lazygit = {
        enable = true;
      };
      lazy = {
        enable = true;
      };
      lualine = {
        enable = true;
        iconsEnabled = true;
      };
      noice = {
        enable = true;
      };
      none-ls = {
        enable = true;
        sources = {
          diagnostics = {
            gitlint.enable = true;
            deadnix.enable = true;
            statix.enable = true;
          };
          formatting = {
            shfmt.enable = true;
            stylua.enable = true;
            prettier.enable = true;
            black.enable = true;
            isort.enable = true;
            gofmt.enable = true;
            goimports.enable = true;
            sqlformat.enable = true;
            yapf.enable = true;
            nixpkgs_fmt.enable = true;
          };
        };
      };
      nix = {
        enable = true;
      };
    };
  };
}  
