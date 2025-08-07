{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    playerctl # CLI interface for playerctld
  ];

  services = {
    playerctld.enable = true;
    # mpris-proxy.enable = true;
    # mpd-mpris.enable = true;
    # mpd, mpdris2, and mpd-discord-rpc removed
  };
}
