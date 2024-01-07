{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    withNodeJs = true;
    withPython3 = true;
    plugins = with pkgs.vimPlugins; [
      # vim-sensible
      # vim-surround
      comment-nvim
      undotree
      gruvbox-nvim
      plenary-nvim
      vim-fugitive
      gitsigns-nvim
      diffview-nvim

      which-key-nvim
      hydra-nvim

      barbar-nvim
      lualine-nvim
      vim-tpipeline
      vim-tmux-navigator

      # vista-vim

      # vim-tpipeline

      nvim-tree-lua
      nvim-web-devicons
      vim-devicons

      # vim-lion
      neoscroll-nvim

      # minimap-vim
      nui-nvim
      nvim-notify
      noice-nvim
      inc-rename-nvim
      leap-nvim
      # peek-nvim
      indent-blankline-nvim

      nvim-lspconfig
      (nvim-treesitter.withPlugins (p:
        with p; [
          bash
          comment
          dockerfile
          html
          javascript
          json
          lua
          nix
          python
          regex
          rust
          sql
          toml
          typescript
          vim
          yaml
          wing
        ]))
      neogen
      luasnip
      nvim-lightbulb

      copilot-lua
      copilot-cmp
      lspkind-nvim
      nvim-cmp
      cmp-nvim-lsp
      cmp-nvim-lua
      cmp-buffer

      null-ls-nvim
      nvim-lsp-ts-utils

      telescope-nvim
      telescope-fzf-native-nvim
      telescope-ui-select-nvim
      typescript-tools-nvim
    ];
    extraPackages = with pkgs; [
      # LSP servers
      nodePackages_latest.pyright
      nodePackages_latest.typescript-language-server
      nil
      sumneko-lua-language-server

      # Linters and formatters
      nodePackages_latest.prettier
      nodePackages_latest.eslint_d
      nodePackages_latest.jsonlint
      yamlfmt
      autoflake
      python311Packages.autopep8
      python311Packages.flake8
      black
      isort
      alejandra
      stylua

      # fzf
      ripgrep
    ];
    #extraPython3Packages = pyPkgs: with pyPkgs; [ ];
  };
  xdg.configFile.nvim = {
    source = ./config;
    recursive = true;
  };
}