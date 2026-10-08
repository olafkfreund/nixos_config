{ config
, lib
, pkgs
, ...
}:
with lib;
let
  cfg = config.modules.programs.claude-code-mods;
  pluginDir = "/etc/claude-code/plugins";
in
{
  options.modules.programs.claude-code-mods = {
    enable = mkEnableOption "Claude Code mods shipped from pkgs/claude-code-mods";
    fleetGuard.enable = mkOption {
      type = types.bool;
      default = true;
      description = "fleet-guard: #agents band, /announce, commit and home-manager guards (managed scope).";
    };
    nixFlavour.enable = mkOption {
      type = types.bool;
      default = true;
      description = "nix-flavour: NixOS spinner words and host/generation/theme status line (user scope).";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.etc."claude-code/plugins".source = pkgs.customPkgs.claude-code-mods;
    }

    (mkIf cfg.fleetGuard.enable {
      assertions = [
        {
          assertion = config.modules.programs.claude-code-managed.enable;
          message = "claude-code-mods.fleetGuard needs modules.programs.claude-code-managed.enable (it loads from managed settings).";
        }
      ];
      modules.programs.claude-code-managed.settings = {
        extraKnownMarketplaces.freundcloud-mods.source = {
          source = "directory";
          path = pluginDir;
        };
        enabledPlugins."fleet-guard@freundcloud-mods" = true;
      };
    })

    (mkIf cfg.nixFlavour.enable {
      environment.sessionVariables.CLAUDE_CODE_PLUGIN_DIRS = "${pluginDir}/nix-flavour";
    })
  ]);
}
