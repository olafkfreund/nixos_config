{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.development.copilot-cli;

  # Import the copilot-cli package derivation
  copilot-cli = pkgs.callPackage ../../home/development/copilot-cli {};
in
{
  options.development.copilot-cli = {
    enable = mkEnableOption "Enable GitHub Copilot CLI";

    package = mkOption {
      type = types.package;
      default = copilot-cli;
      description = "GitHub Copilot CLI package to use";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Add shell aliases for convenience
    programs.bash.shellAliases = {
      "??" = "copilot";
      "gh?" = "gh copilot";
      "git?" = "gh copilot suggest -t git";
      "shell?" = "gh copilot suggest -t shell";
    };

    # Zsh aliases need noglob to prevent glob expansion of ? characters
    # Use interactiveShellInit instead of shellInit to ensure proper ordering
    programs.zsh.interactiveShellInit = ''
      # Disable glob expansion for copilot aliases
      alias '??'='noglob copilot'
      alias 'gh?'='noglob gh copilot'
      alias 'git?'='noglob gh copilot suggest -t git'
      alias 'shell?'='noglob gh copilot suggest -t shell'
    '';
  };
}