-- NixOS: disable Mason. Mason downloads prebuilt binaries that don't run under
-- NixOS (no FHS). Every LSP/formatter we use (rust-analyzer, pyright, ruff,
-- gopls, typescript-language-server, lua-language-server, nixd, stylua,
-- alejandra, gofmt, prettierd) is provided on PATH via home-manager, and
-- nvim-lspconfig/conform find them there. This is what lets the lang.* extras
-- below work without Mason trying (and failing) to install anything.
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
}
