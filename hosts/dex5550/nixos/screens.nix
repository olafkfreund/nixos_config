{...}: let
  vars = import ../variables.nix;
in {
  home-manager.extraSpecialArgs = {
    vars = {
      hostName = vars.hostName;
      class = "laptop";
      screen = {
        name = "eDP-1";
        ultrawide = false;
        hidpi = false;
        width = 1920;
        height = 1080;
        refresh = 60;
      };
    };
  };
}
