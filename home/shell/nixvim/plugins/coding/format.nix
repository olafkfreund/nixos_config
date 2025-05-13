{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    plugins = {
      conform-nvim = {
        enable = true;

        notifyOnError = true;

        formatOnSave = {
          lspFallback = true;
          timeoutMs = 500;
        };

        formattersByFt = {
          lua = ["stylua"];
          python = ["isort" "black"];
          javascript = ["prettierd"];
          typescript = ["prettierd"];
          javascriptreact = ["prettierd"];
          typescriptreact = ["prettierd"];
          css = ["prettierd"];
          html = ["prettierd"];
          json = ["prettierd"];
          yaml = ["prettierd"];
          markdown = ["prettierd"];
          graphql = ["prettierd"];
          nix = ["nixpkgs-fmt"];
          rust = ["rustfmt"];
          go = ["gofmt"];
          sh = ["shfmt"];
        };
      };
    };

    extraConfigLua = ''
      -- Configure format keymaps
      vim.keymap.set({ "n", "v" }, "<leader>cf", function()
        require("conform").format({ async = true, lsp_fallback = true })
      end, { desc = "Format buffer" })
    '';
  };
}
