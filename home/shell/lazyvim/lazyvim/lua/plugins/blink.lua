return {
  {
    "saghen/blink.cmp",
    lazy = false,
    dependencies = {
      "rafamadriz/friendly-snippets",
      "folke/lazydev.nvim",
    },
    -- Use the Nix-built plugin (vimPlugins.blink-cmp), which ships the
    -- prebuilt libblink_cmp_fuzzy.so. The path is materialized by
    -- home/shell/lazyvim/default.nix. Avoids lazy.nvim's release-binary
    -- download (which fails in this env) and the Lua-fallback warning.
    dir = vim.fn.expand("~/.local/share/nix-vim-plugins/blink.cmp"),
    build = false,
    opts = {
      keymap = {
        preset = "enter",
        ["<C-y>"] = { "select_and_accept" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide" },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      completion = {
        accept = { auto_brackets = { enabled = true } },
        menu = {
          draw = {
            columns = {
              { "label", "label_description", gap = 1 },
              { "kind_icon", "kind" },
            },
          },
        },
        ghost_text = { enabled = true },
      },
    },
  },
}
