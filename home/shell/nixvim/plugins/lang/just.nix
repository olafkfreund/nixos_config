{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    # Just-specific setup for Justfile support
    filetype = {
      extension = {
        just = "just";
      };
      filename = {
        Justfile = "just";
        justfile = "just";
        ".justfile" = "just";
      };
    };
    
    extraConfigLua = ''
      -- Just specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "just",
        callback = function()
          -- Set indentation
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
          vim.opt_local.shiftwidth = 4
          vim.opt_local.expandtab = true
        end
      })
      
      -- Commands for working with Just files
      vim.api.nvim_create_user_command("JustRun", function(opts)
        local recipe = opts.args
        local cmd = "just"
        if recipe ~= "" then
          cmd = cmd .. " " .. recipe
        end
        vim.cmd("terminal " .. cmd)
      end, {nargs = "?", desc = "Run just recipe", complete = function()
        local output = vim.fn.systemlist("just --summary")
        table.remove(output, 1) -- Remove the first line ("Available recipes:")
        local recipes = {}
        for _, line in ipairs(output) do
          local recipe = line:match("%s*(%S+)")
          if recipe then
            table.insert(recipes, recipe)
          end
        end
        return recipes
      end})
    '';
    
    # Key mappings for Just
    keymaps = [
      {
        mode = "n";
        key = "<leader>jr";
        action = ":JustRun<CR>";
        options = {
          desc = "Run default just recipe";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>jl";
        action = ":!just --list<CR>";
        options = {
          desc = "List just recipes";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>js";
        action = ":!just --summary<CR>";
        options = {
          desc = "Show just recipe summary";
          silent = true;
        };
      }
    ];

    # Configure treesitter grammar for just files if available
    plugins.treesitter = {
      grammarPackages = with pkgs.tree-sitter-grammars; [
        tree-sitter-just
      ];
    };
  };
}
