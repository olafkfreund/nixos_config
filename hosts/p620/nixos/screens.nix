{...}: let
  vars = import ../variables.nix;
in {
  home-manager.extraSpecialArgs = {
    vars = {
      hostName = vars.hostName;
      class = "workstation";
      screen = {
        name = "HDMI-A-1";
        ultrawide = true;
        hidpi = true;
        width = 3840;
        height = 2160;
        refresh = 120;
      };
    };
  };
}
