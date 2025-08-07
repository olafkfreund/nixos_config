{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.development.nixd;
in
{
  options.development.nixd = {
    enable = mkEnableOption "nixd language server configuration";

    flakeDir = mkOption {
      type = types.str;
      default = "/home/olafkfreund/.config/nixos";
      description = "Path to your flake directory";
    };

    hostName = mkOption {
      type = types.str;
      default = "p620";
      description = "The hostname to use for configuration lookups";
    };

    offlineMode = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to operate in offline mode";
    };

    formatterCommand = mkOption {
      type = types.listOf types.str;
      default = [ "alejandra" ];
      description = "Command to use for formatting Nix files";
    };

    diagnosticsIgnored = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Diagnostic codes to ignore";
    };

    diagnosticsExcluded = mkOption {
      type = types.listOf types.str;
      default = [ "\\.direnv" "result" "\\.git" ];
      description = "File paths to exclude from diagnostics";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nixd
      alejandra
      nixpkgs-fmt
      statix
    ];

    xdg.configFile."nixd/nixd.json".text = builtins.toJSON {
      nixd = {
        formatting = {
          command = cfg.formatterCommand;
          timeout_ms = 5000;
        };

        options = {
          nixos = {
            expr = "(builtins.getFlake (\"git+file://\" + toString ${cfg.flakeDir})).nixosConfigurations.${cfg.hostName}.options";
          };
          home_manager = {
            expr = "(builtins.getFlake (\"git+file://\" + toString ${cfg.flakeDir})).homeConfigurations.\"olafkfreund@${cfg.hostName}\".options";
          };
        };

        diagnostics = {
          enable = true;
          ignored = cfg.diagnosticsIgnored;
          excluded = cfg.diagnosticsExcluded;
        };

        eval = {
          depth = 2;
          workers = 3;
          trace = {
            server = "off";
            evaluation = "off";
          };
        };

        completion = {
          enable = true;
          priority = 10;
          insertSingleCandidateImmediately = true;
        };

        path = {
          include = [ "**/*.nix" ];
          exclude = [
            ".direnv/**"
            "result/**"
            ".git/**"
          ];
        };

        # For improved error handling when not connected
        lsp = {
          progressBar = true;
          snippets = true;
          logLevel = "info";
          maxIssues = 100;
          failureHandling = {
            retry = {
              max = 3;
              delayMs = 1000;
            };
            fallbackToOffline = true;
          };
        };
      };
    };
  };
}
