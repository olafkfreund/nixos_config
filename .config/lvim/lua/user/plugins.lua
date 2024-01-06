lvim.plugins = {
  {
      "zbirenbaum/copilot.lua",
      cmd = "Copilot",
      event = "InsertEnter",
      config = function()
        require("copilot").setup({
          suggestions = { enabled = false },
          panel = { enabled = false },
        })
      end,
    },
  { 'lunarvim/lunar.nvim' },
  { "morhetz/gruvbox" },
  { "sainnhe/gruvbox-material" },
  { "sainnhe/sonokai" },
  { "sainnhe/edge" },
  { "lunarvim/horizon.nvim" },
  { "tomasr/molokai" },
  { "ayu-theme/ayu-vim" },
  --{ "akinsho/toggleterm.nvim" },
  { "tpope/vim-surround" },
  { "felipec/vim-sanegx", event = "BufRead" },
  { "tpope/vim-repeat" },
  --  { "ThePrimeagen/harpoon" },
  {
      'phaazon/hop.nvim',
      branch = 'v2',
      config = function()
        require('hop').setup()
      end
    },
  --  {
  --    'nvim-telescope/telescope-frecency.nvim',
  --    dependencies = { 'nvim-telescope/telescope.nvim', 'kkharji/sqlite.lua' },
  --  },
--  {
--      'AckslD/nvim-trevJ.lua',
--      config = 'require("trevj").setup()',
--      init = function()
--        vim.keymap.set('n', '<leader>j', function()
--          require('trevj').format_at_cursor()
--        end)
--      end,
--    },
}

table.insert(lvim.plugins, {
  "zbirenbaum/copilot-cmp",
  event = "InsertEnter",
  dependencies = { "zbirenbaum/copilot.lua" },
  config = function()
    local ok, cmp = pcall(require, "copilot_cmp")
    if ok then cmp.setup({}) end
  end,
})

--lvim.builtin.telescope.on_config_done = function(telescope)
--  pcall(telescope.load_extension, "frecency")
--end
