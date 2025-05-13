{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    # Terraform-specific setup
    extraPlugins = with pkgs.vimPlugins; [
      vim-terraform # For enhanced syntax highlighting
    ];

    extraConfigLua = ''
      -- Terraform specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {"terraform", "terraform-vars", "hcl"},
        callback = function()
          -- Set indentation settings for terraform files
          vim.opt_local.tabstop = 2
          vim.opt_local.softtabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.expandtab = true

          -- Automatically format terraform files on save
          vim.opt_local.formatoptions = vim.opt_local.formatoptions + "r"
        end
      })

      -- Terraform settings
      vim.g.terraform_align = 1
      vim.g.terraform_fmt_on_save = 1
    '';

    # Filetype associations
    filetype = {
      extension = {
        tf = "terraform";
        tfvars = "terraform";
        hcl = "hcl";
      };
    };
  };
}
