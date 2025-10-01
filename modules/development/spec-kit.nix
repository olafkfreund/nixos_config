{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.features.development;

  # Create a wrapper script that uses uv to run spec-kit
  # This avoids the complexity of full uv2nix packaging while remaining reasonably declarative
  spec-kit-wrapper = pkgs.writeShellScriptBin "specify" ''
    # Ensure we have required dependencies
    export PATH="${pkgs.git}/bin:${pkgs.uv}/bin:${pkgs.python311}/bin:$PATH"

    # Use uv to run spec-kit directly from GitHub
    exec ${pkgs.uv}/bin/uv tool run \
      --from git+https://github.com/github/spec-kit.git \
      --python ${pkgs.python311}/bin/python \
      specify "$@"
  '';
in
{
  options.features.development.spec-kit = mkEnableOption "GitHub spec-kit for Spec-Driven Development";

  config = mkIf (cfg.enable && cfg.spec-kit or false) {
    # Install spec-kit wrapper and dependencies
    environment.systemPackages = [
      spec-kit-wrapper
      pkgs.uv          # Required for running spec-kit
      pkgs.python311   # Required by spec-kit
      pkgs.git         # Required by spec-kit for repository operations
    ];

    # Add convenient shell aliases
    programs.bash.shellAliases = {
      "spec" = "specify";
      "spec-init" = "specify init";
      "spec-check" = "specify check";
    };

    programs.zsh.shellAliases = {
      "spec" = "specify";
      "spec-init" = "specify init";
      "spec-check" = "specify check";
    };
  };
}