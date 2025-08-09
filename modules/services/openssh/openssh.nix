_: {
  services.openssh = {
    enable = true;
    settings.X11Forwarding = true;
  };
}
