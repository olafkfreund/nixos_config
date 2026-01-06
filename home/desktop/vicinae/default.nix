{ lib
, ...
}:
with lib;
{
  options.desktop.vicinae = {
    enable = mkEnableOption {
      default = false;
      description = "Vicinae spatial file manager with grid layout and extensions";
    };
  };

  # Note: This module requires vicinae-extensions to be passed as a special argument
  # If vicinae is not available in your configuration, this module will do nothing
  # To use vicinae, add to your home configuration imports:
  #   vicinae.homeManagerModules.default
  # And add vicinae-extensions to specialArgs
}
