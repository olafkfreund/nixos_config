#TODO follow: https://github.com/glanceapp/glance/blob/main/docs/configuration.md
{
  services.glance = {
    enable = true;
    settings = {
      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "full";
              widgets = [
                {type = "calendar";}
                {
                  type = "weather";
                  location = "Nivelles, Belgium";
                }
              ];
            }
          ];
        }
      ];
    };
    openFirewall = true;
  };
}
