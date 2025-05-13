{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    # YAML-specific setup
    extraPlugins = with pkgs.vimPlugins; [
      vim-yaml # Enhanced YAML syntax support
      vim-yaml-folds # Better folding for YAML files
    ];

    extraConfigLua = ''
      -- YAML specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"yaml", "yml"},
        callback = function()
          -- Set indentation for YAML files
          vim.opt_local.tabstop = 2
          vim.opt_local.softtabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.expandtab = true

          -- Improve the display of yaml files
          vim.opt_local.foldmethod = "indent"
          vim.opt_local.foldlevel = 20

          -- Enable cursor column for better alignment visibility
          vim.opt_local.cursorcolumn = true
        end
      })

      -- Handle special YAML files differently
      vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
        pattern = {
          -- Kubernetes patterns
          "**/templates/**/*.yaml",
          "**/templates/**/*.yml",
          "**/manifests/**/*.yaml",
          "**/manifests/**/*.yml",
          "**/charts/**/*.yaml",
          "**/charts/**/*.yml",
          -- Ansible patterns
          "**/roles/**/*.yml",
          "**/playbooks/*.yml",
          "*playbook.yml",
          -- GitHub workflows
          "**/.github/workflows/*.yaml",
          "**/.github/workflows/*.yml"
        },
        callback = function()
          -- Detect file type based on content and path
          local filename = vim.fn.expand("%:p")
          local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, 10, false), "\n")

          -- Kubernetes detection
          if filename:match("templates") or 
             filename:match("charts") or 
             content:match("apiVersion:") or
             content:match("kind:") then
            vim.b.yaml_schema = "kubernetes"
          -- Ansible detection
          elseif filename:match("roles") or
                 filename:match("playbook") or
                 content:match("hosts:") then
            vim.b.yaml_schema = "ansible"
          -- GitHub workflow detection
          elseif filename:match("workflows") then
            vim.b.yaml_schema = "github-workflow"
          end
        end
      })

      -- Configure schema-based validation for YAML
      vim.g.yaml_schema_mapping = {
        ["kubernetes"] = {
          ["mappings"] = {
            ["apiVersion"] = true,
            ["kind"] = true,
            ["metadata"] = true,
            ["spec"] = true,
          }
        },
        ["ansible"] = {
          ["mappings"] = {
            ["hosts"] = true,
            ["tasks"] = true,
            ["roles"] = true,
          }
        },
        ["github-workflow"] = {
          ["mappings"] = {
            ["name"] = true,
            ["on"] = true,
            ["jobs"] = true,
          }
        }
      }
    '';

    # YAML specific keymaps
    keymaps = [
      {
        mode = "n";
        key = "<leader>yv";
        action = ":!yamllint %<CR>";
        options = {
          desc = "Validate YAML with yamllint";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>ys";
        action = ":!yq . %<CR>";
        options = {
          desc = "Show parsed YAML with yq";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>yf";
        action = ":!prettier --parser yaml --write %<CR>";
        options = {
          desc = "Format YAML with prettier";
          silent = true;
        };
      }
    ];

    # Filetype associations
    filetype = {
      extension = {
        yml = "yaml";
        yaml = "yaml";
      };
    };

    # Configure treesitter for YAML
    plugins.treesitter.ensureInstalled = [
      "yaml"
    ];
  };
}
