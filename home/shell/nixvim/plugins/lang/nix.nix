{pkgs, lib, ...}: {
  programs.nixvim = {
    # Enable Nix filetype detection and syntax highlighting
    filetype.enable = true;

    # Nix language support
    extraPlugins = with pkgs.vimPlugins; [
      vim-nix # Enhanced Nix syntax highlighting
    ];

    plugins = {
      nix = {
        enable = true;
        settings = {
          formatting = {
            command = "nixpkgs-fmt";
          };
        };
      };

      treesitter = {
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          nix
        ];
      };

      lsp = {
        servers = {
          nil_ls = {
            enable = true;
            settings = {
              formatting = {
                command = ["nixpkgs-fmt"];
              };
            };
          };
        };
      };
    };

    # Configure Nix-specific indentation
    extraConfigLua = ''
      -- Nix specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "nix",
        callback = function()
          -- Set indentation for Nix files
          vim.opt_local.tabstop = 2
          vim.opt_local.softtabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.expandtab = true

          -- Enable auto-formatting with nixpkgs-fmt if available
          if vim.fn.executable("nixpkgs-fmt") == 1 then
            vim.opt_local.formatprg = "nixpkgs-fmt"
          end

          -- Nix-specific keymaps
          vim.keymap.set("n", "<leader>cf", "<cmd>lua vim.lsp.buf.format()<CR>", {
            buffer = true,
            desc = "Format Nix file"
          })
        end
      })
    '';

    # Key mappings for Nix files
    keymaps = [
      {
        mode = "n";
        key = "<leader>nf";
        action = ":!nixpkgs-fmt %<CR>";
        options = {
          desc = "Format Nix file";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>ne";
        action = ":!nix eval -f % .<CR>";
        options = {
          desc = "Evaluate Nix expression";
          silent = true;
        };
      }
    ];

    plugins.lsp.servers.nixd = {
      enable = true;
      settings = {
        nixd = {
          formatting = {
            command = ["nixpkgs-fmt"];
          };
          options = {
            enable = true;
          };
        };
      };
    };
  };
}
