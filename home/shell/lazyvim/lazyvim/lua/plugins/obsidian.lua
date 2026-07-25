-- obsidian.nvim — all three vaults, not just one.
--
-- This was upstream boilerplate: a single "personal" workspace pointing at
-- R3_vault, commented-out examples, and no keymaps. Two of the three vaults on
-- this machine were unreachable from Neovim:
--
--   ~/Documents/R3_vault                   872 notes
--   ~/Documents/Synechron                  996 notes
--   ~/Documents/My_Obsidian_Vault/Privat  1085 notes
--
-- obsidian.nvim selects the workspace whose path contains the current buffer,
-- so ordering only decides the fallback.
--
-- Options were checked against obsidian-nvim/obsidian.nvim
-- lua/obsidian/config/default.lua rather than copied from a blog post — this
-- is the maintained fork, not the archived epwalsh plugin, and several keys
-- differ between them.
return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  dependencies = { "nvim-lua/plenary.nvim" },
  -- <leader>v = vault. a/d/e/g/N/o/T are already taken in this config and
  -- b/c/f/g/q/s/t/u/w/x/n belong to LazyVim, so v is the free mnemonic.
  keys = {
    { "<leader>v", "", desc = "+vault (obsidian)" },
    { "<leader>vo", "<cmd>Obsidian open<cr>", desc = "Open in Obsidian app" },
    { "<leader>vs", "<cmd>Obsidian search<cr>", desc = "Search vault" },
    { "<leader>vq", "<cmd>Obsidian quick_switch<cr>", desc = "Quick switch note" },
    { "<leader>vn", "<cmd>Obsidian new<cr>", desc = "New note" },
    { "<leader>vt", "<cmd>Obsidian today<cr>", desc = "Today's daily note" },
    { "<leader>vy", "<cmd>Obsidian yesterday<cr>", desc = "Yesterday's note" },
    { "<leader>vb", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
    { "<leader>vl", "<cmd>Obsidian links<cr>", desc = "Links in note" },
    { "<leader>vg", "<cmd>Obsidian tags<cr>", desc = "Tags" },
    { "<leader>vw", "<cmd>Obsidian workspace<cr>", desc = "Switch vault" },
    { "<leader>vr", "<cmd>Obsidian rename<cr>", desc = "Rename note (updates links)" },
    { "<leader>vx", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Toggle checkbox" },
    { "<leader>ve", "<cmd>Obsidian extract_note<cr>", mode = "v", desc = "Extract selection to note" },
    { "<leader>vk", "<cmd>Obsidian link<cr>", mode = "v", desc = "Link selection to note" },
  },
  opts = {
    workspaces = {
      { name = "r3", path = "~/Documents/R3_vault" },
      { name = "work", path = "~/Documents/Synechron" },
      {
        name = "private",
        path = "~/Documents/My_Obsidian_Vault/Privat",
        -- Only this vault actually has a Daily Notes folder on disk.
        overrides = {
          daily_notes = { folder = "Daily Notes" },
        },
      },
    },

    -- Use the `:Obsidian <subcommand>` form; the legacy :ObsidianOpen-style
    -- commands are deprecated upstream and clutter command completion.
    legacy_commands = false,

    completion = {
      min_chars = 2,
      create_new = true,
    },

    -- LazyVim ships snacks as its picker; naming it explicitly stops
    -- obsidian.nvim guessing when telescope/fzf are also on the runtimepath.
    picker = { name = "snacks.pick" },

    daily_notes = {
      date_format = "%Y-%m-%d",
      default_tags = { "daily" },
      -- These are personal vaults as well as work, so weekend entries should
      -- be allowed rather than silently skipped.
      workdays_only = false,
    },

    ui = {
      -- Conceal re-renders markdown as you type; with ~2950 notes a slightly
      -- longer debounce than the 200ms default keeps large files smooth.
      update_debounce = 400,
    },

    -- Hand non-note links (http, images) to the desktop handler instead of
    -- failing inside Neovim.
    follow_url_func = function(url)
      vim.ui.open(url)
    end,
  },
}
