# Standard module template for consistent structure
{ lib
, pkgs
, ...
}: name: { options ? { }
         , config ? { }
         , meta ? { }
         ,
         }:
let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.${name};
in
{
  options.${name} =
    {
      enable = mkEnableOption "Enable ${name} module" // { default = false; };

      # Standard options every module should have
      package = mkOption {
        type = types.package;
        default = pkgs.${name} or null;
        description = "Package to use for ${name}";
      };

      extraConfig = mkOption {
        type = types.attrs;
        default = { };
        description = "Extra configuration for ${name}";
      };
    }
    // options;

  config = mkIf cfg.enable (config
    // {
    # Standard assertions
    assertions = [
      {
        assertion = cfg.package != null;
        message = "Package for ${name} is not available";
      }
    ];
  });

  meta =
    {
      maintainers = [ "olafkfreund" ];
      doc = ./docs + "/${name}.md";
      platforms = lib.platforms.linux;
    }
    // meta;
}
