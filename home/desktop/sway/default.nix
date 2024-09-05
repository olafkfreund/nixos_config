{
  config,
  lib,
  ...
}: 
with lib; let
  cfg = config.desktop.sway;
in {
  options.desktop.sway = {
    enable = mkEnableOption {
      default = false;
      description = "sway";
    };
  };
  config = mkIf cfg.enable {
    wayland.windowManager.sway = {
      enable = true;
      # extrasessionCommands = ''
      #   export WLR_BACKENDS="headless,libinput"
      #   export WLR_LIBINPUT_NO_DEVICES="1"
      # '';
      config = {
        terminal = "foot";
        startup = [
          {command = "foot";}
        ];
      };
    };
  };
}
