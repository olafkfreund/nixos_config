{ config
, lib
, pkgs
, osConfig ? null
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.development.nixd;

  flake = ''(builtins.getFlake "git+file://${cfg.flakeDir}")'';

  # nixd 2.x reads no config file: settings arrive over workspace/configuration
  # or as flags. Flags work with every client (Claude Code, mcp-language-server),
  # so the per-host values live here, on this host's PATH, never in a synced
  # file (#1983). --config cannot carry `options` (it skips the option-worker
  # start), hence the dedicated --nixos-options-expr.
  # nixd 2.9.2 ends its message loop on any request it does not implement
  # instead of replying -32601, and mcp-language-server sends two of them
  # (textDocument/diagnostic, workspace/symbol). Patched here only, not by
  # overlay, so nothing else loses its cache hits (#1983).
  nixdPatched = pkgs.nixd.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./nixd-method-not-found.patch ];
  });

  nixdAgent = pkgs.writeShellScriptBin "nixd-agent" ''
    exec ${nixdPatched}/bin/nixd \
      --nixos-options-expr=${lib.escapeShellArg "${flake}.nixosConfigurations.${cfg.hostName}.options"} \
      --nixpkgs-expr=${lib.escapeShellArg "import ${flake}.inputs.nixpkgs { }"} \
      --config=${lib.escapeShellArg (builtins.toJSON {
        formatting.command = [ "${pkgs.customPkgs.nix-format}/bin/nix-format" "--stdin" ];
      })} \
      "$@"
  '';
in
{
  options.development.nixd = {
    enable = mkEnableOption "nixd language server for editors and coding agents";

    flakeDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/nixos";
      description = "Flake whose NixOS options and nixpkgs nixd evaluates.";
    };

    hostName = mkOption {
      type = types.str;
      default = if osConfig != null then osConfig.networking.hostName else "p620";
      description = "nixosConfigurations entry whose options nixd completes.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.nixd pkgs.customPkgs.nix-format nixdAgent ];
  };
}
