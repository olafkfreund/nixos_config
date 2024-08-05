{ ...}: {
  services = {
    github-runners = {
      runner = {
        enable = true;
        name = "runner";
        tokenFile = "/home/user/token";
        url = "https://github.com/user/repo";
      };
    };
  };
  networking.enableIPv6 = false;
}
