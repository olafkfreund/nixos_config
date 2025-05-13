{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    autoCmd = [
      # Set indent for specific file types
      {
        event = "FileType";
        pattern = ["lua"];
        command = "setlocal shiftwidth=2 tabstop=2";
      }
      {
        event = "FileType";
        pattern = ["nix"];
        command = "setlocal shiftwidth=2 tabstop=2";
      }
      {
        event = "FileType";
        pattern = ["python"];
        command = "setlocal shiftwidth=4 tabstop=4";
      }
      {
        event = "FileType";
        pattern = ["markdown"];
        command = "setlocal wrap linebreak";
      }

      # Treesitter based folding
      {
        event = "FileType";
        pattern = ["lua" "nix" "rust" "go" "typescript" "javascript" "json" "python"];
        command = "setlocal foldmethod=expr foldexpr=nvim_treesitter#foldexpr() foldlevel=99";
      }
    ];

    # File type specific settings using ftplugin
    ftplugin = {
      markdown = {
        # Enable spell checking for markdown files
        opts = {
          spell = true;
        };
      };

      gitcommit = {
        # Set textwidth for git commit messages
        opts = {
          textwidth = 72;
          spell = true;
        };
      };

      lua = {
        # Format on save for lua files
        opts = {
          formatoptions = "jcroqlnt";
        };
      };

      nix = {
        # Format on save for nix files
        opts = {
          formatoptions = "jcroqlnt";
        };
      };
    };
  };
}
