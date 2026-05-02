{ lib
, config
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.cli.fzf;
  inherit (config.lib.stylix) colors;
in
{
  options.cli.fzf = {
    enable = mkEnableOption {
      default = true;
      description = "Enable fuzzy finder";
    };
  };
  config = mkIf cfg.enable {
    programs.fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      defaultCommand = "fd --hidden --strip-cwd-prefix --exclude .git";
      fileWidgetOptions = [
        "--preview 'if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi'"
      ];

      changeDirWidgetCommand = "fd --type=d --hidden --strip-cwd-prefix --exclude .git";
      changeDirWidgetOptions = [
        "--preview 'eza --tree --color=always {} | head -200'"
      ];

      ## Theme
      defaultOptions = [
        "--color=fg:-1,fg+=#${colors.base07},bg:-1,bg+=#${colors.base00}"
        "--color=hl=#${colors.base0B},hl+=#${colors.base0B},info=#${colors.base03},marker=#${colors.base0F}"
        "--color=prompt=#${colors.base08},spinner=#${colors.base0C},pointer=#${colors.base0F},header=#${colors.base0D}"
        "--color=border=#${colors.base03},label=#${colors.base04},query=#${colors.base07}"
        "--border='double' --border-label='' --preview-window='border-sharp' --prompt='> '"
        "--marker='>' --pointer='>' --separator='─' --scrollbar='│'"
        "--info='right'"
      ];
    };
  };
}
