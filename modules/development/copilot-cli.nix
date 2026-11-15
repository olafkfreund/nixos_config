{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.development;

  # Import the copilot-cli package derivation
  copilot-cli = pkgs.callPackage ../../home/development/copilot-cli { };
in
{
  config = mkIf (cfg.enable && cfg.copilot-cli) {
    environment.systemPackages = [ copilot-cli ];

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
