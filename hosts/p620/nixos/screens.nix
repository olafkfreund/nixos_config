{...}: {
  home-manager.extraSpecialArgs = {
    vars = {
      hostName = "p620";
      class = "workstation";
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
